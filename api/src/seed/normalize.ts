import type { NormalizedPokemonSpecies } from './types.ts';

interface PokemonSpeciesDetailInput {
  id: number;
  name: string;
  evolution_chain: {
    url: string;
  };
  color: {
    name: string;
    url: string;
  };
  evolves_from_species: {
    name: string;
    url: string;
  } | null;
  generation: {
    name: string;
    url: string;
  };
  habitat: {
    name: string;
    url: string;
  } | null;
  is_baby: boolean;
  is_legendary: boolean;
  is_mythical: boolean;
  names: {
    name: string;
    language: {
      name: string;
      url: string;
    };
  }[];
  genera: {
    genus: string;
    language: {
      name: string;
      url: string;
    };
  }[];
  pokedex_numbers: {
    entry_number: number;
    pokedex: {
      name: string;
      url: string;
    };
  }[];
}

export function normalizePokemonSpecies(
  species: PokemonSpeciesDetailInput,
): NormalizedPokemonSpecies {
  return {
    id: species.id,
    name: species.name,
    colorName: species.color.name,
    evolvesFromSpeciesName: species.evolves_from_species?.name ?? null,
    generationName: species.generation.name,
    habitatName: species.habitat?.name ?? null,
    isBaby: species.is_baby,
    isLegendary: species.is_legendary,
    isMythical: species.is_mythical,
    names: species.names.map((name) => ({
      name: name.name,
      languageName: name.language.name,
    })),
    genera: species.genera.map((genus) => ({
      genus: genus.genus,
      languageName: genus.language.name,
    })),
    pokedexNumbers: species.pokedex_numbers.map((pokedexNumber) => ({
      entryNumber: pokedexNumber.entry_number,
      pokedexName: pokedexNumber.pokedex.name,
    })),
  };
}
