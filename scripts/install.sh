#!/bin/zsh
# Instala build/NumpadDeck.app em /Applications e registra um LaunchAgent
# para abrir o app no login (mesmo padrão do SolBar). Rode após ./scripts/build.sh.
set -e
cd "$(dirname "$0")/.."
APP_SRC="build/NumpadDeck.app"
APP_DST="/Applications/NumpadDeck.app"
LABEL="dev.allef.NumpadDeck"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

[ -d "$APP_SRC" ] || { echo "erro: $APP_SRC não existe; rode ./scripts/build.sh primeiro"; exit 1; }

# Encerra a instância em execução para poder substituir o bundle.
pkill -x NumpadDeck 2>/dev/null || true
sleep 0.5

rm -rf "$APP_DST"
cp -R "$APP_SRC" "$APP_DST"
echo "→ $APP_DST"

mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/open</string>
        <string>$APP_DST</string>
    </array>
    <key>RunAtLoad</key><true/>
</dict>
</plist>
PLIST
echo "→ $PLIST"

# Recarrega o agente; RunAtLoad abre o app agora e a cada login.
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "NumpadDeck instalado e configurado para abrir no login."
