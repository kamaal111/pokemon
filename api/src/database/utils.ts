import fs from 'node:fs/promises';
import url from 'node:url';

import Database from './model';
import type { DatabaseConfig } from './config';

const ENSURED_DATABASE_DIRECTORIES = new Set<string>();

export async function createDatabase(config: DatabaseConfig): Promise<Database> {
  await ensureLocalDatabaseDirectory(config.url);

  return new Database(config);
}

async function ensureLocalDatabaseDirectory(databaseUrl: string) {
  if (!databaseUrl.startsWith('file:')) {
    throw new Error('database url must start with `file:`');
  }

  const databasePath = url.fileURLToPath(databaseUrl);
  const databaseDirectoryPath = url.fileURLToPath(new URL('.', databaseUrl));

  if (!ENSURED_DATABASE_DIRECTORIES.has(databaseDirectoryPath)) {
    await fs.mkdir(databaseDirectoryPath, { recursive: true });
  }

  ENSURED_DATABASE_DIRECTORIES.add(databaseDirectoryPath);

  if (databasePath.endsWith('/')) {
    throw new Error(
      `Expected DATABASE_URL to reference a file, received directory URL: ${databaseUrl}`,
    );
  }
}
