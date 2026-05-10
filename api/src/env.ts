import z from 'zod';

export type ServerMode = (typeof SERVER_MODES)[keyof typeof SERVER_MODES];

export type LogLevel = (typeof LOG_LEVELS)[keyof typeof LOG_LEVELS];

export const SERVER_MODES = {
  API: 'API',
  SEED: 'SEED',
  TEST: 'TEST',
} as const;

const LOG_LEVELS = {
  FATAL: 'fatal',
  ERROR: 'error',
  WARN: 'warn',
  INFO: 'info',
  DEBUG: 'debug',
  TRACE: 'trace',
  SILENT: 'silent',
} as const;

const DEFAULT_DATABASE_URL = new URL('../.data/pokemon.sqlite', import.meta.url).toString();

const EnvSchema = z.object({
  PORT: z.coerce.number().gte(1000).lt(10_000).default(8080),
  DEBUG: z.coerce.boolean().default(false),
  MODE: z
    .string()
    .toUpperCase()
    .pipe(z.enum(Object.values(SERVER_MODES)))
    .default(SERVER_MODES.API),
  LOG_LEVEL: z.enum(Object.values(LOG_LEVELS)).default(LOG_LEVELS.INFO),
  DATABASE_URL: z.string().trim().min(1).default(DEFAULT_DATABASE_URL),
  DATABASE_AUTH_TOKEN: z.string().trim().min(1).optional(),
  POKEDEX_SEED_COOLDOWN_DAYS: z.coerce.number().int().positive().default(1),
});

const env = EnvSchema.parse(process.env);

export const IS_TEST = env.MODE === SERVER_MODES.TEST;
export const IS_DEBUG = env.DEBUG;

export default env;
