import path from 'node:path';
import url from 'node:url';

import { describe, expect, test } from 'vitest';

import { getLocalDatabasePath } from './local-reset';

describe('local reset helpers', () => {
  test('rejects non-file database URLs', () => {
    expect(() => getLocalDatabasePath('libsql://example.test/database')).toThrow(
      'db:reset-local only supports file: DATABASE_URL values, received: libsql://example.test/database',
    );
  });

  test('rejects database files outside the repository root', () => {
    const outsideRepositoryUrl = url.pathToFileURL(path.join('/tmp', 'pokemon.sqlite')).toString();

    expect(() => getLocalDatabasePath(outsideRepositoryUrl)).toThrow(
      `Refusing to delete database outside repository root: /tmp/pokemon.sqlite. Set DATABASE_URL to a repo-local file: URL before using db:reset-local.`,
    );
  });
});
