import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';

const [directory, mode] = process.argv.slice(2);
assert(directory && ['unit', 'ui'].includes(mode), 'Supply evidence directory and unit/ui');
// Foundation emits UInt64 treatment seeds. Ruby's standard JSON parser preserves
// those integers; convert only unsafe JS integers to strings before comparison.
const json = file => JSON.parse(execFileSync('/usr/bin/ruby', ['-rjson', '-e', `
def exact(value)
  case value
  when Hash then value.transform_values { |v| exact(v) }
  when Array then value.map { |v| exact(v) }
  when Integer then value.abs > 9007199254740991 ? value.to_s : value
  else value
  end
end
puts JSON.generate(exact(JSON.parse(File.read(ARGV.fetch(0)))))
`, file], { encoding: 'utf8' }));
const sha = file => createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const summary = json(path.join(directory, 'summary.json'));
assert.equal(summary.failedTests, 0);
assert.equal(summary.skippedTests, 0);
assert.equal(summary.totalTestCount, mode === 'unit' ? 9 : 2);
assert.equal(summary.passedTests, summary.totalTestCount);
assert.equal(Number(fs.readFileSync(path.join(directory, 'exit.txt'), 'utf8')), 0);
const scenarios = [];
const assetMap = (snapshot, predicate = () => true) => Object.fromEntries(snapshot.assets.filter(predicate)
  .map(a => [`${a.kind}-${a.sequence}`, a.actualHash]));
const development = snapshot => ({ ...snapshot.development,
  completedSequences: [...snapshot.development.completedSequences].sort((a, b) => a - b) });
for (const id of fs.readdirSync(path.join(directory, 'scenarios')).sort()) {
  const root = path.join(directory, 'scenarios', id);
  const manifest = json(path.join(root, 'scenario.json'));
  const events = fs.readFileSync(path.join(root, 'Evidence/events.jsonl'), 'utf8').trim().split('\n').map(JSON.parse);
  const session = events.find(e => e.event === 'session-open');
  assert.equal(session.run, id);
  assert.equal(session.backend, 'injected-private-writer');
  const current = Date.parse(session.utc) / 1000 >= Math.floor(summary.startTime);
  const inventories = events.filter(e => e.event === 'inventory').map(event => ({
    event, value: json(path.join(root, 'Evidence', event.file)),
  }));
  const last = inventories.at(-1)?.value;
  const copies = events.filter(e => e.event === 'external-synthetic-copy-completed');
  for (const copy of copies) {
    assert.equal(copy.recalledByPrivateRemoval, 'false');
    assert.equal(sha(path.join(root, 'ExternalCopies', copy.file)), copy.sha256);
  }
  assert.equal(copies.length, Object.keys(last?.externalFiles ?? {}).length, 'Every completed copy must be retained');
  const exits = events.filter(e => e.event === 'ordinary-process-exit');
  if (current && mode === 'ui') {
    assert.equal(exits.length, 1);
    assert.equal(exits[0].powerLoss, 'false');
    const pausedIndex = events.findIndex(e => e.event === 'writer-paused');
    assert(pausedIndex >= 0);
    const before = inventories.find(i => events.indexOf(i.event) > pausedIndex && events.indexOf(i.event) < events.indexOf(exits[0]))?.value;
    const recovery = events.find(e => e.event === 'recovery-returned');
    assert(recovery && recovery.process !== exits[0].process, 'Must recover in a different process');
    const recovered = inventories.find(i => i.event.label === 'recover')?.value;
    const retried = inventories.find(i => i.event.label === 'retry')?.value;
    assert(before && recovered && retried);
    assert.deepEqual(recovered.films, before.films);
    assert.deepEqual(development(recovered), development(before));
    assert.deepEqual(assetMap(recovered), assetMap(before));
    assert.deepEqual(recovered.externalFiles, before.externalFiles, 'Recovery must not export');
    assert(!Object.keys(recovered.privateFiles).some(p => p.startsWith('Work/')));
    assert.equal(recovered.assets.filter(a => a.kind === 'source').length, manifest.count);
    assert.deepEqual(recovered.dispositions['1'], { exportRequested: {} });
    const previousCopies = manifest.label === 'process-beforeReply' ? 1 : 0;
    assert.equal(Object.keys(recovered.externalFiles).length, previousCopies);
    assert.equal(Object.keys(retried.externalFiles).length, previousCopies + 1);
    assert.equal(retried.assets.filter(a => a.kind === 'source').length, manifest.count - 1);
    assert.deepEqual(assetMap(retried, a => a.kind !== 'source'), assetMap(before, a => a.kind !== 'source'));
    assert.deepEqual(development(retried), development(before));
    assert.deepEqual(retried.films, before.films);
    const source = before.assets.find(a => a.kind === 'source' && a.sequence === 1);
    assert(source);
    for (const hash of Object.values(retried.externalFiles)) assert.equal(hash, source.actualHash);
    assert.equal(retried.dispositions['1'].exported.sourceSHA256, source.actualHash);
    assert(retried.dispositions['1'].exported.photosIdentifier.startsWith('injected-private-export036:'));
    for (const asset of retried.assets) {
      assert.equal(asset.actualHash, asset.expectedHash);
      assert(asset.decodedFrames > 0);
      assert.equal(sha(path.join(root, 'App', asset.path)), asset.actualHash);
    }
  }
  scenarios.push({ id, currentRun: current, label: manifest.label, camera: manifest.camera,
    processes: [...new Set(events.map(e => e.process))], inventories: inventories.length,
    completedExternalCopies: copies.length, processExits: exits.length,
    writerCancellations: events.filter(e => e.event === 'writer-task-cancelled').length,
    exportErrors: events.filter(e => e.event === 'export-error').map(e => e.error),
    lastSummary: inventories.at(-1)?.event.summary,
  });
}
assert.equal(scenarios.filter(s => s.currentRun).length, mode === 'unit' ? 27 : 4);
console.log(JSON.stringify({ mode, result: summary.result, passed: summary.passedTests, failed: summary.failedTests,
  startUTC: new Date(summary.startTime * 1000).toISOString(), finishUTC: new Date(summary.finishTime * 1000).toISOString(),
  runtime: summary.devicesAndConfigurations, retainedHistories: scenarios.length,
  nativePhotoKitAcceptance: false, scenarios }, null, 2));
