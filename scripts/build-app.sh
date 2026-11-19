#!/usr/bin/env bash
# Compila o Multitarefa.app (Intel + Apple Silicon) e gera dist/Multitarefa.dmg.
# Roda no GitHub Actions; também funciona num Mac com Xcode: bash scripts/build-app.sh
set -euo pipefail
cd "$(dirname "$0")/.."

APP="Multitarefa"
ARCHS=(--arch arm64 --arch x86_64)

swift build -c release "${ARCHS[@]}"
BIN_DIR="$(swift build -c release "${ARCHS[@]}" --show-bin-path)"

DIST="dist"
BUNDLE="$DIST/$APP.app"
rm -rf "$DIST"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"

cp "$BIN_DIR/$APP" "$BUNDLE/Contents/MacOS/$APP"
cp Resources/Info.plist "$BUNDLE/Contents/Info.plist"

# Versão: VERSION (ex: 2.0) + número do build do GitHub (ex: 2.0.12)
BUILD="${BUILD_NUMBER:-0}"
VERSION="$(tr -d '[:space:]' < VERSION).$BUILD"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$BUNDLE/Contents/Info.plist"

# Logo da empresa
if [ -f Resources/logo.png ]; then
  cp Resources/logo.png "$BUNDLE/Contents/Resources/logo.png"
fi

if [ -f Resources/AppIcon.png ]; then
  ICONSET="$DIST/AppIcon.iconset"
  mkdir -p "$ICONSET"
  for s in 16 32 128 256 512; do
    d=$((s * 2))
    sips -z "$s" "$s" Resources/AppIcon.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    sips -z "$d" "$d" Resources/AppIcon.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$BUNDLE/Contents/Resources/AppIcon.icns"
  rm -rf "$ICONSET"
fi

# Assinatura local (ad-hoc), necessária para rodar em Apple Silicon.
codesign --force --deep --sign - "$BUNDLE"

# DMG: janela com o app e um atalho para Aplicativos, pra arrastar.
STAGE="$DIST/dmg"
mkdir -p "$STAGE"
cp -R "$BUNDLE" "$STAGE/"
ln -s /Applications "$STAGE/Aplicativos"
hdiutil create -volname "$APP" -srcfolder "$STAGE" -ov -format UDZO "$DIST/$APP.dmg"
rm -rf "$STAGE"
# Arquivo que o app consulta pra saber se tem versão nova
cat > "$DIST/version.json" <<JSON
{"version": "$VERSION", "build": $BUILD, "url": "https://github.com/Tamiozzo22/Multitarefa/releases/download/latest/$APP.dmg"}
JSON

echo "Pronto: $DIST/$APP.dmg (versão $VERSION)"
