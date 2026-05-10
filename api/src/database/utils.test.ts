import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import url from 'node:url';

import { describe, expect, test } from 'vitest';

import { getDatabaseConfig } from './config';
import { createDatabase } from './utils';

describe('database utilities', () => {
  test('reads database configuration from the environment module', () => {
    expect(getDatabaseConfig()).toEqual({
      url: expect.stringContaining('pokemon.sqlite'),
      authToken: undefined,
    });
  });

  test('creates local database directories once for file URLs', async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), 'pokemon-api-db-test-'));
    const databaseUrl = url
      .pathToFileURL(path.join(tempDir, 'nested', 'pokemon.sqlite'))
      .toString();

    const firstDatabase = await createDatabase({ url: databaseUrl });
    const secondDatabase = await createDatabase({ url: databaseUrl });

    firstDatabase.close();
    secondDatabase.close();
    await expect(fs.stat(path.join(tempDir, 'nested'))).resolves.toMatchObject({
      isDirectory: expect.any(Function),
    });
    await fs.rm(tempDir, { recursive: true, force: true });
  });

  test('rejects non-file database URLs', async () => {
    await expect(createDatabase({ url: 'libsql://example.test/database' })).rejects.toThrow(
      'database url must start with `file:`',
    );
  });

  test('rejects directory database URLs', async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), 'pokemon-api-db-directory-test-'));
    const databaseUrl = url.pathToFileURL(`${tempDir}${path.sep}`).toString();

    await expect(createDatabase({ url: databaseUrl })).rejects.toThrow(
      `Expected DATABASE_URL to reference a file, received directory URL: ${databaseUrl}`,
    );
    await fs.rm(tempDir, { recursive: true, force: true });
  });
});
