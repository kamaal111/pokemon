export function createSpeciesDetail(id: number) {
  return {
    id,
    name: `pokemon-${id}`,
    evolution_chain: {
      url: `https://pokeapi.co/api/v2/evolution-chain/${id}/`,
    },
    color: {
      name: `color-${id}`,
      url: `https://pokeapi.co/api/v2/pokemon-color/${id}/`,
    },
    evolves_from_species:
      id === 1
        ? null
        : {
            name: `pokemon-${id - 1}`,
            url: `https://pokeapi.co/api/v2/pokemon-species/${id - 1}/`,
          },
    generation: {
      name: 'generation-i',
      url: 'https://pokeapi.co/api/v2/generation/1/',
    },
    habitat:
      id % 2 === 0
        ? null
        : {
            name: 'grassland',
            url: 'https://pokeapi.co/api/v2/pokemon-habitat/3/',
          },
    is_baby: false,
    is_legendary: false,
    is_mythical: false,
    names: [
      {
        name: `Pokemon ${id}`,
        language: {
          name: 'en',
          url: 'https://pokeapi.co/api/v2/language/9/',
        },
      },
    ],
    genera: [
      {
        genus: 'Seed Pokemon',
        language: {
          name: 'en',
          url: 'https://pokeapi.co/api/v2/language/9/',
        },
      },
    ],
    pokedex_numbers: [
      {
        entry_number: id,
        pokedex: {
          name: 'national',
          url: 'https://pokeapi.co/api/v2/pokedex/1/',
        },
      },
    ],
  };
}

export function jsonResponse(payload: object, init: ResponseInit = { status: 200 }) {
  return new Response(JSON.stringify(payload), init);
}
