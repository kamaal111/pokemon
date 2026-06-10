import type { SeedDependencies } from './service.ts';

interface GetPokedexSeedDependenciesOptions {
  fetch?: typeof fetch;
}

export function getPokedexSeedDependencies(
  options: GetPokedexSeedDependenciesOptions,
): SeedDependencies {
  const { fetch: fetchImpl = fetch } = options;

  return { fetch: fetchImpl };
}

export const getCardSetsSeedDependencies = getPokedexSeedDependencies;
