import { describeRoute, resolver } from 'hono-openapi';
import z from 'zod';

import { OPENAPI_TAG } from '../constants';
import type { HonoContext } from '@/context';
import type { TypedResponse } from 'hono';
import { STATUS_CODES } from '@/constants/http';

type SeedPokeDexSuccessResponse = z.infer<typeof SeedPokeDexSuccessResponseSchema>;

const SeedPokeDexSuccessResponseSchema = z.object({
  saved: z.number().positive(),
});

function seedPokedexRoute() {
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
      return c.json({ saved: 0 }, STATUS_CODES.OK);
    },
  ] as const;
}

export default seedPokedexRoute;
