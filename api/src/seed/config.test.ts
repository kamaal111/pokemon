import { describe, expect, test, vi } from 'vitest';

import { getPokedexSeedDependencies } from './config';

describe('getPokedexSeedDependencies', () => {
  test('uses the provided fetch implementation', () => {
    const fetchImpl = vi.fn<typeof fetch>();

    expect(getPokedexSeedDependencies({ fetch: fetchImpl })).toEqual({ fetch: fetchImpl });
  });

  test('defaults to the global fetch implementation', () => {
    expect(getPokedexSeedDependencies({})).toEqual({ fetch });
  });
});
