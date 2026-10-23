# NumpadDeck

Transforma um numpad USB com adesivos coloridos em um stream deck para macOS.

## Rodar

```sh
./scripts/build.sh          # gera build/NumpadDeck.app (release)
open build/NumpadDeck.app
```

Só precisa das Command Line Tools (`swift build`), não do Xcode.

## Instalar e abrir no login

```sh
./scripts/build.sh
./scripts/install.sh       # copia para /Applications e registra um LaunchAgent
```

O `install.sh` cria `~/Library/LaunchAgents/dev.allef.NumpadDeck.plist`, que abre o app no login (mesmo esquema do SolBar). Rode de novo após cada rebuild. Para desativar: `launchctl bootout gui/$(id -u)/dev.allef.NumpadDeck` e apague o plist.

Na primeira vez, o app pede permissão em **Ajustes › Privacidade e Segurança › Acessibilidade**. Sem ela a interface funciona, mas as teclas não disparam.

## Uso

- O app vive na barra de menus. `⌘,` abre a janela de configuração.
- Clique numa tecla no numpad desenhado, ou pressione a tecla física, para editá-la.
- Cada tecla tem nome, cor do adesivo e uma ação: abrir app, abrir link, atalho, script zsh, texto ou ferramenta.
- **Ferramentas** embutidas rodam só no momento do toque, sem nada residente. Hoje: **Conta-gotas de cor**, que abre a lupa nativa do macOS e copia a cor em HEX, RGB, HSL ou `Color(...)` do SwiftUI; **Minimizar janela**, **Tela cheia** e **Fechar programa** para o app em primeiro plano, **Bloquear tela** e **Mission Control**; **Conectar por SSH** e **Mudo**.
- **Perfis** trocam sozinhos conforme o app em primeiro plano. O perfil sem apps é o padrão.
- **Modo teste** acende as teclas na tela sem executar nada.
- **Aprender tecla** reatribui a tecla física de uma posição. Serve para numpads com layout diferente e para testar com um teclado comum antes do numpad chegar.
- Com a janela do NumpadDeck em primeiro plano, as teclas só selecionam. A ação dispara quando outro app está na frente.

Configuração salva em `~/Library/Application Support/NumpadDeck/config.json`.

## Screenshots para revisão de design

```sh
build/NumpadDeck.app/Contents/MacOS/NumpadDeck --snapshot /tmp/shots --demo --select k4
```

## Permissão some a cada rebuild?

A assinatura ad hoc muda a cada build e o macOS esquece a permissão. Crie um certificado local uma vez:

```sh
./scripts/make-cert.sh
./scripts/build.sh
```

Se a entrada no painel de Acessibilidade ficar "ligada" mas sem efeito, remova-a com `tccutil reset Accessibility dev.allef.NumpadDeck` e ligue de novo.
