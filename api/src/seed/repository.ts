import { asc, between, eq, inArray } from 'drizzle-orm';

import {
  pokemonSpecies,
  pokemonSpeciesGenera,
  pokemonSpeciesNames,
  pokemonSpeciesPokedexNumbers,
} from '@/db/schema';
import { POKEDEX_SEED_TARGET } from './constants';
import type { NormalizedPokemonSpecies } from './types';
import type { Database } from '@/database';

export async function getContiguousSeededPrefix(database: Database): Promise<number> {
  const rows = await database.db
    .select({ id: pokemonSpecies.id })
    .from(pokemonSpecies)
    .where(between(pokemonSpecies.id, 1, POKEDEX_SEED_TARGET))
    .orderBy(asc(pokemonSpecies.id));
  let expectedId = 1;
  for (const row of rows) {
    if (row.id !== expectedId) {
      break;
    }

    expectedId += 1;
  }

  return expectedId - 1;
}

export async function getExistingSpeciesIds(
  database: Database,
  speciesIds: number[],
): Promise<Set<number>> {
  if (speciesIds.length === 0) {
    return new Set();
  }

  const rows = await database.db
    .select({ id: pokemonSpecies.id })
    .from(pokemonSpecies)
    .where(inArray(pokemonSpecies.id, speciesIds));

  return new Set(rows.map((row) => row.id));
}

export async function insertPokemonSpecies(
  database: Database,
  species: NormalizedPokemonSpecies,
  seededAt: string,
): Promise<number> {
  return database.db.transaction(async (transaction) => {
    const existingSpecies = await transaction
      .select({ id: pokemonSpecies.id })
      .from(pokemonSpecies)
      .where(eq(pokemonSpecies.id, species.id))
      .limit(1);
    if (existingSpecies.length > 0) {
      return 0;
    }

    await transaction.insert(pokemonSpecies).values({
      id: species.id,
      name: species.name,
      colorName: species.colorName,
      evolvesFromSpeciesName: species.evolvesFromSpeciesName,
      generationName: species.generationName,
      habitatName: species.habitatName,
      isBaby: species.isBaby,
      isLegendary: species.isLegendary,
      isMythical: species.isMythical,
      seededAt,
    });

    if (species.names.length > 0) {
      await transaction.insert(pokemonSpeciesNames).values(
        species.names.map((name) => ({
          pokemonSpeciesId: species.id,
          languageName: name.languageName,
          name: name.name,
        })),
      );
    }

    if (species.genera.length > 0) {
      await transaction.insert(pokemonSpeciesGenera).values(
        species.genera.map((genus) => ({
          pokemonSpeciesId: species.id,
          languageName: genus.languageName,
          genus: genus.genus,
        })),
      );
    }

    if (species.pokedexNumbers.length > 0) {
      await transaction.insert(pokemonSpeciesPokedexNumbers).values(
        species.pokedexNumbers.map((pokedexNumber) => ({
          pokemonSpeciesId: species.id,
          pokedexName: pokedexNumber.pokedexName,
          entryNumber: pokedexNumber.entryNumber,
        })),
      );
    }

    return 1;
  });
}

export async function clearPokemonSpeciesTables(database: Database): Promise<void> {
  await database.db.delete(pokemonSpeciesNames);
  await database.db.delete(pokemonSpeciesGenera);
  await database.db.delete(pokemonSpeciesPokedexNumbers);
  await database.db.delete(pokemonSpecies);
}

export async function countPokemonSpecies(database: Database): Promise<number> {
  const rows = await database.db.select({ id: pokemonSpecies.id }).from(pokemonSpecies);

  return rows.length;
}
