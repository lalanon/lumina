#!/usr/bin/env bash
set -euo pipefail

TAXONOMY_JSON="config/taxonomy.json"
LIBRARY_ROOT="${1:-$HOME/LuminaLibrary}"

if [[ ! -f "$TAXONOMY_JSON" ]]; then
  echo "❌ taxonomy.json not found"
  exit 1
fi

echo "📚 Creating taxonomy directories in:"
echo "   $LIBRARY_ROOT"
echo

mkdir -p "$LIBRARY_ROOT"

jq -r '
  to_entries[] |
  .key as $root |
  .value |
  if type == "object" then
    keys[] | [$root, .]
  elif type == "array" then
    .[] | [$root, .]
  else
    empty
  end |
  @tsv
' "$TAXONOMY_JSON" |
while IFS=$'\t' read -r root second; do
  dir="$LIBRARY_ROOT/$root/$second"
  mkdir -p "$dir"
  echo "✔ $dir"
done

echo
echo "✅ Taxonomy directory structure complete."
