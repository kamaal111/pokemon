import env from '../env.ts';
import { resetLocalDatabase } from './local-reset.ts';

async function run(): Promise<void> {
  const { databasePath } = await resetLocalDatabase({
    url: env.DATABASE_URL,
    authToken: env.DATABASE_AUTH_TOKEN,
  });

  console.log(JSON.stringify({ reset: true, databasePath }));
}

void run();
