import { getDatabaseConfig } from '../database/index.ts';
import { getPokedexSeedDependencies } from './config.ts';
import { prepareDatabaseForPokedexSeed } from './prepare-database.ts';
import { seedPokedex } from './service.ts';

async function run() {
  const database = await prepareDatabaseForPokedexSeed(getDatabaseConfig());

  try {
    const result = await seedPokedex({
      ...getPokedexSeedDependencies({}),
      database,
    });

    console.log(JSON.stringify(result));
  } finally {
    database.close();
  }
}

void run();
