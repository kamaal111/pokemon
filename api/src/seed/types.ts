interface PokemonSpeciesTranslation {
  name: string;
  languageName: string;
}

interface PokemonSpeciesGenus {
  genus: string;
  languageName: string;
}

interface PokemonSpeciesPokedexNumber {
  entryNumber: number;
  pokedexName: string;
}

export interface NormalizedPokemonSpecies {
  id: number;
  name: string;
  colorName: string;
  evolvesFromSpeciesName: string | null;
  generationName: string;
  habitatName: string | null;
  isBaby: boolean;
  isLegendary: boolean;
  isMythical: boolean;
  names: PokemonSpeciesTranslation[];
  genera: PokemonSpeciesGenus[];
  pokedexNumbers: PokemonSpeciesPokedexNumber[];
}

export interface PokemonCardSet {
  code: string;
  name: string;
  region: string;
  source: string;
  ptcgoCode: string | null;
}
