# Prompt Palette

*"Copy/paste any prompt into any agent in 2 seconds."*

**Keyboard-first prompt launcher for people who live in AI tools.**

Mac only.

Quickly copy/paste your prompts across various agents, if you do not like setting up skills like me.

All keybind controlled, as my old hardcore gaming days crave it.

Feel free to fork, pork, steal. Have fun.

If you need any changes, feel free to fuck off and tell your agent to do it. If you for any reason can't do that, I will help. Much love.

## Quick Start

```bash
cd prompt-palette
swift build
swift run PromptPalette
```

This repo is source-only. If you want a clickable `.app`, ask any coding agent
to package the SwiftPM project into a macOS app bundle for you.

Prompt Palette runs as a menu bar app, so after `swift run PromptPalette` look
for the menu bar icon. From there, choose **Manage Prompts...** or press
`Cmd+F2` to add prompts.

If the global shortcut does not work, macOS may already be using it. The app
will show an alert if it cannot register the shortcut.

## How to use

1. Open Prompt Palette.
2. Use the menu bar icon and choose **Manage Prompts...**.
3. Add prompts or folders.
4. Press `Cmd+F1` to open the palette.
5. Pick a prompt. Its text is copied to your clipboard.
6. Paste it wherever you need it.

## Hotkeys

- `Cmd+F1` opens the prompt palette.
- `Cmd+F2` opens the management window.
- `1`-`5`, then `Q`, `W`, `E`, `R` pick visible palette items.
- `↑` / `↓` move selection.
- `Return` opens the selected folder or copies the selected prompt.
- `Tab` enters search.
- The key under `Esc` goes back or exits search. On my keyboard, that is `<`.
- `Esc` dismisses the palette or closes the management window.

Important: the picker keys are based on physical key positions, not typed
characters. `1`-`5` means the five number-row keys directly above the left-hand
letter keys, and `Q`, `W`, `E`, `R` means those same physical left-hand positions
on a QWERTY keyboard. This keeps the picker fast and left-handed even on
non-QWERTY layouts, but the letters shown in the app may not match every
keyboard layout.

## TODO

- Make a video demonstration?
- Make a screen demonstration?
- Add a donation option and create a $1 validation flow?
