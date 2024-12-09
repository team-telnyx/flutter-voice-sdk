const fs = require('fs');
const path = require('path');

// Extract environment variables from GitHub Actions
const { GITHUB_EVENT_PATH, GITHUB_REPOSITORY } = process.env;

// Load GitHub event data
const eventData = JSON.parse(fs.readFileSync(GITHUB_EVENT_PATH, 'utf-8'));

// Extract relevant PR data
const prNumber = eventData.pull_request.number;
const prTitle = eventData.pull_request.title;
const prLabels = eventData.pull_request.labels.map((label) => label.name);

// Determine category based on labels
let category = 'Other';
if (prLabels.includes('Bug')) category = 'Bug Fixing';
if (prLabels.includes('Enhancement')) category = 'Enhancement';
if (prLabels.includes('Feature')) category = 'Feature';

// Prepare changelog entry
const newEntry = `## [Unreleased]

### ${category}
- ${prTitle} (PR #${prNumber})
`;

// Read, update, and write the changelog
const changelogPath = path.resolve('packages/telnyx_webrtc/CHANGELOG.md');
let changelogContent = fs.readFileSync(changelogPath, 'utf-8');
changelogContent = newEntry + '\n' + changelogContent;
fs.writeFileSync(changelogPath, changelogContent, 'utf-8');

console.log('CHANGELOG.md updated successfully!');