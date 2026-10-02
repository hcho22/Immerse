import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';

const [directory, mode] = process.argv.slice(2);
assert(directory && ['unit', 'security', 'ui'].includes(mode), 'Supply run directory and unit/security/ui');
const readJSON = file => JSON.parse(fs.readFileSync(file, 'utf8'));
const hash = file => createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const summary = readJSON(path.join(directory, 'summary.json'));
assert.equal(Number(fs.readFileSync(path.join(directory, 'exit.txt'), 'utf8')), 0);
assert.equal(summary.failedTests, 0, 'Retained failure is not a passing checkpoint');
assert.equal(summary.totalTestCount, { unit: 8, security: 1, ui: 3 }[mode]);
if (mode !== 'security') {
  assert.equal(summary.skippedTests, 0);
  assert.equal(summary.passedTests, summary.totalTestCount);
}
const scenarios = [];
const scenarioRoot = path.join(directory, 'scenarios');
for (const name of fs.readdirSync(scenarioRoot).sort()) {
  const root = path.join(scenarioRoot, name);
  const manifest = readJSON(path.join(root, 'scenario.json'));
  const events = fs.readFileSync(path.join(root, 'Evidence/events.jsonl'), 'utf8').trim().split('\n').map(JSON.parse);
  const first = events.find(e => e.event === 'session-open');
  const config = manifest.configuration;
  assert.equal(first.namespace, `com.immerse.validation.receipt035.${name}`);
  assert.equal(first.account, 'device-trial');
  assert.equal(first.backend, config.backend);
  const inventories = events.filter(e => e.event === 'inventory').map(e => ({
    event: e, value: readJSON(path.join(root, 'Evidence', e.file)),
  }));
  for (const { value } of inventories) assert.deepEqual(value.configuration, config);
  // Snapshots include retained earlier histories. Never count those as new executions.
  const current = Date.parse(first.utc) / 1000 >= Math.floor(summary.startTime);
  const exits = events.filter(e => e.event === 'ordinary-process-exit-requested');
  const last = inventories.at(-1)?.value;
  if (current && mode === 'ui') {
    assert.equal(config.backend, 'injectedFile');
    assert.equal(config.fault, 'none');
    assert.equal(exits.length, 1);
    assert.equal(exits[0].powerLoss, 'false');
    const pauseIndex = events.findIndex(e => e.event === 'paused');
    assert(pauseIndex >= 0, 'Explicit production-boundary pause missing');
    const paused = inventories.find(i => events.indexOf(i.event) > pauseIndex &&
      events.indexOf(i.event) < events.indexOf(exits[0]) && i.value.pending)?.value;
    assert(paused, 'Missing pre-exit pending inventory');
    const basename = path.basename(manifest.sourcePath);
    assert.equal(paused.files[`Staging/${manifest.filmID}/Commit/${basename}`], manifest.sourceHash);
    assert.equal(paused.films[0].captures.length, config.pauseAt === 'projected' ? 1 : 0);
    assert.equal(Boolean(paused.underlyingRecord.consumedFilmID), config.pauseAt !== 'prepared');
    const resumed = events.find(e => e.event === 'recovery-returned');
    assert(resumed && resumed.process !== exits[0].process, 'Recovery must run in a different process');
    assert.equal(last.films.length, 1);
    const film = last.films[0];
    assert.equal(film.captures.length, 1);
    const capture = film.captures[0];
    assert.equal(capture.sequenceNumber, 1);
    assert.equal(capture.savedAt, manifest.savedAt);
    assert.equal(capture.revealState, 'sealed');
    assert.equal(last.pending, false);
    assert.equal(last.outboxFilmIDs.length, 0);
    assert.equal(last.underlyingRecord.consumedFilmID, manifest.filmID);
    assert.equal(last.underlyingRecord.consumedCaptureID, basename);
    assert.equal(last.underlyingRecord.consumedAt, manifest.savedAt);
    assert.equal(last.sqlReceipt.sourceSHA256, manifest.sourceHash);
    assert.equal(last.sqlReceipt.sequenceNumber, 1);
    assert.equal(last.sourceMatches, true);
    assert(last.decodedFrames > 0);
    const source = Object.keys(last.files).find(p => p.startsWith(`Media/${manifest.filmID}/source-1.`));
    assert(source, 'Persisted source missing');
    assert.equal(hash(path.join(root, 'App', source)), manifest.sourceHash);
    if (config.cameraID !== 'disposable1990s') {
      assert.equal(film.movieOrientation, 'portrait');
      assert.equal(capture.kind.movieClip.orientation, 'landscape');
      assert.equal(capture.kind.movieClip.seconds, manifest.duration);
    }
  }
  scenarios.push({ name, currentRun: current, configuration: config, namespace: first.namespace,
    processes: [...new Set(events.map(e => e.process))],
    adapterStatuses: [...new Set(events.filter(e => e.event.startsWith('adapter-')).map(e => e.status ?? e.actualStatus))],
    observedErrors: events.filter(e => e.error).map(e => ({ event: e.event, error: e.error })),
    capabilityUnavailable: events.find(e => e.event === 'native-capability-unavailable')?.status,
    processExits: exits.length, inventories: inventories.length,
    lastSummary: inventories.at(-1)?.event.summary,
  });
}
const current = scenarios.filter(s => s.currentRun);
assert.equal(current.length, { unit: 19, security: 1, ui: 9 }[mode]);
if (mode === 'ui') {
  const combinations = new Set(current.map(s => `${s.configuration.cameraID}/${s.configuration.pauseAt}`));
  assert.equal(combinations.size, 9);
}
if (mode === 'security' && summary.skippedTests === 1) {
  assert(current[0].capabilityUnavailable, 'Skip requires actual recorded native status');
}
console.log(JSON.stringify({ mode, result: summary.result, passed: summary.passedTests, skipped: summary.skippedTests,
  startUTC: new Date(summary.startTime * 1000).toISOString(), finishUTC: new Date(summary.finishTime * 1000).toISOString(),
  runtime: summary.devicesAndConfigurations, newHistories: current.length, retainedHistories: scenarios.length,
  nativeAcceptance: false, scenarios }, null, 2));
