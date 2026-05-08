import env from '@/env';

const { DATABASE_URL, DATABASE_AUTH_TOKEN } = env;

export interface DatabaseConfig {
  authToken?: string;
  url: string;
}

export function getDatabaseConfig(): DatabaseConfig {
  return { url: DATABASE_URL, authToken: DATABASE_AUTH_TOKEN };
}
