import z from 'zod';

import {
  POKEAPI_POKEMON_SPECIES_URL,
  POKEAPI_SPECIES_PAGE_SIZE,
  POKEDEX_SEED_TARGET,
} from './constants';
import type { NormalizedPokemonSpecies } from './types';
import { normalizePokemonSpecies } from './normalize';

interface PokemonSpeciesSummary {
  id: number;
  name: string;
  url: string;
}

const ResourceSchema = z.object({ name: z.string().trim().min(1), url: z.url() });

const NullableResourceSchema = ResourceSchema.nullable();

const PokemonSpeciesListResponseSchema = z.object({
  count: z.number().int().nonnegative(),
  next: z.url().nullable(),
  previous: z.url().nullable(),
  results: z.array(ResourceSchema),
});

const PokemonSpeciesDetailSchema = z.object({
  id: z.number().int().positive(),
  name: z.string().trim().min(1),
  evolution_chain: z.object({ url: z.url() }),
  color: ResourceSchema,
  evolves_from_species: NullableResourceSchema,
  generation: ResourceSchema,
  habitat: NullableResourceSchema,
  is_baby: z.boolean(),
  is_legendary: z.boolean(),
  is_mythical: z.boolean(),
  names: z.array(z.object({ name: z.string().trim().min(1), language: ResourceSchema })),
  genera: z.array(z.object({ genus: z.string().trim().min(1), language: ResourceSchema })),
  pokedex_numbers: z.array(
    z.object({ entry_number: z.number().int().nonnegative(), pokedex: ResourceSchema }),
  ),
});

async function fetchJson<Schema extends z.ZodType>(
  url: string,
  schema: Schema,
  fetchImpl: typeof fetch,
): Promise<z.infer<Schema>> {
  const response = await fetchImpl(url);
  if (!response.ok) {
    throw new Error(`Failed to fetch ${url}: ${response.status}`);
  }

  const payload = await response.json();

  return schema.parse(payload);
}

export function buildSpeciesListingUrl(offset: number): string {
  const url = new URL(POKEAPI_POKEMON_SPECIES_URL);
  url.searchParams.set('offset', offset.toString());
  url.searchParams.set('limit', POKEAPI_SPECIES_PAGE_SIZE.toString());

  return url.toString();
}

function getSpeciesIdFromUrl(url: string): number {
  const match = url.match(/\/pokemon-species\/(\d+)\/?$/);
  const matchValue = match?.[1];
  if (matchValue == null) {
    throw new Error(`Could not determine species id from ${url}`);
  }

  return Number.parseInt(matchValue, 10);
}

export async function collectPokemonSpeciesSummaries(
  resumeOffset: number,
  fetchImpl: typeof fetch,
): Promise<PokemonSpeciesSummary[]> {
  const collectedSummaries = new Map<number, Omit<PokemonSpeciesSummary, 'id'>>();
  let nextUrl: string | null = buildSpeciesListingUrl(resumeOffset);
  while (nextUrl != null && collectedSummaries.size < POKEDEX_SEED_TARGET - resumeOffset) {
    const page: z.infer<typeof PokemonSpeciesListResponseSchema> = await fetchJson(
      nextUrl,
      PokemonSpeciesListResponseSchema,
      fetchImpl,
    );
    for (const summary of page.results) {
      const id = getSpeciesIdFromUrl(summary.url);
      if (id <= resumeOffset) {
        continue;
      }
      if (id > POKEDEX_SEED_TARGET) {
        continue;
      }
      if (collectedSummaries.has(id)) {
        continue;
      }

      collectedSummaries.set(id, { name: summary.name, url: summary.url });
      if (collectedSummaries.size >= POKEDEX_SEED_TARGET - resumeOffset) {
        break;
      }
    }

    nextUrl = page.next;
  }

  return collectedSummaries
    .entries()
    .map(([id, value]) => ({ ...value, id }))
    .toArray()
    .toSorted((left, right) => left.id - right.id);
}

export async function fetchPokemonSpeciesDetails(
  speciesSummaries: PokemonSpeciesSummary[],
  fetchImpl: typeof fetch,
): Promise<NormalizedPokemonSpecies[]> {
  const speciesDetails = await Promise.all(
    speciesSummaries.map(async (summary) => {
      const detail = await fetchJson(summary.url, PokemonSpeciesDetailSchema, fetchImpl);

      return normalizePokemonSpecies(detail);
    }),
  );

  return speciesDetails.toSorted((left, right) => left.id - right.id);
}
