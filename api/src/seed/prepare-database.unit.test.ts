import fs from 'node:fs/promises';
import path from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import url from 'node:url';

import { beforeEach, describe, expect, test, vi } from 'vitest';

const { createDatabaseMock, resetLocalDatabaseMock } = vi.hoisted(() => {
  return {
    createDatabaseMock: vi.fn(),
    resetLocalDatabaseMock: vi.fn(),
  };
});

vi.mock('../database/index.ts', () => ({
  createDatabase: createDatabaseMock,
}));

vi.mock('../database/local-reset.ts', () => ({
  resetLocalDatabase: resetLocalDatabaseMock,
}));

import { prepareDatabaseForPokedexSeed } from './prepare-database.ts';

const LOCAL_DATA_DIRECTORY_PATH = url.fileURLToPath(new URL('../../.data/', import.meta.url));

describe('prepareDatabaseForPokedexSeed unit cases', () => {
  beforeEach(() => {
    createDatabaseMock.mockReset();
    resetLocalDatabaseMock.mockReset();
  });

  test('closes the database when migrate fails', async () => {
    const migrate = vi.fn(async () => {
      throw new Error('migrate failed');
    });
    const close = vi.fn();

    createDatabaseMock.mockResolvedValue({ migrate, close });

    await expect(
      prepareDatabaseForPokedexSeed({
        url: url
          .pathToFileURL(path.join(LOCAL_DATA_DIRECTORY_PATH, 'migrate-failure.sqlite'))
          .toString(),
      }),
    ).rejects.toThrow('migrate failed');

    expect(close).toHaveBeenCalledTimes(1);
    expect(resetLocalDatabaseMock).not.toHaveBeenCalled();
  });

  test('returns the migrated database without resetting when the required table already exists', async () => {
    await fs.mkdir(LOCAL_DATA_DIRECTORY_PATH, { recursive: true });
    const tempDir = await fs.mkdtemp(
      path.join(LOCAL_DATA_DIRECTORY_PATH, 'pokemon-api-seed-ready-test-'),
    );
    const databasePath = path.join(tempDir, 'pokemon.sqlite');
    const databaseUrl = url.pathToFileURL(databasePath).toString();
    const sqliteDatabase = new DatabaseSync(databasePath);
    sqliteDatabase.exec(
      'CREATE TABLE seed_sync_state (seed_name text PRIMARY KEY NOT NULL, last_successful_sync_at text NOT NULL);',
    );
    sqliteDatabase.close();

    const database = {
      migrate: vi.fn(async () => undefined),
      close: vi.fn(),
    };
    createDatabaseMock.mockResolvedValue(database);

    try {
      await expect(prepareDatabaseForPokedexSeed({ url: databaseUrl })).resolves.toBe(database);

      expect(database.close).not.toHaveBeenCalled();
      expect(resetLocalDatabaseMock).not.toHaveBeenCalled();
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });

  test('fails clearly when the required table is still missing after a local reset', async () => {
    await fs.mkdir(LOCAL_DATA_DIRECTORY_PATH, { recursive: true });
    const tempDir = await fs.mkdtemp(
      path.join(LOCAL_DATA_DIRECTORY_PATH, 'pokemon-api-seed-repair-failure-test-'),
    );
    const databasePath = path.join(tempDir, 'pokemon.sqlite');
    const databaseUrl = url.pathToFileURL(databasePath).toString();
    const sqliteDatabase = new DatabaseSync(databasePath);
    sqliteDatabase.close();

    const migrate = vi.fn(async () => undefined);
    const close = vi.fn();
    createDatabaseMock.mockResolvedValue({ migrate, close });
    resetLocalDatabaseMock.mockResolvedValue({ databasePath });

    try {
      await expect(prepareDatabaseForPokedexSeed({ url: databaseUrl })).rejects.toThrow(
        'Local database reset completed, but required table seed_sync_state is still missing.',
      );

      expect(close).toHaveBeenCalledTimes(1);
      expect(resetLocalDatabaseMock).toHaveBeenCalledWith({ url: databaseUrl });
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });
});
