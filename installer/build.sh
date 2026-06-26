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

INSTALL_NAMESPACE="io.benoitlahoz.millumin.scripts"

# ✅ Chemin relatif au home (sans $HOME) pour pkgbuild
USER_SCRIPTS_DIR="Library/Millumin/Scripts/$INSTALL_NAMESPACE"
USER_REGISTRY_DIR="Library/Application Support/$IDENTIFIER_PREFIX"

echo "🚀 Millumin Scripts Builder starting..."
echo "📂 ROOT: $ROOT_DIR"
echo "📂 SCRIPTS: $SCRIPTS_DIR"

rm -rf "$BUILD_DIR"
mkdir -p "$PKGS_DIR"
mkdir -p "$DIST_DIR"
mkdir -p "$REGISTRY_DIR"

DISTRIBUTION_FILE="$BUILD_DIR/distribution.xml"

cat > "$DISTRIBUTION_FILE" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
<title>Millumin Scripts Installer</title>
<options customize="always" require-scripts="false"/>
<domains enable_anywhere="false" enable_currentUserHome="true" enable_localSystem="false"/>
<choices-outline>
EOF

CHOICES_XML=""
FOUND_ANY=0

if [ ! -d "$SCRIPTS_DIR" ]; then
    echo "❌ ERROR: scripts folder not found"
    exit 1
fi

FOUND_DIRS=$(find "$SCRIPTS_DIR" -mindepth 1 -maxdepth 1 -type d)

for dir in $FOUND_DIRS; do

    MANIFEST="$dir/manifest.json"

    if [ ! -f "$MANIFEST" ]; then
        echo "⚠️ No manifest: $dir"
        continue
    fi

    NAME=$(jq -r '.name // empty' "$MANIFEST")
    VERSION=$(jq -r '.version // "1.0.0"' "$MANIFEST")
    INSTALL=$(jq -r '.install // true' "$MANIFEST")

    echo "📂 Script: $dir"
    echo "   name = $NAME"

    if [ "$INSTALL" != "true" ]; then
        echo "⏭️ SKIP"
        continue
    fi

    # -------------------------
    # FIND JS FILE
    # -------------------------
    JS_FILE=$(find "$dir" -maxdepth 1 -name "*.js" | head -n 1)

    if [ -z "$JS_FILE" ]; then
        echo "⚠️ No JS file in $dir"
        continue
    fi

    # -------------------------
    # REAL FILE NAME
    # -------------------------
    JS_FILENAME=$(basename "$JS_FILE")

    PACKAGE_ID="$IDENTIFIER_PREFIX.$JS_FILENAME"

    echo "📦 Building: $JS_FILENAME"

    COMPONENT_PKG="$PKGS_DIR/$JS_FILENAME.pkg"

    # -------------------------
    # TMP STAGING
    # -------------------------
    TMP_ROOT="/tmp/millumin_pkg_${JS_FILENAME}"
    rm -rf "$TMP_ROOT"
    mkdir -p "$TMP_ROOT"

    cp "$JS_FILE" "$TMP_ROOT/$JS_FILENAME"

    # -------------------------
    # PREINSTALL SCRIPT
    # Crée le dossier de destination s'il n'existe pas,
    # sans toucher à ce qui existe déjà.
    # -------------------------
    SCRIPTS_DIR_PKG="$PKGS_DIR/scripts_${JS_FILENAME}"
    mkdir -p "$SCRIPTS_DIR_PKG"

    cat > "$SCRIPTS_DIR_PKG/preinstall" <<PREINSTALL
#!/bin/bash
DEST="\$HOME/Library/Millumin/Scripts/$INSTALL_NAMESPACE"
mkdir -p "\$DEST"
exit 0
PREINSTALL

    chmod +x "$SCRIPTS_DIR_PKG/preinstall"

    pkgbuild \
        --root "$TMP_ROOT" \
        --identifier "$PACKAGE_ID" \
        --version "$VERSION" \
        --scripts "$SCRIPTS_DIR_PKG" \
        --install-location "$USER_SCRIPTS_DIR" \
        "$COMPONENT_PKG"

    FOUND_ANY=1

    cp "$MANIFEST" "$REGISTRY_DIR/$JS_FILENAME.json"

    cat >> "$DISTRIBUTION_FILE" <<EOF
    <line choice="$JS_FILENAME"/>
EOF

    CHOICES_XML+="
    <choice id=\"$JS_FILENAME\" title=\"$NAME\" start_selected=\"true\">
        <pkg-ref id=\"$PACKAGE_ID\"/>
    </choice>

    <pkg-ref id=\"$PACKAGE_ID\" version=\"$VERSION\" auth=\"root\">$JS_FILENAME.pkg</pkg-ref>
"

done

cat >> "$DISTRIBUTION_FILE" <<EOF
</choices-outline>

$CHOICES_XML

</installer-gui-script>
EOF

if [ "$FOUND_ANY" -eq 0 ]; then
    echo "❌ ERROR: No scripts found"
    exit 1
fi

echo "🔧 Building final installer..."

productbuild \
    --distribution "$DISTRIBUTION_FILE" \
    --package-path "$PKGS_DIR" \
    "$DIST_DIR/Millumin-Scripts-Unsigned.pkg"

echo "✅ DONE"
echo "📦 Output:"
echo "   $DIST_DIR/Millumin-Scripts-Unsigned.pkg"

echo "📁 Registry:"
echo "   $REGISTRY_DIR"