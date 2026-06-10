import { getDatabaseConfig } from '../database/index.ts';
import { getCardSetsSeedDependencies, getPokedexSeedDependencies } from './config.ts';
import { prepareDatabaseForPokedexSeed } from './prepare-database.ts';
import { seedPokedex, seedPokemonCardSets } from './service.ts';

async function run() {
  const database = await prepareDatabaseForPokedexSeed(getDatabaseConfig());

  try {
    const seedName = process.argv[2] ?? 'pokedex';
    const result =
      seedName === 'card-sets'
        ? await seedPokemonCardSets({
            ...getCardSetsSeedDependencies({}),
            database,
          })
        : await seedPokedex({
            ...getPokedexSeedDependencies({}),
            database,
          });

    console.log(JSON.stringify(result));
  } finally {
    database.close();
  }
}

void run();
