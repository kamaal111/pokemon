import { createDatabase, getDatabaseConfig } from '@/database';
import { getPokedexSeedDependencies } from './config';
import { seedPokedex } from './service';

async function run() {
  const database = await createDatabase(getDatabaseConfig());

  try {
    await database.migrate();

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
