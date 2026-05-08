---
name: database-workflows
description: Reusable workflow for database schema, migration, Drizzle config, and local SQLite lifecycle changes in this repository. Use when adding or editing Drizzle schema files, generating or applying migrations, resetting or reseeding the local database, planning rollback steps, or validating migration history.
---

# Database Workflows

## Overview

Apply this skill whenever work touches the repository database contract, Drizzle schema, SQL migrations, migration tooling, or local database lifecycle. Prefer the root `just` commands over ad hoc `pnpm` or `drizzle-kit` commands so agents follow the same workflow.

## Start Here

- Run `just` from the repository root first and confirm the database recipes you need exist there.
- Read the current schema under `api/src/db/schema/` and the latest files in `api/drizzle/` before changing anything.
- Treat `api/src/env.ts`, `api/drizzle.config.ts`, `api/src/database/`, and `api/drizzle/` as one coordinated surface.
- Keep route and feature names separate from database naming. Database config should stay generic.

## Preferred Commands

- Generate a schema migration: `just db-generate`
- Generate a named schema migration: `just db-generate add_pokemon_forms`
- Generate an empty custom SQL migration: `just db-generate-custom revert_bad_seed`
- Apply unapplied migrations: `just db-migrate`
- Check migration history consistency: `just db-check`
- Upgrade Drizzle snapshot metadata after Drizzle upgrades: `just db-up`
- Reset the local repo database and recreate it from migrations: `just db-reset-local`
- Reset, recreate, and reseed the local repo database: `just db-reseed-local`

## Schema Change Workflow

1. Edit the Drizzle schema in `api/src/db/schema/`.
2. Generate a migration with `just db-generate <descriptive_name>`.
3. Review the generated SQL in `api/drizzle/` instead of trusting it blindly.
4. Apply the migration with `just db-migrate` if your task needs the local database updated.
5. Run narrow validation for the affected surface, then run the repository final gate when code changed.

## Migration Safety Rules

- Do not hand-edit `api/drizzle/meta/_journal.json` unless you are deliberately resolving a migration-history issue and understand the consequence.
- Do not delete previously committed migrations just to make a new schema diff cleaner.
- Prefer additive, reviewable migrations over `push`-style direct schema mutation.
- Keep migration names descriptive and scoped to the actual schema change.
- Review generated indexes, constraints, nullability, and foreign keys carefully because they affect runtime behavior as much as application code does.

## Rollback Strategy

- This repository does not use automatic down migrations as the default workflow.
- If a migration was committed but needs to be reversed, create a new custom SQL migration with `just db-generate-custom revert_<change>` and write explicit reverse SQL.
- SQLite squashes are exceptional maintenance work for an in-progress schema history, not the default workflow. When squashing, ensure `api/drizzle/0000_*.sql`, the matching `0000_snapshot.json`, and `meta/_journal.json` all describe the same single baseline schema.
- Apply the reverse migration with `just db-migrate`.
- For disposable local development data, prefer `just db-reset-local` or `just db-reseed-local` instead of editing migration history tables manually.
- Do not mutate `__drizzle_migrations` to fake a rollback unless the user explicitly asks for a repair workflow and you have explained the risk.

## Local Database Rules

- `just db-reset-local` is only for repo-local `file:` database URLs.
- If `DATABASE_URL` points outside the repository or to a remote database, stop and confirm the intended workflow instead of trying to reset it.
- After a reset, reseed only if the task depends on seed data.
- Keep feature tests isolated through their fixtures rather than sharing the dev database.

## Verification

- Run the narrowest useful command while iterating, such as `just db-check`, `just typecheck`, `just compile-api`, or targeted tests.
- Run `just ready` as the final verification for code changes.
- For docs-only updates to this skill or `AGENTS.md`, `just ready` is not required unless the user explicitly asks for it.

## Expected Output When Using This Skill

Finish by stating:

- which schema, migration, or database workflow you changed
- which `just` database commands you ran
- whether you applied migrations, generated custom SQL, or reset local data
- whether `just ready` passed, or why it was skipped
