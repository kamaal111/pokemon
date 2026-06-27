import type { Database } from '../database/index.ts';
import {
  getContiguousSeededPrefix,
  getLastSuccessfulSeedSyncAt,
  getExistingSpeciesIds,
  insertPokemonSpecies,
  markSuccessfulNamedSeedSync,
  markSuccessfulSeedSync,
  upsertPokemonCardSets,
} from './repository.ts';
import { CARD_SETS_SEED_SYNC_STATE_NAME } from './constants.ts';
import {
  collectPokemonSpeciesSummaries,
  fetchPokemonSpeciesDetails,
  fetchPokemonSpeciesPage,
} from './pokeapi.ts';
import { fetchLimitlessJapaneseCardSets } from './limitless.ts';
import { fetchPokemonTcgApiEnglishCardSets } from './pokemon-tcg-api.ts';
import type { SeedCardSetsSuccessResponse, SeedPokeDexSuccessResponse } from './responses.ts';
import env from '../env.ts';

export interface SeedDependencies {
  fetch: typeof fetch;
}

interface SeedOptions extends SeedDependencies {
  database: Database;
  now?: () => Date;
}

export async function seedPokedex(options: SeedOptions): Promise<SeedPokeDexSuccessResponse> {
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

export async function seedPokemonCardSets(
  options: SeedOptions,
): Promise<SeedCardSetsSuccessResponse> {
  const [japaneseCardSets, englishCardSets] = await Promise.all([
    fetchLimitlessJapaneseCardSets(options.fetch),
    fetchPokemonTcgApiEnglishCardSets(options.fetch),
  ]);
  const resolveNow = options.now ?? (() => new Date());
  const seededAt = resolveNow().toISOString();
  const saved = await upsertPokemonCardSets(options.database, [
    ...japaneseCardSets,
    ...englishCardSets,
  ]);

  await markSuccessfulNamedSeedSync(options.database, CARD_SETS_SEED_SYNC_STATE_NAME, seededAt);

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
