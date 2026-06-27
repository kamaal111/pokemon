import { index, integer, primaryKey, sqliteTable, text } from 'drizzle-orm/sqlite-core';

export const pokemonSpecies = sqliteTable(
  'pokemon_species',
  {
    id: integer('id').primaryKey(),
    name: text('name').notNull().unique(),
    colorName: text('color_name').notNull(),
    evolvesFromSpeciesName: text('evolves_from_species_name'),
    generationName: text('generation_name').notNull(),
    habitatName: text('habitat_name'),
    isBaby: integer('is_baby', { mode: 'boolean' }).notNull(),
    isLegendary: integer('is_legendary', { mode: 'boolean' }).notNull(),
    isMythical: integer('is_mythical', { mode: 'boolean' }).notNull(),
    seededAt: text('seeded_at').notNull(),
  },
  (table) => [index('pokemon_species_name_index').on(table.name)],
);

export const pokemonSpeciesNames = sqliteTable(
  'pokemon_species_names',
  {
    pokemonSpeciesId: integer('pokemon_species_id')
      .notNull()
      .references(() => pokemonSpecies.id, { onDelete: 'cascade' }),
    languageName: text('language_name').notNull(),
    name: text('name').notNull(),
  },
  (table) => [
    primaryKey({ columns: [table.pokemonSpeciesId, table.languageName] }),
    index('pokemon_species_names_species_id_index').on(table.pokemonSpeciesId),
  ],
);

export const pokemonSpeciesGenera = sqliteTable(
  'pokemon_species_genera',
  {
    pokemonSpeciesId: integer('pokemon_species_id')
      .notNull()
      .references(() => pokemonSpecies.id, { onDelete: 'cascade' }),
    languageName: text('language_name').notNull(),
    genus: text('genus').notNull(),
  },
  (table) => [
    primaryKey({ columns: [table.pokemonSpeciesId, table.languageName] }),
    index('pokemon_species_genera_species_id_index').on(table.pokemonSpeciesId),
  ],
);

export const pokemonSpeciesPokedexNumbers = sqliteTable(
  'pokemon_species_pokedex_numbers',
  {
    pokemonSpeciesId: integer('pokemon_species_id')
      .notNull()
      .references(() => pokemonSpecies.id, { onDelete: 'cascade' }),
    pokedexName: text('pokedex_name').notNull(),
    entryNumber: integer('entry_number').notNull(),
  },
  (table) => [
    primaryKey({ columns: [table.pokemonSpeciesId, table.pokedexName] }),
    index('pokemon_species_pokedex_numbers_species_id_index').on(table.pokemonSpeciesId),
  ],
);

export const pokemonCardSets = sqliteTable(
  'pokemon_card_sets',
  {
    code: text('code').notNull(),
    name: text('name').notNull(),
    region: text('region').notNull(),
    source: text('source').notNull(),
    ptcgoCode: text('ptcgo_code'),
  },
  (table) => [primaryKey({ columns: [table.region, table.code] })],
);

export const seedSyncState = sqliteTable('seed_sync_state', {
  seedName: text('seed_name').primaryKey(),
  lastSuccessfulSyncAt: text('last_successful_sync_at').notNull(),
});
