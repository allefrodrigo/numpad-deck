# NumpadDeck — design

## Mode
Operate. The window is a settings surface opened for seconds; brand lives in the keycaps, never in the chrome.

## World
The physical object on the desk, mirrored. A dark keypad plate (gradient #2b2b2b → #1c1c1c, 22pt continuous corners, soft offset shadow) holds keycaps with a two-layer build: dark cap body, then the sticker inset 5pt with a top highlight. Sticker colors are the exact sticker set: yellow, blue, green, salmon, pink, brown, gray, black. Everything outside the plate is native macOS: unified toolbar, grouped Form inspector, semantic system colors, SF Symbols.

## Tokens
- Deck pane ground: light 93% / dark 13% white. Inspector: `windowBackgroundColor`.
- Sticker foreground: near-black (#141414) on yellow, green, salmon; white on the rest. Keeps ≥4.5:1.
- Selection: `accentColor` 2.5pt ring. Learning: dashed accent ring. Hover: 35% white ring.
- Type: system rounded for keycap glyphs (11 semibold) and names (12 bold, 2 lines, min scale 0.8). Everything else system text styles.
- Radii: keycap 11 / sticker 9 / banners 10.

## Motion
One authored moment: a physical keypress. The keycap scales to 0.94, brightens 12%, shadow collapses, spring 180ms / 0.6 damping. Everything else is 120–200ms ease-out state change.

## Status vocabulary
Toolbar pill states: orange shield = no Accessibility permission; gray pause = deck off; purple flask = test mode; green radio = live, showing the profile and frontmost app. The last fired action trails the pill.

## Copy
pt-BR, second person, controls name their action ("Aprender tecla", "Executar agora"). Errors name the problem and the recovery.
