import z from 'zod';

export type SeedPokeDexSuccessResponse = z.infer<typeof SeedPokeDexSuccessResponseSchema>;

export const SeedPokeDexSuccessResponseSchema = z.object({
  saved: z.number().int().nonnegative(),
});
