#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

const versionFile = path.join(__dirname, '..', 'VERSION');
const version = fs.readFileSync(versionFile, 'utf-8').trim();
const [major, minor, patch] = version.split('.').map(Number);

const type = process.argv[2] || 'patch';
let newVersion;

switch (type) {
  case 'major':
    newVersion = `${major + 1}.0.0`;
    break;
  case 'minor':
    newVersion = `${major}.${minor + 1}.0`;
    break;
  case 'patch':
    newVersion = `${major}.${minor}.${patch + 1}`;
    break;
  default:
    console.error('Usage: node bump-version.js [major|minor|patch]');
    process.exit(1);
}

fs.writeFileSync(versionFile, newVersion + '\n');
console.log(`Bumped version: ${version} → ${newVersion}`);
