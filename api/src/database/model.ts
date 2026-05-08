import url from 'node:url';

import { createClient, type Client } from '@libsql/client';
import { drizzle, type LibSQLDatabase } from 'drizzle-orm/libsql';
import { migrate } from 'drizzle-orm/libsql/migrator';

import * as schema from '@/db/schema';
import type { DatabaseConfig } from './config';

const MIGRATIONS_FOLDER_PATH = url.fileURLToPath(new URL('../../drizzle', import.meta.url));

class Database {
  readonly db: LibSQLDatabase<typeof schema>;

  private readonly client: Client;
  private readonly __brand!: void;

  constructor(config: DatabaseConfig) {
    this.client = createClient({ url: config.url, authToken: config.authToken });
    this.db = drizzle({ client: this.client, schema });
  }

  migrate = () => migrate(this.db, { migrationsFolder: MIGRATIONS_FOLDER_PATH });

  close = () => this.client.close();
}

export default Database;
