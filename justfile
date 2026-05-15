set export
set dotenv-load

PN := "pnpm"
PNR := PN + " run"
PNX := PN + " exec"
UV := "uv"
UVR := UV + " run"

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

# Run dev ocr
[working-directory("ocr")]
dev-ocr: prepare-ocr
    {{ UVR }} src/main.py

# Seed the pokedex SQLite database
[working-directory("api")]
seed-pokedex:
    {{ PNR }} seed:pokedex

# Print the pnpm version declared in package.json
pnpm-version:
    bash scripts/pnpm-version.bash

# Generate a database migration from the Drizzle schema. Optional: just db-generate create_pokemon_types
[working-directory("api")]
db-generate name="":
    #!/usr/bin/env zsh

    if [[ -n "{{ name }}" ]]
    then
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
[parallel]
ready: quality test

# Run all heavy verification checks
[parallel]
heavy: quality test-heavy

# Run all verification checks for the api
[parallel]
ready-api: quality-api test-api

# Run all verification checks for ocr
ready-ocr: quality-ocr test-ocr

# Compile api
[working-directory("api")]
compile-api:
    {{ PNR }} compile

# Run tests
[parallel]
test: test-api test-skills

# Run heavy tests
[parallel]
test-heavy: test-api test-ocr test-skills

# Run api tests
[working-directory("api")]
test-api:
    {{ PNR }} test

# Run ocr tests
[working-directory("ocr")]
test-ocr:
    {{ UVR }} pytest -vv --durations=0 tests

# Run dependency-upgrade skill script tests
test-skills:
    {{ UVR }} -m unittest discover -s .agents/skills/dependency-upgrade-best-practices/tests -p 'test_*.py'

# Run quality checks
[parallel]
quality: lint format-check typecheck

# Run quality checks for api
[parallel]
quality-api: lint-api lint-sql format-check-api format-sql typecheck-api

# Run quality checks for ocr
[parallel]
quality-ocr: lint-ocr format-check-ocr typecheck-ocr

# Type check
[parallel]
typecheck: typecheck-api typecheck-ocr

# Type check api
[working-directory("api")]
typecheck-api:
    {{ PNR }} typecheck

# Type check ocr
[working-directory("ocr")]
typecheck-ocr:
    {{ UVR }} ty check src tests

# Lint the project
[parallel]
lint: lint-js lint-sql lint-ocr

# Lint js code
lint-js:
    {{ PNR }} lint

# Lint sql code
lint-sql:
    {{ PNR }} lint:sql

# Lint api code
lint-api:
    {{ PNR }} lint:api

# Lint ocr code
[working-directory("ocr")]
lint-ocr:
    {{ UVR }} ruff check src tests

# Format code
[parallel]
format: format-js format-sql format-ocr

# Format js code
format-js:
    {{ PNR }} format

# Format sql code
format-sql:
    {{ PNR }} format:sql

# Format ocr code
[working-directory("ocr")]
format-ocr:
    {{ UVR }} ruff format src tests

# Check code formatting
[parallel]
format-check: format-check-js format-check-sql format-check-ocr

# Check js code formatting
format-check-js:
    {{ PNR }} format:check

# Check sql code formatting
format-check-sql:
    {{ PNR }} format:check:sql

# Check api code formatting
format-check-api:
    {{ PNR }} format:check:api

# Check ocr code formatting
[working-directory("ocr")]
format-check-ocr:
    {{ UVR }} ruff format --check src tests

# Prepare project to work with
prepare: install-modules prepare-api

# Prepare ocr
prepare-ocr: install-modules-ocr

# Prepare api
prepare-api: install-modules-api

# Prepare api for Linux CI
[linux]
prepare-api-ci: install-node-modules-ci

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
install-modules-ci: install-node-modules-ci install-python-modules

[private]
install-node-modules-ci:
    {{ PN }} install --frozen-lockfile
    just install-modules-api-ci

[private]
[working-directory("api")]
install-modules-api-ci:
    {{ PN }} install --frozen-lockfile

[private]
[parallel]
install-modules: install-node-modules install-python-modules

[private]
install-node-modules:
    #!/usr/bin/env zsh

    . ~/.zshrc || true
    echo "Y" | {{ PN }} i

[private]
install-modules-ocr: install-python-modules

[private]
install-python-modules:
    {{ UV }} sync

[private]
[working-directory("api")]
install-modules-api:
    #!/usr/bin/env zsh

    . ~/.zshrc || true
    echo "Y" | {{ PN }} i --ignore-workspace
