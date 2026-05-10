set export
set dotenv-load

PN := "pnpm"
PNR := PN + " run"
PNX := PN + " exec"
TSX := PNX + " tsx"

API_PORT := env("API_PORT", "8080")

# List available commands
default:
    just --list --unsorted

# Run dev api
[working-directory("api")]
dev-api: prepare-api
    #!/usr/bin/env zsh

    export DEBUG="true"
    export PORT="{{ API_PORT }}"
    export MODE="api"

    {{ PNR }} dev

# Seed the pokedex SQLite database
[working-directory("api")]
seed-pokedex:
    {{ PNR }} seed:pokedex

# Generate a database migration from the Drizzle schema. Optional: just db-generate create_pokemon_types
[working-directory("api")]
db-generate name="":
    #!/usr/bin/env zsh

    if [[ -n "{{ name }}" ]]; then
        {{ PNX }} drizzle-kit generate --name "{{ name }}"
    else
        {{ PNR }} db:generate
    fi

# Generate an empty custom SQL migration, useful for manual data fixes or rollback migrations. Usage: just db-generate-custom revert_bad_seed
[working-directory("api")]
db-generate-custom name:
    {{ PNX }} drizzle-kit generate --custom --name "{{ name }}"

# Apply unapplied database migrations
[working-directory("api")]
db-migrate:
    {{ PNR }} db:migrate

# Check the database migration history for conflicts
[working-directory("api")]
db-check:
    {{ PNR }} db:check

# Upgrade Drizzle migration snapshots after Drizzle version changes
[working-directory("api")]
db-up:
    {{ PNR }} db:up

# Reset the local repo database file and recreate it from migrations
[working-directory("api")]
db-reset-local:
    {{ PNR }} db:reset-local

# Reset the local repo database file, recreate it from migrations, and reseed the pokedex
[working-directory("api")]
db-reseed-local: db-reset-local
    {{ PNR }} seed:pokedex

# Run all verification checks
ready: _ready-tasks

# Run all verification checks for the api
[parallel]
ready-api: quality-api test-api

# Compile api
[working-directory("api")]
compile-api:
    {{ PNR }} compile

# Run tests
[parallel]
test: test-api test-skills

# Run api tests
[working-directory("api")]
test-api:
    {{ PNR }} test

# Run dependency-upgrade skill script tests
test-skills:
    python3 -m unittest discover -s .agents/skills/dependency-upgrade-best-practices/tests -p 'test_*.py'

# Run quality checks
[parallel]
quality: lint format-check typecheck

# Run quality checks for api
[parallel]
quality-api: lint-api lint-sql format-check-api format-sql typecheck-api

# Type check
typecheck: typecheck-api

# Type check api
[working-directory("api")]
typecheck-api:
    {{ PNR }} typecheck

# Lint the project
[parallel]
lint: lint-js lint-sql

# Lint js code
lint-js:
    {{ PNR }} lint

# Lint sql code
lint-sql:
    {{ PNR }} lint:sql

# Lint api code
lint-api:
    {{ PNR }} lint:api

# Format code
[parallel]
format: format-js format-sql

# Format js code
format-js:
    {{ PNR }} format

# Format sql code
format-sql:
    {{ PNR }} format:sql

# Check code formatting
[parallel]
format-check: format-check-js format-check-sql

# Check js code formatting
format-check-js:
    {{ PNR }} format:check

# Check sql code formatting
format-check-sql:
    {{ PNR }} format:check:sql

# Check api code formatting
format-check-api:
    {{ PNR }} format:check:api

# Prepare project to work with
prepare: install-modules prepare-api

# Prepare api
prepare-api: install-modules-api

# Prepare api for Linux CI
[linux]
prepare-api-ci: install-modules-ci

# Bootstrap project
bootstrap: prepare bootstrap-api

# Bootstrap api
bootstrap-api: prepare-api

# Open project in zed
z:
    zed .

# Open project in vscode
code:
    code pokemon.code-workspace

[private]
[parallel]
_ready-tasks: quality test

[private]
install-modules-ci:
    pnpm install --frozen-lockfile
    pnpm --dir api install --frozen-lockfile --ignore-workspace

[private]
install-modules:
    #!/usr/bin/env zsh

    . ~/.zshrc || true
    echo "Y" | {{ PN }} i

[private]
[working-directory("api")]
install-modules-api:
    #!/usr/bin/env zsh

    . ~/.zshrc || true
    echo "Y" | {{ PN }} i --ignore-workspace
