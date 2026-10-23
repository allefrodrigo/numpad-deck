#!/bin/zsh
# Builds NumpadDeck.app into ./build. Needs only Command Line Tools.
set -e
cd "$(dirname "$0")/.."
CONFIG=${1:-release}
swift build -c "$CONFIG" 2>&1 | grep -Ev "^\[|Compiling|Build complete" || true
BIN=".build/$CONFIG/NumpadDeck"
[ -x "$BIN" ] || { echo "build failed"; exit 1; }
APP="build/NumpadDeck.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/NumpadDeck"
cp scripts/Info.plist "$APP/Contents/Info.plist"
[ -f assets/icon/AppIcon.icns ] && cp assets/icon/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
IDENTITY="-"
security find-identity -v -p codesigning 2>/dev/null | grep -q "NumpadDeck Dev" && IDENTITY="NumpadDeck Dev"
if ! codesign --force --sign "$IDENTITY" --identifier dev.allef.NumpadDeck "$APP" 2>&1 | grep -v "replacing existing signature"; then :; fi
codesign -dv "$APP" 2>&1 | grep -q "Signature=adhoc" && [ "$IDENTITY" != "-" ] && { echo "erro: codesign não usou o certificado '$IDENTITY'. Abra o Keychain Access e permita o acesso, ou rode: security unlock-keychain"; exit 1; }
[ "$IDENTITY" = "-" ] && echo "aviso: assinatura ad hoc; rode scripts/make-cert.sh para a permissão de Acessibilidade não se perder a cada build"
echo "→ $APP"
