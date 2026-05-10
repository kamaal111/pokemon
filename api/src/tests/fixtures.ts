import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import url from 'node:url';

import { test as baseTest, vi } from 'vitest';

import createApp from '@/app';
import { createDatabase } from '@/database';
import { POKEAPI_SPECIES_PAGE_SIZE } from '@/seed/constants';
import { buildSpeciesListingUrl } from '@/seed/pokeapi';
import { clearPokemonSpeciesTables } from '@/seed/repository';
import type { SeedDependencies } from '@/seed/service';
import { createSpeciesDetail, jsonResponse } from './utils';

const DEFAULT_UPSTREAM_SPECIES_COUNT = 45;

export const integrationTest = baseTest
  .extend('_suitePrefix', { scope: 'file' }, 'pokemon-api-test')
  .extend('_suiteSetup', { scope: 'file' }, async ({ _suitePrefix }, { onCleanup }) => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), `${_suitePrefix}-`));
    const databasePath = path.join(tempDir, 'pokemon.sqlite');
    const databaseUrl = url.pathToFileURL(databasePath).toString();
    const database = await createDatabase({ url: databaseUrl });

    await database.migrate();

    onCleanup(async () => {
      database.close();
      await fs.rm(tempDir, { recursive: true, force: true });
    });

    return { database, databasePath, url: databaseUrl };
  })
  .extend('_testSetup', { auto: true }, async ({ _suiteSetup }, { onCleanup }) => {
    await clearPokemonSpeciesTables(_suiteSetup.database);

    const apiMock = createApiMock();
    const seedDependencies: SeedDependencies = {
      fetch: apiMock.fetch,
    };
    vi.stubGlobal('fetch', apiMock.fetch);

    onCleanup(() => {
      apiMock.reset();
      vi.unstubAllGlobals();
    });

    return {
      database: _suiteSetup.database,
      databasePath: _suiteSetup.databasePath,
      apiMock,
      app: createApp({
        databaseConfig: { url: _suiteSetup.url },
        pokedexSeedDependencies: seedDependencies,
      }),
      seedDependencies,
    };
  })
  .extend('database', ({ _testSetup }) => _testSetup.database)
  .extend('databasePath', ({ _testSetup }) => _testSetup.databasePath)
  .extend('apiMock', ({ _testSetup }) => _testSetup.apiMock)
  .extend('app', ({ _testSetup }) => _testSetup.app)
  .extend('seedDependencies', ({ _testSetup }) => _testSetup.seedDependencies);

function createSpeciesSummary(id: number) {
  return {
    name: `pokemon-${id}`,
    url: `https://pokeapi.co/api/v2/pokemon-species/${id}/`,
  };
}

function createSpeciesListResponse(offset: number, totalSpeciesCount: number) {
  const pageLength = Math.max(0, Math.min(POKEAPI_SPECIES_PAGE_SIZE, totalSpeciesCount - offset));
  const results = Array.from({ length: pageLength }, (_, index) => {
    return createSpeciesSummary(offset + index + 1);
  });
  const nextOffset = offset + POKEAPI_SPECIES_PAGE_SIZE;

  return {
    count: totalSpeciesCount,
    next: nextOffset >= totalSpeciesCount ? null : buildSpeciesListingUrl(nextOffset),
    previous:
      offset === 0 ? null : buildSpeciesListingUrl(Math.max(0, offset - POKEAPI_SPECIES_PAGE_SIZE)),
    results,
  };
}

function getRequestUrl(input: string | URL | Request): string {
  if (typeof input === 'string') {
    return input;
  }

  if (input instanceof URL) {
    return input.toString();
  }

  return input.url;
}

function createApiMock() {
  const urlOverrides = new Map<string, () => Response | Promise<Response>>();
  let totalSpeciesCount = DEFAULT_UPSTREAM_SPECIES_COUNT;
  const fetchMock = vi.fn<typeof fetch>(async (input) => {
    const url = getRequestUrl(input);
    const override = urlOverrides.get(url);

    if (override !== undefined) {
      return override();
    }

    return createDefaultApiResponse(url);
  });

  return {
    fetch: fetchMock,
    setTotalSpeciesCount(value: number) {
      totalSpeciesCount = value;
    },
    mockUrl(url: string, response: Response | (() => Response | Promise<Response>)) {
      urlOverrides.set(url, typeof response === 'function' ? response : () => response);
    },
    requestUrls() {
      return fetchMock.mock.calls.map(([input]) => getRequestUrl(input));
    },
    reset() {
      totalSpeciesCount = DEFAULT_UPSTREAM_SPECIES_COUNT;
      urlOverrides.clear();
      fetchMock.mockClear();
    },
  };

  function createDefaultApiResponse(url: string): Response {
    const parsedUrl = new URL(url);
    if (parsedUrl.pathname === '/api/v2/pokemon-species') {
      const offset = Number(parsedUrl.searchParams.get('offset') ?? '0');
      return jsonResponse(createSpeciesListResponse(offset, totalSpeciesCount));
    }

    const detailMatch = parsedUrl.pathname.match(/^\/api\/v2\/pokemon-species\/(\d+)\/?$/);

    if (detailMatch?.[1] !== undefined) {
      return jsonResponse(createSpeciesDetail(Number(detailMatch[1])));
    }

    throw new Error(`Unexpected fetch url: ${url}`);
  }
}
