#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

SCRIPTS_DIR="$ROOT_DIR/scripts"

BUILD_DIR="$ROOT_DIR/installer/build"
PKGS_DIR="$BUILD_DIR/pkgs"
DIST_DIR="$BUILD_DIR/dist"
REGISTRY_DIR="$BUILD_DIR/registry"

IDENTIFIER_PREFIX="io.benoitlahoz.millumin.scripts"

USER_LIB="$HOME/Library/Millumin"
USER_SCRIPTS_DIR="$USER_LIB/Scripts"
USER_REGISTRY_DIR="$HOME/Library/Application Support/$IDENTIFIER_PREFIX"

echo "🚀 Millumin Scripts Builder starting..."

echo "📂 ROOT: $ROOT_DIR"
echo "📂 SCRIPTS: $SCRIPTS_DIR"

# -------------------------
# CLEAN
# -------------------------
rm -rf "$BUILD_DIR"
mkdir -p "$PKGS_DIR"
mkdir -p "$DIST_DIR"
mkdir -p "$REGISTRY_DIR"

# -------------------------
# DISTRIBUTION XML START
# -------------------------
DISTRIBUTION_FILE="$BUILD_DIR/distribution.xml"

cat > "$DISTRIBUTION_FILE" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
<title>Millumin Scripts Installer</title>
<options customize="always" require-scripts="false"/>
<domains enable_anywhere="true"/>
<choices-outline>
EOF

CHOICES_XML=""
FOUND_ANY=0

# -------------------------
# CHECK ROOT
# -------------------------
if [ ! -d "$SCRIPTS_DIR" ]; then
    echo "❌ ERROR: scripts folder not found: $SCRIPTS_DIR"
    exit 1
fi

FOUND_DIRS=$(find "$SCRIPTS_DIR" -mindepth 1 -maxdepth 1 -type d)

if [ -z "$FOUND_DIRS" ]; then
    echo "❌ ERROR: no scripts found in $SCRIPTS_DIR"
    exit 1
fi

# -------------------------
# SCAN SCRIPTS
# -------------------------
for dir in $FOUND_DIRS; do

    [ -d "$dir" ] || continue

    MANIFEST="$dir/manifest.json"

    if [ ! -f "$MANIFEST" ]; then
        echo "⚠️  No manifest: $dir"
        continue
    fi

    echo "------------------------------"
    echo "📂 Script: $dir"

    NAME=$(jq -r '.name // empty' "$MANIFEST" 2>/dev/null)
    VERSION=$(jq -r '.version // "1.0.0"' "$MANIFEST" 2>/dev/null)
    CATEGORY=$(jq -r '.category // "Other"' "$MANIFEST" 2>/dev/null)
    INSTALL=$(jq -r '.install // true' "$MANIFEST" 2>/dev/null)

    echo "   name     = $NAME"
    echo "   version  = $VERSION"
    echo "   category = $CATEGORY"
    echo "   install  = $INSTALL"

    if [ "$INSTALL" != "true" ] && [ "$INSTALL" != true ]; then
        echo "⏭️ SKIP"
        continue
    fi

    ID=$(basename "$dir")
    PACKAGE_ID="$IDENTIFIER_PREFIX.$ID"

    echo "📦 Building: $ID"

    COMPONENT_PKG="$PKGS_DIR/$ID.pkg"

    # -------------------------
    # IMPORTANT: only JS file
    # -------------------------
    JS_FILE=$(find "$dir" -maxdepth 1 -name "*.js" | head -n 1)

    if [ -z "$JS_FILE" ]; then
        echo "⚠️ No JS file in $dir"
        continue
    fi

    TMP_ROOT="$BUILD_DIR/root/$ID"
    mkdir -p "$TMP_ROOT"

    cp "$JS_FILE" "$TMP_ROOT/"

    # -------------------------
    # BUILD PKG (USER LIBRARY)
    # -------------------------
    pkgbuild \
        --root "$TMP_ROOT" \
        --identifier "$PACKAGE_ID" \
        --version "$VERSION" \
        --install-location "$USER_SCRIPTS_DIR" \
        "$COMPONENT_PKG"

    FOUND_ANY=1

    # -------------------------
    # ADD TO REGISTRY
    # -------------------------
    cp "$MANIFEST" "$REGISTRY_DIR/$ID.json"

    # -------------------------
    # DISTRIBUTION XML
    # -------------------------
    cat >> "$DISTRIBUTION_FILE" <<EOF
    <line choice="$ID"/>
EOF

    CHOICES_XML+="
    <choice id=\"$ID\" title=\"$NAME\" start_selected=\"true\">
        <pkg-ref id=\"$PACKAGE_ID\"/>
    </choice>

    <pkg-ref id=\"$PACKAGE_ID\" version=\"$VERSION\" auth=\"root\">$ID.pkg</pkg-ref>
"

done

# -------------------------
# CLOSE XML
# -------------------------
cat >> "$DISTRIBUTION_FILE" <<EOF
</choices-outline>

$CHOICES_XML

</installer-gui-script>
EOF

# -------------------------
# CHECK EMPTY
# -------------------------
if [ "$FOUND_ANY" -eq 0 ]; then
    echo ""
    echo "❌ ERROR: No scripts with install=true found."
    exit 1
fi

# -------------------------
# BUILD FINAL PKG
# -------------------------
echo ""
echo "🔧 Building final installer..."

productbuild \
    --distribution "$DISTRIBUTION_FILE" \
    --package-path "$PKGS_DIR" \
    "$DIST_DIR/Millumin-Scripts.pkg"

echo ""
echo "✅ DONE"
echo "📦 Output:"
echo "   $DIST_DIR/Millumin-Scripts-Unsigned.pkg"

echo ""
echo "📁 Registry created at:"
echo "   $REGISTRY_DIR"