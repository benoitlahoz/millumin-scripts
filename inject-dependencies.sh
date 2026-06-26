#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="scripts"

process_file() {
  local FILE="$1"

  [[ -z "$FILE" || ! -f "$FILE" ]] && return 0

  if grep -q "// GENERATED:BEGIN" "$FILE"; then
    echo "⏭ skip: $FILE"
    return 0
  fi

  if ! grep -q "@ms:" "$FILE"; then
    return 0
  fi

  echo "→ processing $FILE"

  tmp="$(mktemp)"

  # ----------------------------
  # metadata
  # ----------------------------
  has_home=0
  grep -q "// @ms:home" "$FILE" && has_home=1

  libs=()
  while IFS= read -r line; do
    libs+=("${line//\/\/ @ms:lib /}")
  done < <(grep "// @ms:lib" "$FILE" || true)

  # ----------------------------
  # body clean
  # ----------------------------
  grep -v "// @ms:" "$FILE" > "$tmp"

  final="$(mktemp)"

  {
    # ============================
    # GENERATED BLOCK START
    # ============================
    echo "// GENERATED:BEGIN"
    echo "// Automatically generated: remove these lines if you don't use them"

    echo ""

    # HOME
    if [[ "$has_home" -eq 1 ]]; then
      echo "// @ms:home"
      echo 'const home = runAppleScript("do shell script \"echo $HOME\"")'
      echo 'const cleanedHome = home.replace("\n", "")'
      echo ""
    fi

    # LIBS (NO trailing empty noise)
    if [[ ${#libs[@]} -gt 0 ]]; then
      for lib in "${libs[@]}"; do
        [[ -z "$lib" ]] && continue
        echo "// @ms:lib $lib"
        echo "loadJSLibrary(base + \"$lib.js\")"
      done
      echo ""
    fi

    # END MARKER
    echo "// GENERATED:END"
    echo ""

    # ORIGINAL CODE (trimmed naturally by grep)
    cat "$tmp"

  } | awk 'NF { blank=0; print; next } !blank { blank=1; print }' \
    > "$final"

  mv "$final" "$FILE"
  rm -f "$tmp"
}

export -f process_file

find "$ROOT_DIR" -type f -name "*.js" -print0 |
while IFS= read -r -d '' file; do
  process_file "$file"
done

echo "✔ done"