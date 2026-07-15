const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');

const lib = require('../tools/skillctl-lib');

function tempDir(name) {
  return fs.mkdtempSync(path.join(os.tmpdir(), name));
}

function write(file, content) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, content);
}

function test(name, fn) {
  try {
    fn();
    console.log(`ok - ${name}`);
  } catch (error) {
    console.error(`not ok - ${name}`);
    console.error(error && error.stack ? error.stack : error);
    process.exitCode = 1;
  }
}

test('normalizes GitHub repository inputs into canonical owner/repo and clone URL', () => {
  const normalized = lib.normalizeGithubRepository('https://github.com/kangarooking/cangjie-skill.git');
  assert.strictEqual(normalized.repository, 'kangarooking/cangjie-skill');
  assert.strictEqual(normalized.cloneUrl, 'https://github.com/kangarooking/cangjie-skill.git');
});

test('hashDirectory is stable across file creation order and ignores git metadata', () => {
  const first = tempDir('skillctl-hash-a-');
  const second = tempDir('skillctl-hash-b-');

  write(path.join(first, 'SKILL.md'), 'name: demo\n');
  write(path.join(first, 'references', 'guide.md'), 'hello\n');
  write(path.join(first, '.git', 'HEAD'), 'ignored\n');

  write(path.join(second, 'references', 'guide.md'), 'hello\n');
  write(path.join(second, '.git', 'HEAD'), 'different ignored\n');
  write(path.join(second, 'SKILL.md'), 'name: demo\n');

  assert.strictEqual(lib.hashDirectory(first), lib.hashDirectory(second));
  assert.match(lib.hashDirectory(first), /^sha256:[a-f0-9]{64}$/);
});

test('applyOverlay performs declared text replacements', () => {
  const skill = tempDir('skillctl-overlay-');
  write(path.join(skill, 'SKILL.md'), 'Run npm test.\n');

  lib.applyOverlay(skill, {
    replace: [
      { file: 'SKILL.md', from: 'Run npm test.', to: 'Run pnpm test.' }
    ]
  });

  assert.strictEqual(fs.readFileSync(path.join(skill, 'SKILL.md'), 'utf8'), 'Run pnpm test.\n');
});

test('scanSkillRisk flags high risk tools, scripts, network commands, and secret access', () => {
  const skill = tempDir('skillctl-risk-');
  write(path.join(skill, 'SKILL.md'), [
    '---',
    'name: risky',
    'description: risky demo',
    'allowed-tools: Bash, Write',
    '---',
    'Run curl https://example.com and read ~/.ssh/id_rsa or .env.'
  ].join('\n'));
  write(path.join(skill, 'scripts', 'run.sh'), '#!/usr/bin/env bash\necho hi\n');

  const report = lib.scanSkillRisk(skill);
  assert.strictEqual(report.highRisk, true);
  assert.ok(report.flags.includes('allowed-tools includes Bash'));
  assert.ok(report.flags.includes('allowed-tools includes Write'));
  assert.ok(report.flags.includes('contains network command'));
  assert.ok(report.flags.includes('mentions secret-bearing path'));
  assert.ok(report.flags.includes('contains executable helper scripts'));
});


test('parseGitStatusPorcelain includes modified and untracked paths', () => {
  const files = lib.parseGitStatusPorcelain(' M README.md\nM AGENTS.md\n?? sources/skills.sources.yaml\nA  tools/skillctl\n');
  assert.deepStrictEqual(files, ['README.md', 'AGENTS.md', 'sources/skills.sources.yaml', 'tools/skillctl']);
});


test('root skillctl wrapper forwards arguments to the CLI', () => {
  const childProcess = require('child_process');
  const repoRoot = path.resolve(__dirname, '..');
  const output = childProcess.execFileSync(path.join(repoRoot, 'skillctl'), ['--help'], {
    cwd: repoRoot,
    encoding: 'utf8'
  });
  assert.ok(output.includes('Usage: tools/skillctl <command> [args]'));
});


test('selectLsRemoteRef prefers exact branch refs over similarly named branches', () => {
  const output = [
    '5ddcfd126a7630eefb8b54088cc6b45e64aa556a\trefs/heads/changeset-release/main',
    'e9fcdf95b402d360f90f1db8d776d5dd450f9234\trefs/heads/main'
  ].join('\n');
  assert.strictEqual(lib.selectLsRemoteRef(output, { type: 'branch', value: 'main' }), 'e9fcdf95b402d360f90f1db8d776d5dd450f9234');
});
