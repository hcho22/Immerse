import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const read = path => readFileSync(new URL(path, import.meta.url), 'utf8');
const addedSource = patch => patch.split('\n')
  .filter(line => line.startsWith('+') && !line.startsWith('+++'))
  .map(line => line.slice(1)).join('\n');
let expected = addedSource(read('../progress-correction/diagnostic.patch'));
const replacements = [
  ['for _ in 0..<8 where !camera.isHittable { app.swipeUp() }',
    'for _ in 0..<8 {\n                if camera.isHittable { break }\n                app.swipeUp()\n            }'],
  ['for _ in 0..<16 where !title.exists { try drag(app, points: -220) }',
    'for _ in 0..<16 {\n                if title.exists { break }\n                try drag(app, points: -220)\n            }'],
  ['for _ in 0..<16 where abs(title.frame.minY - 400) > 1 {',
    'for _ in 0..<16 {\n                if abs(title.frame.minY - 400) <= 1 { break }'],
  ['for _ in 0..<20 where !row.exists {',
    'for _ in 0..<20 {\n                    if row.exists { break }'],
  ['for _ in 0..<20 where !readingBounds(app).contains(row.frame) {',
    'for _ in 0..<20 {\n                    if readingBounds(app).contains(row.frame) { break }']
];
for (const [before, after] of replacements) {
  assert.equal(expected.split(before).length, 2);
  expected = expected.replace(before, after);
}
assert.equal(addedSource(read('diagnostic.patch')), expected);
console.log('Only five bounded search/position loops changed to early exit on fresh AX success conditions.');
console.log('Iteration limits, post-loop assertions, consecutive settlement, matching, ten rows, snapshots, audit and no-progress throw are byte-identical.');
console.log('This is source equivalence evidence, not an executed native failure-path test.');
