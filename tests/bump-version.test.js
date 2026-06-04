'use strict';

// Behavioral tests for scripts/bump-version.js.
//
// Two layers:
//   1. Table-driven unit tests over the exported pure logic (parseVersion,
//      bump) — exact increment semantics for patch/minor/major and rejection
//      of malformed input.
//   2. End-to-end CLI tests that spawn the real script against a throwaway
//      VERSION file and assert the file is rewritten on success AND left
//      untouched (with a non-zero exit) on a malformed VERSION.
//
// These FAIL if the validation regression is reintroduced (e.g. writing
// "1.2.NaN" or exiting 0 on corrupt input): the CLI tests check both the
// exit code and the post-run file contents, so a script that writes garbage
// or swallows the error breaks them.

const test = require('node:test');
const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const SCRIPT = path.join(__dirname, '..', 'scripts', 'bump-version.js');
const { parseVersion, bump } = require(SCRIPT);

// --- Layer 1: pure logic --------------------------------------------------

test('bump() computes correct increments (table-driven)', () => {
  const cases = [
    // [input, type, expected]
    ['1.0.0', 'patch', '1.0.1'],
    ['1.0.0', 'minor', '1.1.0'],
    ['1.0.0', 'major', '2.0.0'],
    ['1.2.3', 'patch', '1.2.4'],
    ['1.2.3', 'minor', '1.3.0'],
    ['1.2.3', 'major', '2.0.0'],
    ['0.0.9', 'patch', '0.0.10'],
    ['0.9.9', 'minor', '0.10.0'],
    ['9.9.9', 'major', '10.0.0'],
    ['10.20.30', 'patch', '10.20.31'],
  ];
  for (const [input, type, expected] of cases) {
    assert.equal(
      bump(input, type),
      expected,
      `bump("${input}", "${type}") should be ${expected}`
    );
  }
});

test('minor/major reset lower components to zero', () => {
  assert.equal(bump('3.7.5', 'minor'), '3.8.0');
  assert.equal(bump('3.7.5', 'major'), '4.0.0');
});

test('parseVersion accepts strict X.Y.Z of non-negative integers', () => {
  assert.deepEqual(parseVersion('1.2.3'), [1, 2, 3]);
  assert.deepEqual(parseVersion('0.0.0'), [0, 0, 0]);
  assert.deepEqual(parseVersion('12.34.56'), [12, 34, 56]);
});

test('parseVersion rejects malformed versions (returns null)', () => {
  const bad = [
    'not-a-version',
    '1.2', // too few components
    '1.2.3.4', // too many components
    '1.2.3-beta', // pre-release suffix
    'v1.2.3', // leading v
    '1.2.x',
    '1..3',
    '1.2.',
    '', // empty
    '1.2.03a',
    ' 1.2.3', // surrounding space (caller trims, but parser is strict)
  ];
  for (const v of bad) {
    assert.equal(parseVersion(v), null, `parseVersion("${v}") should be null`);
  }
});

test('bump() throws (does not return garbage) on malformed VERSION', () => {
  for (const v of ['not-a-version', '1.2', '1.2.3-beta', '']) {
    assert.throws(
      () => bump(v, 'patch'),
      /invalid VERSION/,
      `bump("${v}", "patch") must throw`
    );
  }
});

test('bump() throws on unknown bump type', () => {
  assert.throws(() => bump('1.2.3', 'banana'), /unknown bump type/);
});

// --- Layer 2: real CLI behavior ------------------------------------------

// Build a throwaway repo layout (<dir>/VERSION + <dir>/scripts/bump-version.js)
// so the script resolves VERSION via its own __dirname/.. logic. We copy the
// script rather than symlink so require() inside it still works.
function makeSandbox(versionContents) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'bump-version-'));
  fs.mkdirSync(path.join(dir, 'scripts'));
  fs.copyFileSync(SCRIPT, path.join(dir, 'scripts', 'bump-version.js'));
  fs.writeFileSync(path.join(dir, 'VERSION'), versionContents);
  return dir;
}

function runCli(dir, arg) {
  const scriptInSandbox = path.join(dir, 'scripts', 'bump-version.js');
  try {
    const stdout = execFileSync(
      process.execPath,
      [scriptInSandbox, arg].filter(Boolean),
      { encoding: 'utf-8', stdio: ['ignore', 'pipe', 'pipe'] }
    );
    return { code: 0, stdout, stderr: '' };
  } catch (err) {
    return {
      code: err.status === null || err.status === undefined ? 1 : err.status,
      stdout: err.stdout ? err.stdout.toString() : '',
      stderr: err.stderr ? err.stderr.toString() : '',
    };
  }
}

test('CLI rewrites VERSION file on a valid patch bump', () => {
  const dir = makeSandbox('1.2.3\n');
  try {
    const res = runCli(dir, 'patch');
    assert.equal(res.code, 0, `expected exit 0, got ${res.code} (${res.stderr})`);
    const after = fs.readFileSync(path.join(dir, 'VERSION'), 'utf-8');
    assert.equal(after, '1.2.4\n');
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('CLI rewrites VERSION file on minor and major bumps', () => {
  for (const [arg, expected] of [
    ['minor', '1.3.0\n'],
    ['major', '2.0.0\n'],
  ]) {
    const dir = makeSandbox('1.2.3\n');
    try {
      const res = runCli(dir, arg);
      assert.equal(res.code, 0, res.stderr);
      assert.equal(fs.readFileSync(path.join(dir, 'VERSION'), 'utf-8'), expected);
    } finally {
      fs.rmSync(dir, { recursive: true, force: true });
    }
  }
});

test('CLI defaults to patch when no argument is given', () => {
  const dir = makeSandbox('4.5.6\n');
  try {
    const res = runCli(dir, undefined);
    assert.equal(res.code, 0, res.stderr);
    assert.equal(fs.readFileSync(path.join(dir, 'VERSION'), 'utf-8'), '4.5.7\n');
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('CLI fails loudly and does NOT corrupt a malformed VERSION', () => {
  // This is the core regression guard for the CRITICAL finding: a malformed
  // VERSION must cause exit(1) to stderr and must NOT be overwritten with
  // "1.2.NaN" / "NaN.undefined.NaN".
  const malformedInputs = ['not-a-version\n', '1.2\n', '1.2.3-beta\n'];
  for (const original of malformedInputs) {
    const dir = makeSandbox(original);
    try {
      const res = runCli(dir, 'patch');
      assert.equal(
        res.code,
        1,
        `malformed "${original.trim()}" must exit 1, got ${res.code}`
      );
      assert.match(
        res.stderr,
        /malformed/i,
        'must print a malformed-VERSION error to stderr'
      );
      const after = fs.readFileSync(path.join(dir, 'VERSION'), 'utf-8');
      assert.equal(
        after,
        original,
        `VERSION must be left untouched on failure (was "${after.trim()}")`
      );
      assert.doesNotMatch(
        after,
        /NaN|undefined/,
        'VERSION must never contain NaN/undefined'
      );
    } finally {
      fs.rmSync(dir, { recursive: true, force: true });
    }
  }
});

test('CLI rejects an unknown bump type with a non-zero exit', () => {
  const dir = makeSandbox('1.2.3\n');
  try {
    const res = runCli(dir, 'sideways');
    assert.equal(res.code, 1);
    // VERSION untouched.
    assert.equal(fs.readFileSync(path.join(dir, 'VERSION'), 'utf-8'), '1.2.3\n');
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
