import { readFileSync } from 'node:fs';

const directory = new URL('./paired/', import.meta.url);
const read = path => readFileSync(new URL(path, directory), 'utf8');
const manifest = JSON.parse(read('attachments/manifest.json'));
const events = manifest.flatMap(run => run.attachments).filter(item => item.exportedFileName.endsWith('.txt'))
  .map(item => ({ file: item.exportedFileName, text: read(`attachments/${item.exportedFileName}`) }))
  .filter(item => item.text.startsWith('SETUP_PAIR'))
  .map(item => ({ ...item, time: Number(item.text.match(/time=([0-9.]+)/)[1]),
    event: item.text.match(/event=([^ ]+)/)[1] }))
  .sort((a, b) => a.time - b.time);
const frames = item => Object.fromEntries([...item.text.matchAll(/([a-zA-Z]+)=\(([^)]+)\)/g)]
  .map(match => [match[1], match[2].split(',').map(Number)]));
const a = frames(events.find(item => item.event === 'A-no-audit-before.snapshot-start'));
const b = frames(events.find(item => item.event === 'B-all-audit-before.snapshot-start'));
const poseDeltas = Object.fromEntries(Object.keys(a).map(key => [key, a[key].map((n, i) => b[key][i] - n)]));
const details = JSON.parse(read('test-details.json'));
console.log(JSON.stringify({
  test: { result: details.testResult, runs: details.testDescription, seconds: details.durationInSeconds,
    startUTC: new Date(details.startTime * 1000).toISOString() },
  rows: { A: events.filter(item => item.event.startsWith('A-no-audit.row.')).length,
    B: events.filter(item => item.event.startsWith('B-all-audit.row.')).length },
  pose: { A: a, B: b, deltas: poseDeltas },
  events: events.map(({ file, time, event }) => ({ file, event, utc: new Date(time * 1000).toISOString() }))
}, null, 2));
