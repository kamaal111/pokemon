import { DatabaseSync } from 'node:sqlite';
import url from 'node:url';

import { createDatabase, type Database, type DatabaseConfig } from '../database/index.ts';
import { resetLocalDatabase } from '../database/local-reset.ts';

const REQUIRED_POKEDEX_SEED_TABLE_NAME = 'seed_sync_state';

export async function prepareDatabaseForPokedexSeed(
  databaseConfig: DatabaseConfig,
): Promise<Database> {
  const database = await createDatabase(databaseConfig);
  try {
    await database.migrate();
    if (hasTable(databaseConfig.url, REQUIRED_POKEDEX_SEED_TABLE_NAME)) {
      return database;
    }
  } catch (error) {
    database.close();
    throw error;
  }

  database.close();

  await resetLocalDatabase(databaseConfig);

  if (!hasTable(databaseConfig.url, REQUIRED_POKEDEX_SEED_TABLE_NAME)) {
    throw new Error(
      `Local database reset completed, but required table ${REQUIRED_POKEDEX_SEED_TABLE_NAME} is still missing.`,
    );
  }

  return createDatabase(databaseConfig);
}

function hasTable(databaseUrl: string, tableName: string): boolean {
  const database = new DatabaseSync(url.fileURLToPath(databaseUrl));
  try {
    const result = database
      .prepare("SELECT COUNT(*) AS count FROM sqlite_master WHERE type = 'table' AND name = ?")
      .get(tableName);

    return result != null && typeof result.count === 'number' && result.count > 0;
  } finally {
    database.close();
  }
}
