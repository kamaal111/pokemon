# Repository Guidelines

## Start Here

- Run `just` from the repository root first so you can discover the current command surface and prefer repo recipes over ad hoc commands.
- Run commands from the repository root unless a command explicitly requires a package directory.
- Look for existing patterns before writing code. Match surrounding structure, naming, validation, error handling, and test style unless there is a strong reason to introduce something new.

## Critical Development Rules

- **ALWAYS verify your work with relevant commands before claiming completion**
  - Run the narrowest useful checks while iterating.
  - Run `just ready` from the repository root as the final verification for code changes.
  - For docs-only changes, such as `AGENTS.md`, `README.md`, or skill files, do not run `just ready` unless the user explicitly asks for it.
- **NEVER claim code changes are done until `just ready` passes**
  - If `just ready` fails, fix the issues and rerun it until it succeeds.
- **ALWAYS include proof of work in the final response**
  - Tell the user exactly how you validated the work.
  - List the commands, builds, tests, or manual checks you ran.
  - If you skipped validation, say so explicitly and why.
- **ALWAYS use `pnpm` for Node.js work**
  - Do not use `npm` or `yarn` anywhere in this repository.
- **ALWAYS use root `just` commands when they exist**
  - Prefer repo recipes over custom command sequences for build, test, quality, database, and OpenAPI workflows.
- **NEVER start the server directly or as a background process**
  - Do not use `node ... &`, `pnpm start &`, `tsx ... &`, or similar patterns.
  - Only use `just dev-api` if the user explicitly asks you to start the server.
- **NEVER suppress lint or type errors**
  - Do not add lint-disable comments, `@ts-ignore`, or `@ts-expect-error`.
- **NEVER use TypeScript type assertions or casting**
  - Do not use `as Type` or `<Type>value`.
- **ALWAYS use the `testing-best-practices` skill for test changes**
  - Apply this skill whenever writing, maintaining, or modifying tests.
- **ALWAYS use the `typescript-server-best-practices` skill for TypeScript server work**
  - Apply this skill whenever implementing, maintaining, or refactoring server-side TypeScript code.
- **ALWAYS use the `dependency-upgrade-best-practices` skill for dependency updates**
  - Apply this skill whenever upgrading, pinning, or auditing dependencies.
- **ALWAYS use the `gh-actions-log-debug` skill for CI failure triage**
  - Apply this skill whenever investigating or fixing GitHub Actions failures.
- **ALWAYS use the `database-workflows` skill for database work**
  - Apply this skill whenever changing Drizzle schema files, SQL migrations, Drizzle config, database env contracts, or local database lifecycle workflows.
- **ALWAYS validate unknown or external data**
  - Use Zod at boundaries instead of forcing types through.
- **ALWAYS enforce user ownership when querying user-scoped resources**
  - Do not query by client-supplied resource IDs alone when the resource should belong to the authenticated user.
  - Scope reads and writes through the requesting user's owned parent record or an equivalent ownership constraint in the query itself.
  - Treat any uncertainty about ownership as a real security bug, not a follow-up cleanup.
- **NEVER hide required dependency failures behind misleading success responses**
  - If required derived data is missing, fail clearly instead of returning a superficially valid response that breaks downstream assumptions.

## Verification Commands

- Use `just lint` for linting changes.
- Use `just format` or `just format-check` for formatting changes.
- Use `just typecheck` for TypeScript type changes.
- Use `just compile-api` for server compilation changes.
- Use `just test` for server or app behavior changes.
- Run `just ready` last for code changes.
