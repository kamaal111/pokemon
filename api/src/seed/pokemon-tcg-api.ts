import z from 'zod';

import {
  ENGLISH_CARD_SETS_REGION_NAME,
  ENGLISH_CARD_SETS_SOURCE_NAME,
  POKEMON_TCG_API_CARD_SETS_URL,
} from './constants.ts';
import type { PokemonCardSet } from './types.ts';

const CardSetCodeSchema = z
  .string()
  .trim()
  .regex(/^(?=.*[a-z])[a-z0-9-]{1,16}$/i);

const PokemonTcgApiSetSchema = z.object({
  id: CardSetCodeSchema,
  name: z.string().trim().min(1),
  ptcgoCode: CardSetCodeSchema.optional(),
});

const PokemonTcgApiSetsResponseSchema = z.object({
  data: z.array(PokemonTcgApiSetSchema),
});

const CardSetSchema = z.object({
  code: z.string().trim().min(1),
  name: z.string().trim().min(1),
  region: z.literal(ENGLISH_CARD_SETS_REGION_NAME),
  source: z.literal(ENGLISH_CARD_SETS_SOURCE_NAME),
  ptcgoCode: z.string().trim().min(1).nullable(),
});

export async function fetchPokemonTcgApiEnglishCardSets(
  fetchImpl: typeof fetch,
): Promise<PokemonCardSet[]> {
  const response = await fetchImpl(POKEMON_TCG_API_CARD_SETS_URL);
  if (!response.ok) {
    throw new Error(`Failed to fetch ${POKEMON_TCG_API_CARD_SETS_URL}: ${response.status}`);
  }

  return parsePokemonTcgApiEnglishCardSets(await response.json());
}

export function parsePokemonTcgApiEnglishCardSets(value: unknown): PokemonCardSet[] {
  const parsedResponse = PokemonTcgApiSetsResponseSchema.parse(value);

  return parsedResponse.data
    .map((cardSet) =>
      CardSetSchema.parse({
        code: cardSet.id.toLowerCase(),
        name: cardSet.name,
        region: ENGLISH_CARD_SETS_REGION_NAME,
        source: ENGLISH_CARD_SETS_SOURCE_NAME,
        ptcgoCode: cardSet.ptcgoCode?.toLowerCase() ?? null,
      }),
    )
    .toSorted((left, right) => left.code.localeCompare(right.code));
}
