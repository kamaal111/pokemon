import { spawnSync } from 'node:child_process';
import { readdirSync } from 'node:fs';
import { join } from 'node:path';

const sqlDirectoryPath = join(process.cwd(), 'api', 'drizzle');
const sqlFilePaths = readdirSync(sqlDirectoryPath)
  .filter((fileName) => fileName.endsWith('.sql'))
  .sort()
  .map((fileName) => join(sqlDirectoryPath, fileName));

const mode = process.argv[2];

if (mode !== '--fix' && mode !== '--check') {
  throw new Error(`Unsupported mode: ${mode}`);
}

for (const sqlFilePath of sqlFilePaths) {
  const args = ['--language', 'sqlite'];

  if (mode === '--fix') {
    args.push('--fix');
  } else {
    args.push('--output', '/dev/null');
  }

  args.push(sqlFilePath);

  const result = spawnSync('sql-formatter', args, { stdio: 'inherit' });

  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
}
