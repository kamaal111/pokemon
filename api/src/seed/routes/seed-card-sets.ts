import type { TypedResponse } from 'hono';
import { describeRoute, resolver } from 'hono-openapi';

import { OPENAPI_TAG } from '../constants.ts';
import { seedPokemonCardSets, type SeedDependencies } from '../service.ts';
import {
  SeedCardSetsSuccessResponseSchema,
  type SeedCardSetsSuccessResponse,
} from '../responses.ts';
import type { HonoContext } from '../../context.ts';
import { STATUS_CODES } from '../../constants/http.ts';

interface SeedCardSetsRouteDependencies {
  cardSetsSeedDependencies: SeedDependencies;
}

function seedCardSetsRoute(dependencies: SeedCardSetsRouteDependencies) {
  return [
    '/card-sets',
    describeRoute({
      description: 'Seed Pokemon card set database.',
      tags: [OPENAPI_TAG],
      responses: {
        [STATUS_CODES.OK]: {
          description: 'Successfully created seed for Pokemon card sets.',
          content: {
            'application/json': { schema: resolver(SeedCardSetsSuccessResponseSchema) },
          },
        },
      },
    }),
    async (
      c: HonoContext,
    ): Promise<TypedResponse<SeedCardSetsSuccessResponse, typeof STATUS_CODES.OK>> => {
      const result = await seedPokemonCardSets({
        ...dependencies.cardSetsSeedDependencies,
        now: c.get('theWorld').now,
        database: c.get('database'),
      });

      return c.json(
        SeedCardSetsSuccessResponseSchema.parse({ saved: result.saved }),
        STATUS_CODES.OK,
      );
    },
  ] as const;
}

export default seedCardSetsRoute;
