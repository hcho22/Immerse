import { readFileSync, statSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';

const root = fileURLToPath(new URL('.', import.meta.url));
const json = path => JSON.parse(readFileSync(root + path, 'utf8'));
const utc = seconds => new Date(seconds * 1000).toISOString();
const walk = activities => activities.flatMap(a => [a, ...walk(a.childActivities ?? [])]);
const observations = [];
for (const mode of ['light', 'dark']) {
  const summary = json(`${mode}-summary.json`);
  const manifest = json(`${mode}/attachments/manifest.json`);
  if (summary.totalTestCount !== 2 || summary.skippedTests !== 0 || manifest.length !== 2) {
    throw Error(`Unexpected execution inventory: ${mode}`);
  }
  for (const name of ['default', 'largest']) {
    const details = json(`${mode}/${name}-details.json`);
    const runs = json(`${mode}/${name}-activities.json`).testRuns;
    if (runs.length !== 1) throw Error('Expected exactly one run per case');
    const attachments = manifest.find(m => m.testIdentifier === details.testIdentifier).attachments;
    const attachmentText = a => readFileSync(root + `${mode}/attachments/${a.exportedFileName}`, 'utf8');
    const trees = attachments.filter(a => /accessibility-tree/.test(a.suggestedHumanReadableName));
    const nodes = attachments.filter(a => /audit-node/.test(a.suggestedHumanReadableName));
    observations.push({
      mode, name, testIdentifier: details.testIdentifier, result: details.testResult,
      startUTC: utc(details.startTime), durationSeconds: details.durationInSeconds,
      timeline: runs[0].activities.filter(a =>
        a.isAssociatedWithFailure || /Start Test|Open |Tap |Swipe |Added attachment|Setting device|Tear Down/.test(a.title)
      ).map(a => ({ utc: utc(a.startTime), failure: a.isAssociatedWithFailure, title: a.title })),
      failureCount: walk(runs[0].activities).filter(a => a.isAssociatedWithFailure).length,
      auditNodes: nodes.map(a => ({
        file: `${mode}/attachments/${a.exportedFileName}`,
        name: a.suggestedHumanReadableName, utc: utc(a.timestamp),
        detail: attachmentText(a).split('\n').slice(0, 2)
      })),
      preAuditTrees: trees.map(a => ({
        file: `${mode}/attachments/${a.exportedFileName}`,
        name: a.suggestedHumanReadableName, utc: utc(a.timestamp),
        relevantLines: attachmentText(a).split('\n').filter(l =>
          /NavigationBar|finer grain|Silent capture|Orientation|film-title|Trial|Subscription|Load Film/.test(l)
        ).map(l => l.trim())
      })),
      recordings: attachments.filter(a => a.exportedFileName.endsWith('.mp4')).map(a => {
        const file = `${mode}/attachments/${a.exportedFileName}`;
        const probe = JSON.parse(execFileSync('ffprobe', ['-v', 'error', '-show_entries',
          'format=duration,size:stream=codec_name,width,height,nb_frames', '-of', 'json', root + file]));
        return { file, startUTC: utc(a.timestamp), bytes: statSync(root + file).size, probe };
      })
    });
  }
}
process.stdout.write(JSON.stringify(observations, null, 2) + '\n');
