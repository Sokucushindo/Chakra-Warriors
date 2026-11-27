# Chakra Warriors

An open-world ninja action RPG made with Godot 4.7, set in the Naruto universe. Five great villages, clans, chakra natures, tailed beasts, rank exams (Academy → Genin → Chūnin → Jōnin → ANBU → Kage), missions, the Bingo Book, friendships, marriage and family, and training your own genin team.

> **Fan game.** Chakra Warriors is a free, non-commercial fan project. It is not affiliated with or endorsed by the official Naruto franchise. No canon characters appear in the game; you create your own ninja.

## Features

- **Create your own ninja**: clan, home village, chakra nature, looks and outfit
- **1300+ jutsu**: ninjutsu, genjutsu, taijutsu and kekkei genkai, learned by practice
- **Dōjutsu**: Sharingan, Mangekyō Sharingan, Byakugan, Rinnegan and more
- **Hand seals**: weave real seal sequences to cast techniques
- **Susanoo, Sage Mode, the Eight Gates, tailed beast modes**
- **Huge open world**: the five great villages and the lands between them
- **RPG systems**: missions from D to S rank, Bingo Book bounties, outfits and gear, rank progression
- **Life sim**: friends, rivals, marriage, children, aging and passing on your legacy
- **Story cutscenes**

## How to play

**With the launcher (recommended):** download `ChakraWarriorsLauncher.exe` from the latest release on the **Releases** page,
put it in an empty folder (for example `C:\Games\Chakra Warriors`) and run it. It downloads the game, installs it next to
itself and updates it automatically every time you open it. Press **Play** to start. Your saves are kept in a separate
folder and are never touched by updates.

**Manually:** download the latest `ChakraWarriors_vX.Y.Z.zip`, unzip it and run `ChakraWarriorsLauncher.exe` (or
`ChakraWarriors.exe`) inside the `ChakraWarriors` folder (Windows, no install needed).

The game starts in English; you can switch the language in the settings.

### Controls

| Key | Action |
|---|---|
| W A S D | Move |
| Space / Ctrl / Shift | Jump / long leap / dash |
| Left click / Right click | Attack / block |
| 1–6 | Jutsu slots |
| G | Hand seal mode |
| Q | Kawarimi (substitution) |
| C | Charge chakra |
| R / T | Throw / switch throwing tool |
| E or middle click | Lock on target |
| F | Interact / talk |
| H / Y / O | Salve / pill / switch pill |
| V / Z / X / B | Eye / Sage / Beast / Gates modes |
| N | Draw weapon |
| J / U | Summon command / summon special |
| L | Switch map marker (mission, friend, wanted, target) |
| Tab / I / K / M | Ninja menu / inventory / jutsu / map |
| Esc | Pause |

## Building from source

1. Download Godot 4.7.2 and place it in the `tools/` folder.
2. Run `python build.py main`. The exe is written to the `Oyun/` folder.

The launcher (`launcher/Launcher.cs`) is built with `python tools/build_launcher.py` (it uses the .NET Framework compiler that ships with Windows).

The Godot project lives in `godot/`. Tests are in `godot/tests/` and run with `--test=res://tests/<name>.gd`.
