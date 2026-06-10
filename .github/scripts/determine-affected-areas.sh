#!/bin/bash

set -euo pipefail

# Load configuration
config_file="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/config/affected-areas.conf"
if [[ ! -f "$config_file" ]]; then
  echo "Error: Configuration file not found at $config_file" >&2
  exit 1
fi
source "$config_file"

if [[ "$EVENT_NAME" == "push" && "$REF_NAME" == "main" ]]
then
  echo "api=true" >> "$GITHUB_OUTPUT"
  echo "app=true" >> "$GITHUB_OUTPUT"
  echo "skills=true" >> "$GITHUB_OUTPUT"
  echo "Running all jobs for pushes to main."
  exit 0
fi

git fetch --no-tags --prune --depth=1 origin main
base_commit="$(git merge-base HEAD origin/main)"
changed_files=()
while IFS= read -r -d '' file
do
  changed_files+=("$file")
done < <(git diff --name-only -z "$base_commit"...HEAD)

if ((${#changed_files[@]} == 0))
then
  echo "No files changed relative to origin/main."
else
  echo "Changed files relative to origin/main ($base_commit):"
  printf '%s\n' "${changed_files[@]}"
fi

api=false
app=false
skills=false

matches_any_pattern() {
  local file="$1"
  local pattern_list="$2"
  local pattern
  local patterns=()

  IFS='|' read -r -a patterns <<< "$pattern_list"
  for pattern in "${patterns[@]}"
  do
    if [[ "$file" == $pattern ]]
    then
      return 0
    fi
  done

  return 1
}

for file in "${changed_files[@]}"
do
  if matches_any_pattern "$file" "$BOTH"
  then
    api=true
    app=true
  elif matches_any_pattern "$file" "$API"
  then
    api=true
  elif matches_any_pattern "$file" "$APP"
  then
    app=true
  elif matches_any_pattern "$file" "$SKILLS"
  then
    skills=true
  fi
done

echo "api=$api" >> "$GITHUB_OUTPUT"
echo "app=$app" >> "$GITHUB_OUTPUT"
echo "skills=$skills" >> "$GITHUB_OUTPUT"
