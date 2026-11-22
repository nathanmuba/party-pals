# Party Pals

A 4-player couch party game made in **Godot 4.4**. Free-for-all, 2 vs 2, 1 vs 3 and co-op mini-games, played with keyboards and/or controllers. Empty player slots are filled by CPU pals.

All 50 mini-games from the browser prototype are included. This project is the version that will ship on **Steam** (and later, Nintendo Switch).

## Open and run it

1. Install **Godot 4.4.1** (standard version, not .NET) from <https://godotengine.org/download>.
2. Open Godot → **Import** → choose this folder's `project.godot`.
3. Press **F5** (or the ▶ button) to play.

## Controls

| Player | Move | Action |
|---|---|---|
| P1 | W A S D | Q |
| P2 | I J K L | U |
| P3 | Arrow keys | Enter |
| P4 | Numpad 8 4 5 6 | Numpad 0 |
| Controllers | Left stick / D-pad | A, B, X or Y |

On the title screen each player presses their **action** button to join. Space / Start begins a party, **F** (or L/R shoulder) opens Free Play, **R** (or Back/−) changes the number of rounds, **F11** toggles fullscreen, **Esc** quits.

Mini-games that ask for a *specific* button (like Quick Draw) use the four face buttons by position. On a keyboard, the matching direction key counts: ↓ = bottom, → = right, ← = left, ↑ = top.

## Project layout

```
project.godot          engine settings (1280×720, scales to any window)
main.tscn              the only scene
scripts/game.gd        autoload "G": players, input for 4 keyboards + controllers, beeps, particles
scripts/art.gd         all drawing helpers + the Pal character (everything is drawn in code)
scripts/main.gd        party flow: title, free play, round intro, results, bonus awards, podium
scripts/minigame.gd    base class every mini-game extends
scripts/games.gd       list of mini-games (add new ones here)
scripts/games/*.gd     one file per mini-game
fonts/                 Baloo 2 (SIL Open Font License, see OFL.txt)
```

## Adding a mini-game

1. Copy a similar game in `scripts/games/` (e.g. `hot_potato.gd` for an arena game, `obstacle_dash.gd` for a race) to a new file.
2. Set `NAME`, `MODES`, `HOW` and `desc()`. Then write `update()`, `bot()` (what CPU pals do) and `draw()`.
3. When the game ends, set `done = true` and `result` (see the comment at the top of `minigame.gd`).
4. Add it to `scripts/games.gd`.

## Testing without playing

Every game/mode can be played by CPU pals at high speed to catch crashes and balance problems:

```
godot --headless --path . -- --autotest
godot --headless --path . -- --autotest=10,20   # only games 10–19
```

Screenshot a game (index, mode index, seconds, file):

```
godot --path . -- --shot=0,0,8,/tmp/shot.png
```

## Building

**Project → Export** in the editor (presets for Windows, Linux and macOS are included), or from a terminal:

```
godot --headless --path . --export-release "Windows Desktop" build/windows/PartyPals.exe
godot --headless --path . --export-release "Linux" build/linux/PartyPals.x86_64
godot --headless --path . --export-release "macOS" build/macos/PartyPals.zip
```

You need Godot's export templates (Editor → Manage Export Templates → Download).

## Roadmap

- [x] Core: 4-player input, Pal art, party flow, free play, bonus awards
- [x] All 50 mini-games ported (37 free-for-all, 21 2 vs 2, 9 1 vs 3, 11 co-op)
- [ ] Friends playtest → fix list
- [ ] Settings menu (volume, controls, rounds), pause menu, sound effects + music
- [ ] Steam: GodotSteam integration, achievements, Steam Input, store page art, trailer
- [ ] Switch: apply to the Nintendo Developer Portal once the PC version is out
