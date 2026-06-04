#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

const SEMVER_RE = /^\d+\.\d+\.\d+$/;

// Parse and validate a raw VERSION string into [major, minor, patch].
// Returns null (does not throw) if the string is not a strict X.Y.Z of
// non-negative integers, so callers can fail loudly instead of writing
// garbage like "1.2.NaN" back to disk.
function parseVersion(raw) {
  if (!SEMVER_RE.test(raw)) {
    return null;
  }
  const parts = raw.split('.').map((n) => Number(n));
  if (!parts.every((n) => Number.isInteger(n) && n >= 0)) {
    return null;
  }
  return parts;
}

// Compute the next version for a given bump type. Exported alongside
// parseVersion so the test suite drives the real logic, not a copy.
function bump(raw, type) {
  const parsed = parseVersion(raw);
  if (parsed === null) {
    throw new Error(
      `invalid VERSION "${raw}": expected MAJOR.MINOR.PATCH of non-negative integers`
    );
  }
  const [major, minor, patch] = parsed;
  switch (type) {
    case 'major':
      return `${major + 1}.0.0`;
    case 'minor':
      return `${major}.${minor + 1}.0`;
    case 'patch':
      return `${major}.${minor}.${patch + 1}`;
    default:
      throw new Error(`unknown bump type "${type}": expected major|minor|patch`);
  }
}

function main(argv) {
  const versionFile = path.join(__dirname, '..', 'VERSION');
  const version = fs.readFileSync(versionFile, 'utf-8').trim();
  const type = argv[2] || 'patch';

  if (!['major', 'minor', 'patch'].includes(type)) {
    console.error('Usage: node bump-version.js [major|minor|patch]');
    process.exit(1);
  }

  // Validate BEFORE writing. A corrupt VERSION must never be overwritten
  // with a malformed value, and the process must exit non-zero so callers
  // (CI, release scripts) see the failure.
  if (parseVersion(version) === null) {
    console.error(
      `Error: VERSION file is malformed: "${version}". ` +
        'Expected MAJOR.MINOR.PATCH of non-negative integers (e.g. 1.2.3).'
    );
    process.exit(1);
  }

  const newVersion = bump(version, type);
  fs.writeFileSync(versionFile, newVersion + '\n');
  console.log(`Bumped version: ${version} → ${newVersion}`);
}

if (require.main === module) {
  main(process.argv);
}

module.exports = { parseVersion, bump };
