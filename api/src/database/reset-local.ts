import fs from 'node:fs/promises';
import path from 'node:path';
import url from 'node:url';

import env from '@/env';
import { createDatabase } from './utils';

const REPOSITORY_ROOT_PATH = url.fileURLToPath(new URL('../../../', import.meta.url));

async function run(): Promise<void> {
  const databasePath = getLocalDatabasePath(env.DATABASE_URL);

  await fs.rm(databasePath, { force: true });

  const database = await createDatabase({
    url: env.DATABASE_URL,
    authToken: env.DATABASE_AUTH_TOKEN,
  });
  try {
    await database.migrate();
  } finally {
    database.close();
  }

  console.log(JSON.stringify({ reset: true, databasePath }));
}

function getLocalDatabasePath(databaseUrl: string): string {
  if (!databaseUrl.startsWith('file:')) {
    throw new Error(
      `db:reset-local only supports file: DATABASE_URL values, received: ${databaseUrl}`,
    );
  }

  const databasePath = url.fileURLToPath(databaseUrl);
  const relativeDatabasePath = path.relative(REPOSITORY_ROOT_PATH, databasePath);
  if (
    relativeDatabasePath.startsWith('..') ||
    path.isAbsolute(relativeDatabasePath) ||
    relativeDatabasePath === ''
  ) {
    throw new Error(
      `Refusing to delete database outside repository root: ${databasePath}. ` +
        'Set DATABASE_URL to a repo-local file: URL before using db:reset-local.',
    );
  }

  return databasePath;
}

void run();
