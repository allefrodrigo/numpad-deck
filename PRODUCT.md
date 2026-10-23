# NumpadDeck

## What it is
A macOS menu-bar utility that turns a cheap USB numpad into a stream deck. Each physical key carries a colored sticker; the app mirrors that grid on screen so the user maps a key to an action by looking at the color they see on the desk.

## Platform
macos (SwiftUI, Swift Package, no Xcode required)

## Users
One person: a developer/creator who wants one-press actions (open app, run script, send shortcut, paste snippet) without memorizing combos. They use Portuguese (pt-BR).

## Jobs
- Map a key to an action in under 30 seconds.
- Know instantly whether the deck is live (accessibility permission, engine on/off, active profile).
- Different layouts per foreground app, switching automatically.
- Test a mapping without the physical numpad (learn a key from any keyboard).

## Constraints
- Global key capture needs Accessibility permission; the app must explain and link to the setting.
- Bound keys are swallowed system-wide; unbound keys pass through untouched.
- Config lives in ~/Library/Application Support/NumpadDeck/config.json.
