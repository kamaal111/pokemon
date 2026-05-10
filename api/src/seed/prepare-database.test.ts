import fs from 'node:fs/promises';
import path from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import url from 'node:url';

import { describe, expect, test } from 'vitest';

import { createDatabase } from '../database/index.ts';
import { prepareDatabaseForPokedexSeed } from './prepare-database.ts';

const LOCAL_DATA_DIRECTORY_PATH = url.fileURLToPath(new URL('../../.data/', import.meta.url));

describe('prepareDatabaseForPokedexSeed', () => {
  test('resets a stale repo-local database when the squashed baseline is missing seed_sync_state', async () => {
    await fs.mkdir(LOCAL_DATA_DIRECTORY_PATH, { recursive: true });
    const tempDir = await fs.mkdtemp(
      path.join(LOCAL_DATA_DIRECTORY_PATH, 'pokemon-api-seed-repair-test-'),
    );
    const databasePath = path.join(tempDir, 'pokemon.sqlite');
    const databaseUrl = url.pathToFileURL(databasePath).toString();

    try {
      const initialDatabase = await createDatabase({ url: databaseUrl });
      await initialDatabase.migrate();
      initialDatabase.close();

      const staleDatabase = new DatabaseSync(databasePath);
      staleDatabase.exec('DROP TABLE seed_sync_state;');
      expect(
        staleDatabase
          .prepare(
            "SELECT COUNT(*) AS count FROM sqlite_master WHERE type = 'table' AND name = 'seed_sync_state'",
          )
          .get(),
      ).toEqual({ count: 0 });
      staleDatabase.close();

      const repairedDatabase = await prepareDatabaseForPokedexSeed({ url: databaseUrl });
      repairedDatabase.close();

      const verifiedDatabase = new DatabaseSync(databasePath);
      expect(
        verifiedDatabase
          .prepare(
            "SELECT COUNT(*) AS count FROM sqlite_master WHERE type = 'table' AND name = 'seed_sync_state'",
          )
          .get(),
      ).toEqual({ count: 1 });
      expect(
        verifiedDatabase.prepare('SELECT COUNT(*) AS count FROM __drizzle_migrations').get(),
      ).toEqual({ count: 1 });
      verifiedDatabase.close();
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });
});
