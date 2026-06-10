import z from 'zod';

export type SeedPokeDexSuccessResponse = z.infer<typeof SeedPokeDexSuccessResponseSchema>;
export type SeedCardSetsSuccessResponse = z.infer<typeof SeedCardSetsSuccessResponseSchema>;

export const SeedPokeDexSuccessResponseSchema = z.object({
  saved: z.number().int().nonnegative(),
});

export const SeedCardSetsSuccessResponseSchema = z.object({
  saved: z.number().int().nonnegative(),
});
