import { defineConfig } from 'vitest/config';

import { SERVER_MODES } from './src/env';

export default defineConfig({
  resolve: {},
  test: {
    globals: true,
    environment: 'node',
    include: ['src/**/*.test.ts'],
    setupFiles: ['./src/tests/setup.ts'],
    env: {
      MODE: SERVER_MODES.TEST,
    },
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      include: ['src/**/*.ts'],
      exclude: [
        'node_modules/',
        'dist/',
        'src/tests/**',
        'src/db/schema/**',
        'src/index.ts',
        'src/server.ts',
        'src/seed/cli.ts',
        'src/database/reset-local.ts',
      ],
      thresholds: { statements: 100, branches: 100, functions: 100, lines: 100 },
    },
  },
});
