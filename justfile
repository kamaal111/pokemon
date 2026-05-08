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
test: test-api

# Run api tests
[working-directory("api")]
test-api:
    {{ PNR }} test

# Run quality checks
[parallel]
quality: lint format-check typecheck

# Run quality checks for api
[parallel]
quality-api: lint-api format-check-api typecheck-api

# Type check
typecheck: typecheck-api

# Type check api
[working-directory("api")]
typecheck-api:
    {{ PNR }} typecheck

# Lint the project
lint: lint-js

# Lint js code
lint-js:
    {{ PNR }} lint

# Lint api code
lint-api:
    {{ PNR }} lint:api

# Format code
format: format-js

# Format js code
format-js:
    {{ PNR }} format

# Check code formatting
format-check: format-check-js

# Check js code formatting
format-check-js:
    {{ PNR }} format:check

# Check api code formatting
format-check-api:
    {{ PNR }} format:check:api

# Prepare project to work with
prepare: install-modules prepare-api

# Prepare api
prepare-api: install-modules-api

# Bootstrap project
bootstrap: prepare bootstrap-api

# Bootstrap api
bootstrap-api: prepare-api

# Open project in zed
zed:
    zed .

# Open project in vscode
code:
    code pokemon.code-workspace

[private]
[parallel]
_ready-tasks: quality test

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
    echo "Y" | {{ PN }} i
