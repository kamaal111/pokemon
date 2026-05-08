import type { SeedDependencies } from './service';

interface GetPokedexSeedDependenciesOptions {
  fetch?: typeof fetch;
}

export function getPokedexSeedDependencies(
  options: GetPokedexSeedDependenciesOptions,
): SeedDependencies {
  const { fetch: fetchImpl = fetch } = options;

  return { fetch: fetchImpl };
}
