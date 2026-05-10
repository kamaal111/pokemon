import type { Database } from '../database/index.ts';
import {
  getContiguousSeededPrefix,
  getLastSuccessfulSeedSyncAt,
  getExistingSpeciesIds,
  insertPokemonSpecies,
  markSuccessfulSeedSync,
} from './repository.ts';
import {
  collectPokemonSpeciesSummaries,
  fetchPokemonSpeciesDetails,
  fetchPokemonSpeciesPage,
} from './pokeapi.ts';
import type { SeedPokeDexSuccessResponse } from './responses.ts';
import env from '../env.ts';

export interface SeedDependencies {
  fetch: typeof fetch;
}

interface SeedPokedexOptions extends SeedDependencies {
  database: Database;
  now?: () => Date;
}

export async function seedPokedex(
  options: SeedPokedexOptions,
): Promise<SeedPokeDexSuccessResponse> {
  const firstPage = await fetchPokemonSpeciesPage(0, options.fetch);
  const lastSuccessfulSeedSyncAt = await getLastSuccessfulSeedSyncAt(options.database);
  const resolveNow = options.now ?? (() => new Date());
  if (isCooldownActive(lastSuccessfulSeedSyncAt, env.POKEDEX_SEED_COOLDOWN_DAYS, resolveNow())) {
    return { saved: 0 };
  }

  const upstreamTotal = firstPage.count;
  const contiguousSeededPrefix = await getContiguousSeededPrefix(options.database);
  if (contiguousSeededPrefix >= upstreamTotal) {
    await markSuccessfulSeedSync(options.database, resolveNow().toISOString());
    return { saved: 0 };
  }

  const candidateSpeciesSummaries = await collectPokemonSpeciesSummaries(
    contiguousSeededPrefix,
    upstreamTotal,
    firstPage,
    options.fetch,
  );
  const existingSpeciesIds = await getExistingSpeciesIds(
    options.database,
    candidateSpeciesSummaries.map((species) => species.id),
  );
  const missingSpeciesSummaries = candidateSpeciesSummaries.filter(
    (species) => !existingSpeciesIds.has(species.id),
  );
  if (missingSpeciesSummaries.length === 0) {
    await markSuccessfulSeedSync(options.database, resolveNow().toISOString());
    return { saved: 0 };
  }

  const seededAt = resolveNow().toISOString();
  const normalizedPokemonSpecies = await fetchPokemonSpeciesDetails(
    missingSpeciesSummaries,
    options.fetch,
  );

  let saved = 0;
  for (const species of normalizedPokemonSpecies) {
    saved += await insertPokemonSpecies(options.database, species, seededAt);
  }

  const finalContiguousSeededPrefix = await getContiguousSeededPrefix(options.database);
  if (finalContiguousSeededPrefix >= upstreamTotal) {
    await markSuccessfulSeedSync(options.database, resolveNow().toISOString());
  }

  return { saved };
}

function isCooldownActive(
  lastSuccessfulSeedSyncAt: string | null,
  cooldownDays: number,
  now: Date,
): boolean {
  if (lastSuccessfulSeedSyncAt == null) {
    return false;
  }

  const lastSuccessfulSeedSyncDate = new Date(lastSuccessfulSeedSyncAt);
  const cooldownMilliseconds = cooldownDays * 24 * 60 * 60 * 1000;

  return now.getTime() - lastSuccessfulSeedSyncDate.getTime() < cooldownMilliseconds;
}
