import { getDatabaseConfig } from '@/database';
import { getPokedexSeedDependencies } from './config';
import { prepareDatabaseForPokedexSeed } from './prepare-database';
import { seedPokedex } from './service';

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
