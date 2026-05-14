package_manager="$(
    sed -nE 's/^[[:space:]]*"packageManager"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' package.json
)"

if [[ "$package_manager" != pnpm@* ]]
then
    echo "package.json packageManager must be set to pnpm@<version>" >&2
    exit 1
fi

printf '%s\n' "${package_manager#pnpm@}"
