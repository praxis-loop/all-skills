const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const os = require('os');
const childProcess = require('child_process');
const yaml = require('js-yaml');

const HIGH_RISK_TOOL_NAMES = ['Bash', 'Write', 'Edit'];

function normalizeGithubRepository(input) {
  if (!input || typeof input !== 'string') {
    throw new Error('GitHub repository must be a non-empty string');
  }

  let value = input.trim();
  value = value.replace(/^git@github\.com:/, '');
  value = value.replace(/^ssh:\/\/git@github\.com\//, '');
  value = value.replace(/^https:\/\/github\.com\//, '');
  value = value.replace(/^http:\/\/github\.com\//, '');
  value = value.replace(/^github\.com\//, '');
  value = value.replace(/\.git$/, '');
  value = value.replace(/^\/+|\/+$/g, '');

  const parts = value.split('/');
  if (parts.length !== 2 || !parts[0] || !parts[1]) {
    throw new Error(`Invalid GitHub repository: ${input}`);
  }

  const repository = `${parts[0]}/${parts[1]}`;
  return {
    repository,
    cloneUrl: `https://github.com/${repository}.git`
  };
}

function ensureDir(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

function removeDir(dir) {
  if (!fs.existsSync(dir)) return;
  fs.rmdirSync(dir, { recursive: true });
}

function listFiles(root) {
  const result = [];

  function visit(current) {
    const entries = fs.readdirSync(current, { withFileTypes: true });
    entries.sort((a, b) => a.name.localeCompare(b.name));
    entries.forEach((entry) => {
      if (entry.name === '.git' || entry.name === 'node_modules') return;
      const fullPath = path.join(current, entry.name);
      if (entry.isDirectory()) {
        visit(fullPath);
      } else if (entry.isFile()) {
        result.push(fullPath);
      }
    });
  }

  if (fs.existsSync(root)) visit(root);
  return result;
}

function sha256Buffer(buffer) {
  return crypto.createHash('sha256').update(buffer).digest('hex');
}

function hashDirectory(root) {
  if (!fs.existsSync(root)) {
    throw new Error(`Directory does not exist: ${root}`);
  }

  const hash = crypto.createHash('sha256');
  listFiles(root).forEach((file) => {
    const relative = path.relative(root, file).split(path.sep).join('/');
    const fileHash = sha256Buffer(fs.readFileSync(file));
    hash.update(relative);
    hash.update('\0');
    hash.update(fileHash);
    hash.update('\0');
  });
  return `sha256:${hash.digest('hex')}`;
}

function copyDir(source, target) {
  if (!fs.existsSync(source)) {
    throw new Error(`Source directory does not exist: ${source}`);
  }
  ensureDir(target);
  fs.readdirSync(source, { withFileTypes: true }).forEach((entry) => {
    if (entry.name === '.git' || entry.name === 'node_modules') return;
    const sourcePath = path.join(source, entry.name);
    const targetPath = path.join(target, entry.name);
    if (entry.isDirectory()) {
      copyDir(sourcePath, targetPath);
    } else if (entry.isFile()) {
      ensureDir(path.dirname(targetPath));
      fs.copyFileSync(sourcePath, targetPath);
    }
  });
}

function loadYamlFile(file, fallback) {
  if (!fs.existsSync(file)) return fallback;
  const raw = fs.readFileSync(file, 'utf8');
  const parsed = yaml.load(raw);
  return parsed || fallback;
}

function writeYamlFile(file, data) {
  ensureDir(path.dirname(file));
  fs.writeFileSync(file, yaml.dump(data, { lineWidth: 100, noRefs: true }));
}

function loadJsonFile(file, fallback) {
  if (!fs.existsSync(file)) return fallback;
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

function writeJsonFile(file, data) {
  ensureDir(path.dirname(file));
  fs.writeFileSync(file, `${JSON.stringify(data, null, 2)}\n`);
}

function validateSources(sources) {
  const errors = [];
  if (!sources || sources.version !== 1) {
    errors.push('sources file must contain version: 1');
  }
  const skills = sources && sources.skills ? sources.skills : {};
  Object.keys(skills).forEach((name) => {
    const item = skills[name];
    if (!item || !item.type) errors.push(`${name}: missing type`);
    if (item.type === 'github') {
      if (!item.repository) errors.push(`${name}: missing repository`);
      if (!item.path) errors.push(`${name}: missing path`);
      if (!item.target) errors.push(`${name}: missing target`);
      if (!item.track || !item.track.type || !item.track.value) errors.push(`${name}: missing track.type/value`);
    } else if (item.type === 'npm') {
      if (!item.package) errors.push(`${name}: missing package`);
      if (!item.range) errors.push(`${name}: missing range`);
      if (!item.path) errors.push(`${name}: missing path`);
      if (!item.target) errors.push(`${name}: missing target`);
    } else {
      errors.push(`${name}: unsupported type ${item.type}`);
    }
  });
  return errors;
}

function parseAllowedTools(skillText) {
  const match = skillText.match(/^allowed-tools:\s*(.+)$/m);
  if (!match) return [];
  return match[1].split(',').map((value) => value.trim()).filter(Boolean);
}

function scanSkillRisk(skillDir) {
  const flags = [];
  const skillFile = path.join(skillDir, 'SKILL.md');
  let skillText = '';
  if (fs.existsSync(skillFile)) {
    skillText = fs.readFileSync(skillFile, 'utf8');
  } else {
    flags.push('missing SKILL.md');
  }

  const tools = parseAllowedTools(skillText);
  HIGH_RISK_TOOL_NAMES.forEach((tool) => {
    if (tools.indexOf(tool) !== -1) flags.push(`allowed-tools includes ${tool}`);
  });

  if (/\b(curl|wget)\b/.test(skillText)) flags.push('contains network command');
  if (/\bsudo\b/.test(skillText)) flags.push('contains sudo command');
  if (/\b(npm install|pip install|pnpm add|yarn add)\b/.test(skillText)) flags.push('contains package install command');
  if (/(~\/\.ssh|~\/\.aws|\.env\b|API key|token|secret)/i.test(skillText)) flags.push('mentions secret-bearing path');
  if (/\brm\s+-rf\b/.test(skillText)) flags.push('contains destructive delete command');

  const scriptsDir = path.join(skillDir, 'scripts');
  if (fs.existsSync(scriptsDir) && listFiles(scriptsDir).length > 0) {
    flags.push('contains executable helper scripts');
  }

  return {
    highRisk: flags.length > 0,
    flags
  };
}

function applyOverlay(skillDir, overlay) {
  if (!overlay) return [];
  const changes = [];
  const replacements = overlay.replace || [];
  replacements.forEach((item, index) => {
    const file = item.file || 'SKILL.md';
    if (!item.from && item.from !== '') throw new Error(`overlay replace[${index}] missing from`);
    if (!item.to && item.to !== '') throw new Error(`overlay replace[${index}] missing to`);
    const filePath = path.join(skillDir, file);
    if (!filePath.startsWith(path.resolve(skillDir))) {
      throw new Error(`overlay path escapes skill directory: ${file}`);
    }
    if (!fs.existsSync(filePath)) throw new Error(`overlay target file does not exist: ${file}`);
    const original = fs.readFileSync(filePath, 'utf8');
    if (original.indexOf(item.from) === -1) {
      throw new Error(`overlay text not found in ${file}: ${item.from}`);
    }
    fs.writeFileSync(filePath, original.split(item.from).join(item.to));
    changes.push(file);
  });
  return changes;
}

function loadOverlay(repoRoot, skillName) {
  const overlayFile = path.join(repoRoot, 'overlays', skillName, 'overlay.yaml');
  if (!fs.existsSync(overlayFile)) return null;
  return loadYamlFile(overlayFile, null);
}

function parseGitStatusPorcelain(output) {
  if (!output) return [];
  return output.split('\n').map((line) => {
    if (!line.trim()) return null;
    if (/^.. /.test(line)) return line.slice(3).trim();
    return line.replace(/^\S+\s+/, '').trim();
  }).filter(Boolean);
}

function execGit(args, cwd) {
  return childProcess.execFileSync('git', args, {
    cwd,
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe']
  }).trim();
}

function resolveGithubHead(source) {
  const normalized = normalizeGithubRepository(source.repository);
  const ref = source.track && source.track.value ? source.track.value : 'main';
  const output = execGit(['ls-remote', normalized.cloneUrl, ref], process.cwd());
  if (!output) throw new Error(`Unable to resolve ${normalized.repository} ${ref}`);
  const firstLine = output.split('\n')[0];
  return firstLine.split(/\s+/)[0];
}

function cloneGithubSource(source, workDir) {
  const normalized = normalizeGithubRepository(source.repository);
  const ref = source.track && source.track.value ? source.track.value : 'main';
  const cloneDir = path.join(workDir, 'repo');
  const args = ['clone', '--depth', '1'];
  if (source.track && (source.track.type === 'branch' || source.track.type === 'tag')) {
    args.push('--branch', ref);
  }
  args.push(normalized.cloneUrl, cloneDir);
  execGit(args, workDir);
  if (source.track && source.track.type === 'commit') {
    execGit(['checkout', ref], cloneDir);
  }
  const commit = execGit(['rev-parse', 'HEAD'], cloneDir);
  const sourcePath = source.path === '.' ? cloneDir : path.join(cloneDir, source.path);
  if (!fs.existsSync(sourcePath)) {
    throw new Error(`Source path does not exist in ${normalized.repository}: ${source.path}`);
  }
  const treeSpec = source.path === '.' ? 'HEAD^{tree}' : `HEAD:${source.path.replace(/^\.\//, '')}`;
  const treeSha = execGit(['rev-parse', treeSpec], cloneDir);
  return {
    repository: normalized.repository,
    cloneUrl: normalized.cloneUrl,
    cloneDir,
    sourcePath,
    commit,
    treeSha
  };
}

function makeTempWorkDir() {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'skillctl-'));
}

module.exports = {
  applyOverlay,
  cloneGithubSource,
  copyDir,
  ensureDir,
  execGit,
  hashDirectory,
  listFiles,
  loadJsonFile,
  loadOverlay,
  loadYamlFile,
  makeTempWorkDir,
  normalizeGithubRepository,
  parseGitStatusPorcelain,
  removeDir,
  resolveGithubHead,
  scanSkillRisk,
  validateSources,
  writeJsonFile,
  writeYamlFile
};
