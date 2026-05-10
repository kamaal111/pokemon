import type { TypedResponse } from 'hono';
import { describeRoute, resolver } from 'hono-openapi';

import { OPENAPI_TAG } from '../constants.ts';
import type { HonoContext } from '../../context.ts';
import { STATUS_CODES } from '../../constants/http.ts';
import { seedPokedex, type SeedDependencies } from '../service.ts';
import { SeedPokeDexSuccessResponseSchema, type SeedPokeDexSuccessResponse } from '../responses.ts';

interface SeedPokedexRouteDependencies {
  pokedexSeedDependencies: SeedDependencies;
}

function seedPokedexRoute(dependencies: SeedPokedexRouteDependencies) {
  return [
    '/pokedex',
    describeRoute({
      description: 'Seed Pokedex database.',
      tags: [OPENAPI_TAG],
      responses: {
        [STATUS_CODES.OK]: {
          description: 'Successfully created seed for Pokedex database.',
          content: {
            'application/json': { schema: resolver(SeedPokeDexSuccessResponseSchema) },
          },
        },
      },
    }),
    async (
      c: HonoContext,
    ): Promise<TypedResponse<SeedPokeDexSuccessResponse, typeof STATUS_CODES.OK>> => {
      const result = await seedPokedex({
        ...dependencies.pokedexSeedDependencies,
        now: c.get('theWorld').now,
        database: c.get('database'),
      });

      return c.json(
        SeedPokeDexSuccessResponseSchema.parse({ saved: result.saved }),
        STATUS_CODES.OK,
      );
    },
  ] as const;
}

export default seedPokedexRoute;
