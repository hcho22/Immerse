import { readFileSync } from 'node:fs';

const read = path => readFileSync(new URL(path, import.meta.url), 'utf8');
const manifest = JSON.parse(read('attachments/manifest.json'));
const events = manifest.flatMap(run => run.attachments)
  .filter(item => item.exportedFileName.endsWith('.txt'))
  .map(item => ({ file: item.exportedFileName, text: read(`attachments/${item.exportedFileName}`) }))
  .filter(item => item.text.startsWith('SETUP_PAIR'))
  .map(item => ({ ...item, time: Number(item.text.match(/time=([0-9.]+)/)[1]),
    event: item.text.match(/event=([^ ]+)/)[1] }))
  .sort((a, b) => a.time - b.time);
const frames = item => item ? Object.fromEntries([...item.text.matchAll(/([a-zA-Z]+)=\(([^)]+)\)/g)]
  .map(match => [match[1], match[2].split(',').map(Number)])) : null;
const poses = Object.fromEntries(['A-no-audit', 'B-all-audit'].map(arm => [arm,
  frames(events.find(item => item.event === `${arm}-before.snapshot-start`))]));
const [a, b] = Object.values(poses);
const deltas = a && b ? Object.fromEntries(Object.keys(a).map(key => [key,
  b[key] ? a[key].map((n, i) => b[key][i] - n) : null])) : null;
const rows = events.filter(item => /\.row\./.test(item.event)).map(item => {
  const { readingBounds: bounds, element } = frames(item);
  return { file: item.file, event: item.event, bounds, element,
    contained: element[0] >= bounds[0] && element[1] >= bounds[1]
      && element[0] + element[2] <= bounds[0] + bounds[2]
      && element[1] + element[3] <= bounds[1] + bounds[3] };
});
const details = JSON.parse(read('test-details.json'));
console.log(JSON.stringify({
  test: { result: details.testResult, runs: details.testDescription,
    seconds: details.durationInSeconds, startUTC: new Date(details.startTime * 1000).toISOString() },
  completion: Object.fromEntries(['A-no-audit', 'B-all-audit'].map(arm => [arm, {
    rows: rows.filter(item => item.event.startsWith(arm)).length,
    completeEvent: events.find(item => item.event === `${arm}.complete`)?.text ?? null
  }])),
  poses, deltas, rows,
  scrolls: events.filter(item => item.event === 'scroll.progress').map(({ file, text }) => ({ file, text })),
  issues: events.filter(item => item.event.endsWith('.issue')),
  events: events.map(({ file, time, event }) => ({ file, event, utc: new Date(time * 1000).toISOString() }))
}, null, 2));
