CREATE TABLE `pokemon_card_sets` (
  `code` text NOT NULL,
  `name` text NOT NULL,
  `region` text NOT NULL,
  `source` text NOT NULL,
  `ptcgo_code` text,
  PRIMARY KEY (`region`, `code`)
);

--> statement-breakpoint
CREATE TABLE `pokemon_species` (
  `id` integer PRIMARY KEY NOT NULL,
  `name` text NOT NULL,
  `color_name` text NOT NULL,
  `evolves_from_species_name` text,
  `generation_name` text NOT NULL,
  `habitat_name` text,
  `is_baby` integer NOT NULL,
  `is_legendary` integer NOT NULL,
  `is_mythical` integer NOT NULL,
  `seeded_at` text NOT NULL
);

--> statement-breakpoint
CREATE UNIQUE INDEX `pokemon_species_name_unique` ON `pokemon_species` (`name`);

--> statement-breakpoint
CREATE INDEX `pokemon_species_name_index` ON `pokemon_species` (`name`);

--> statement-breakpoint
CREATE TABLE `pokemon_species_genera` (
  `pokemon_species_id` integer NOT NULL,
  `language_name` text NOT NULL,
  `genus` text NOT NULL,
  PRIMARY KEY (`pokemon_species_id`, `language_name`),
  FOREIGN KEY (`pokemon_species_id`) REFERENCES `pokemon_species` (`id`) ON UPDATE no action ON DELETE cascade
);

--> statement-breakpoint
CREATE INDEX `pokemon_species_genera_species_id_index` ON `pokemon_species_genera` (`pokemon_species_id`);

--> statement-breakpoint
CREATE TABLE `pokemon_species_names` (
  `pokemon_species_id` integer NOT NULL,
  `language_name` text NOT NULL,
  `name` text NOT NULL,
  PRIMARY KEY (`pokemon_species_id`, `language_name`),
  FOREIGN KEY (`pokemon_species_id`) REFERENCES `pokemon_species` (`id`) ON UPDATE no action ON DELETE cascade
);

--> statement-breakpoint
CREATE INDEX `pokemon_species_names_species_id_index` ON `pokemon_species_names` (`pokemon_species_id`);

--> statement-breakpoint
CREATE TABLE `pokemon_species_pokedex_numbers` (
  `pokemon_species_id` integer NOT NULL,
  `pokedex_name` text NOT NULL,
  `entry_number` integer NOT NULL,
  PRIMARY KEY (`pokemon_species_id`, `pokedex_name`),
  FOREIGN KEY (`pokemon_species_id`) REFERENCES `pokemon_species` (`id`) ON UPDATE no action ON DELETE cascade
);

--> statement-breakpoint
CREATE INDEX `pokemon_species_pokedex_numbers_species_id_index` ON `pokemon_species_pokedex_numbers` (`pokemon_species_id`);

--> statement-breakpoint
CREATE TABLE `seed_sync_state` (
  `seed_name` text PRIMARY KEY NOT NULL,
  `last_successful_sync_at` text NOT NULL
);
