import crypto from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import zlib from 'node:zlib';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, '..');
const outputDir = path.join(repoRoot, 'apps', 'zhixuan_main', 'web', 'memory');
const outputPath = path.join(outputDir, 'project-memory-snapshot.enc.json');

const MEMORY_PASSPHRASE = 'zhixuan-memory-bridge::2026::project-memory';
const PBKDF2_ITERATIONS = 120000;
const EXCLUDED_SEGMENTS = new Set([
  '.git',
  '.dart_tool',
  '.idea',
  '.vscode',
  'build',
  'node_modules',
  '.wrangler',
  '.turbo',
  '.DS_Store',
]);

const CONFIG_FILE_PATTERNS = [
  /^pubspec\.yaml$/i,
  /^melos\.yaml$/i,
  /^package(-lock)?\.json$/i,
  /^wrangler\.jsonc$/i,
  /^analysis_options\.yaml$/i,
  /^Dockerfile/i,
  /^docker-compose/i,
  /\.gradle(\.kts)?$/i,
  /\.properties$/i,
  /\.toml$/i,
  /\.ya?ml$/i,
  /\.json$/i,
  /\.env(\..+)?$/i,
  /\.cmake$/i,
];

const DOC_EXTENSIONS = new Set(['.md', '.mdx', '.txt']);
const CODE_EXTENSIONS = new Set(['.dart', '.js', '.mjs', '.cjs', '.ts', '.tsx', '.jsx']);

function toPosix(value) {
  return value.split(path.sep).join('/');
}

function shouldSkip(fullPath, relativePath) {
  const parts = toPosix(relativePath).split('/');
  if (parts.some((segment) => EXCLUDED_SEGMENTS.has(segment))) {
    return true;
  }

  const normalized = toPosix(relativePath);
  return normalized.startsWith('supabase/.temp/');
}

function sha256(buffer) {
  return crypto.createHash('sha256').update(buffer).digest('hex');
}

async function walkDirectory(directoryPath, results = []) {
  const entries = await fs.readdir(directoryPath, { withFileTypes: true });

  for (const entry of entries) {
    const fullPath = path.join(directoryPath, entry.name);
    const relativePath = path.relative(repoRoot, fullPath);
    if (shouldSkip(fullPath, relativePath)) {
      continue;
    }

    const stats = await fs.stat(fullPath);
    const isDirectory = entry.isDirectory() || stats.isDirectory();
    const isFile = entry.isFile() || stats.isFile();
    if (!isDirectory && !isFile) {
      continue;
    }

    const item = {
      path: toPosix(relativePath),
      type: isDirectory ? 'directory' : 'file',
      size: stats.size,
      modifiedAt: stats.mtime.toISOString(),
    };

    if (isDirectory) {
      results.push(item);
      await walkDirectory(fullPath, results);
      continue;
    }

    const buffer = await fs.readFile(fullPath);
    item.sha256 = sha256(buffer);
    results.push(item);
  }

  return results.sort((a, b) => a.path.localeCompare(b.path));
}

async function readFilesByPredicate(predicate) {
  const fileTree = await walkDirectory(repoRoot);
  const selected = fileTree.filter((entry) => entry.type === 'file' && predicate(entry.path));
  const records = [];

  for (const entry of selected) {
    const fullPath = path.join(repoRoot, entry.path);
    const content = await fs.readFile(fullPath, 'utf8');
    records.push({
      path: entry.path,
      sha256: entry.sha256,
      content,
    });
  }

  return records;
}

function isConfigFile(relativePath) {
  const baseName = path.basename(relativePath);
  return CONFIG_FILE_PATTERNS.some((pattern) => pattern.test(baseName));
}

function isDocFile(relativePath) {
  return DOC_EXTENSIONS.has(path.extname(relativePath).toLowerCase());
}

function isCodeFile(relativePath) {
  return CODE_EXTENSIONS.has(path.extname(relativePath).toLowerCase());
}

async function collectPubspecDependencies(filePath, content) {
  const lines = content.split(/\r?\n/);
  const dependencies = [];
  let currentSection = null;

  for (const rawLine of lines) {
    const line = rawLine.replace(/\t/g, '  ');
    const sectionMatch = line.match(/^([A-Za-z_][A-Za-z0-9_]*):\s*$/);
    if (sectionMatch) {
      currentSection = sectionMatch[1];
      continue;
    }

    if (!['dependencies', 'dev_dependencies'].includes(currentSection)) {
      continue;
    }

    const dependencyMatch = line.match(/^\s{2}([A-Za-z0-9_]+):\s*(.+)?$/);
    if (!dependencyMatch) {
      continue;
    }

    const [, name, rawValue = ''] = dependencyMatch;
    const value = rawValue.trim();
    dependencies.push({
      sourceFile: filePath,
      scope: currentSection,
      name,
      version: value || 'implicit',
    });
  }

  return dependencies;
}

function collectPackageDependencies(filePath, content) {
  const json = JSON.parse(content);
  const dependencies = [];

  for (const scope of ['dependencies', 'devDependencies', 'peerDependencies']) {
    const entries = Object.entries(json[scope] ?? {});
    for (const [name, version] of entries) {
      dependencies.push({
        sourceFile: filePath,
        scope,
        name,
        version,
      });
    }
  }

  return dependencies;
}

async function buildDependencyInventory(configFiles) {
  const dependencies = [];

  for (const file of configFiles) {
    const baseName = path.basename(file.path);
    if (baseName === 'package.json') {
      dependencies.push(...collectPackageDependencies(file.path, file.content));
      continue;
    }

    if (baseName === 'pubspec.yaml') {
      dependencies.push(...(await collectPubspecDependencies(file.path, file.content)));
    }
  }

  return dependencies.sort((a, b) => `${a.name}:${a.scope}`.localeCompare(`${b.name}:${b.scope}`));
}

function buildImportGraph(codeFiles) {
  const graph = [];
  const importRegex = /(?:import|export)\s+['"]([^'"]+)['"]/g;

  for (const file of codeFiles) {
    const imports = [];
    let match;
    while ((match = importRegex.exec(file.content)) != null) {
      imports.push(match[1]);
    }

    graph.push({
      file: file.path,
      imports,
    });
  }

  return graph.sort((a, b) => a.file.localeCompare(b.file));
}

async function readGitMetadata() {
  const headPath = path.join(repoRoot, '.git', 'HEAD');
  const headContent = await fs.readFile(headPath, 'utf8');
  const refMatch = headContent.match(/^ref:\s+(.+)$/m);
  if (!refMatch) {
    return { head: headContent.trim() };
  }

  const refPath = path.join(repoRoot, '.git', refMatch[1].trim());
  const commit = await fs.readFile(refPath, 'utf8');
  return {
    head: commit.trim(),
    ref: refMatch[1].trim(),
  };
}

async function generateSnapshot() {
  const fileTree = await walkDirectory(repoRoot);
  const configFiles = await readFilesByPredicate(isConfigFile);
  const docs = await readFilesByPredicate(isDocFile);
  const codeFiles = await readFilesByPredicate(isCodeFile);
  const dependencyInventory = await buildDependencyInventory(configFiles);
  const importGraph = buildImportGraph(codeFiles);
  const gitMetadata = await readGitMetadata();

  return {
    schemaVersion: 1,
    generatedAt: new Date().toISOString(),
    projectRoot: 'c:/Users/49975/Desktop/智选',
    git: gitMetadata,
    fileTree,
    configFiles,
    docs,
    dependencyInventory,
    importGraph,
    businessFlows: [
      {
        name: 'media_upload_pipeline',
        path: [
          'packages/features/feature_video/lib/src/presentation/video_editor_screen.dart',
          'packages/core/core_network/lib/src/supabase_service.dart',
          'packages/core/core_network/r2_worker/src/index.js',
          'supabase/migrations/20260628153000_build_media_closure.sql',
        ],
      },
      {
        name: 'auth_session_pipeline',
        path: [
          'packages/core/core_network/lib/src/supabase_service.dart',
          'packages/features/feature_profile/lib/src/presentation/profile_screen.dart',
          'docs/auth-session-test-report-20260628.md',
        ],
      },
    ],
  };
}

function encryptSnapshot(snapshot) {
  const plainBuffer = Buffer.from(JSON.stringify(snapshot), 'utf8');
  const compressed = zlib.gzipSync(plainBuffer, { level: 9 });
  const salt = crypto.randomBytes(16);
  const iv = crypto.randomBytes(12);
  const key = crypto.pbkdf2Sync(MEMORY_PASSPHRASE, salt, PBKDF2_ITERATIONS, 32, 'sha256');
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
  const encrypted = Buffer.concat([cipher.update(compressed), cipher.final()]);
  const tag = cipher.getAuthTag();

  return {
    schemaVersion: 1,
    generatedAt: new Date().toISOString(),
    pbkdf2Iterations: PBKDF2_ITERATIONS,
    encryption: 'AES-256-GCM',
    compression: 'gzip',
    salt: salt.toString('base64'),
    iv: iv.toString('base64'),
    tag: tag.toString('base64'),
    payload: encrypted.toString('base64'),
    payloadSha256: sha256(encrypted),
  };
}

async function main() {
  const snapshot = await generateSnapshot();
  const payload = encryptSnapshot(snapshot);

  await fs.mkdir(outputDir, { recursive: true });
  await fs.writeFile(outputPath, `${JSON.stringify(payload, null, 2)}\n`, 'utf8');

  console.log(`Project memory snapshot updated: ${path.relative(repoRoot, outputPath)}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
