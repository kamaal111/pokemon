set export
set dotenv-load

PN := "pnpm"
PNR := PN + " run"
PNX := PN + " exec"
UV := "uv"
UVR := UV + " run"

API_PORT := env("API_PORT", "8080")
APP_DERIVED_DATA_PATH := env("APP_DERIVED_DATA_PATH", "/tmp/pokemon-derived")
APP_PROJECT := "Pokemon.xcodeproj"
APP_SCHEME := "Pokemon"
APP_TEST_DESTINATION := env("APP_TEST_DESTINATION", "platform=iOS Simulator,name=iPhone 17")
OCR_LEXICON_OUTPUT_PATH := env(
    "OCR_LEXICON_OUTPUT_PATH",
    "app/Modules/PokemonFeatures/Sources/PokemonOcr/Internal/Resources/PokemonSpeciesLexicon.tsv"
)

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

# Regenerate the OCR species lexicon from the local seeded Pokedex SQLite database
generate-ocr-lexicon:
    #!/usr/bin/env zsh
    set -euo pipefail

    sqlite3 -separator $'\t' api/.data/pokemon.sqlite "
        select language_name, trim(name)
        from pokemon_species_names
        where language_name in ('en', 'ja', 'ja-hrkt', 'ko', 'zh-hans', 'zh-hant')
          and trim(name) <> ''
        group by language_name, name
        order by language_name, name;
    " > "{{ OCR_LEXICON_OUTPUT_PATH }}"

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

# Run all verification checks for app
ready-app: quality-app test-app

# Compile api
[working-directory("api")]
compile-api:
    {{ PNR }} compile

# Run tests
[parallel]
test: test-api test-skills test-app

# Run heavy tests
test-heavy: test

# Run api tests
[working-directory("api")]
test-api:
    {{ PNR }} test

# Run dependency-upgrade skill script tests
test-skills:
    {{ UVR }} -m unittest discover -s .agents/skills/dependency-upgrade-best-practices/tests -p 'test_*.py'

# Run app tests
[working-directory("app")]
test-app:
    xcodebuild \
        -project "{{ APP_PROJECT }}" \
        -scheme "{{ APP_SCHEME }}" \
        -sdk iphonesimulator \
        -destination "{{ APP_TEST_DESTINATION }}" \
        -derivedDataPath "{{ APP_DERIVED_DATA_PATH }}" \
        test

# Log available app destinations
[working-directory("app")]
app-destinations:
    xcodebuild \
        -showdestinations \
        -project "{{ APP_PROJECT }}" \
        -scheme "{{ APP_SCHEME }}" \
        -sdk iphonesimulator

    xcrun simctl list devices available

# Run quality checks
[parallel]
quality: lint format-check typecheck

# Run quality checks for api
[parallel]
quality-api: lint-api lint-sql format-check-api format-sql typecheck-api

# Run quality checks for app
quality-app: format-check-app

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
format: format-js format-sql format-app

# Format js code
format-js:
    {{ PNR }} format

# Format sql code
format-sql:
    {{ PNR }} format:sql

# Format app code
[working-directory("app")]
format-app:
    swift format --in-place -r .

# Check code formatting
[parallel]
format-check: format-check-js format-check-sql format-check-app

# Check js code formatting
format-check-js:
    {{ PNR }} format:check

# Check sql code formatting
format-check-sql:
    {{ PNR }} format:check:sql

# Check api code formatting
format-check-api:
    {{ PNR }} format:check:api

# Check app code formatting
[working-directory("app")]
format-check-app:
    swift format lint --strict -r .

# Prepare project to work with
prepare: install-modules prepare-api

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

# Open app in Xcode
[working-directory("app")]
xcode:
    open "{{ APP_PROJECT }}"

[private]
install-modules-ci: install-node-modules-ci

[private]
install-node-modules-ci:
    {{ PN }} install --frozen-lockfile
    just install-modules-api-ci

[private]
[working-directory("api")]
install-modules-api-ci:
    {{ PN }} install --frozen-lockfile

[private]
install-modules: install-node-modules

[private]
install-node-modules:
    #!/usr/bin/env zsh

    . ~/.zshrc || true
    echo "Y" | {{ PN }} i

[private]
[working-directory("api")]
install-modules-api:
    #!/usr/bin/env zsh

    . ~/.zshrc || true
    echo "Y" | {{ PN }} i --ignore-workspace
