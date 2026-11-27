# FFR_SharedProgress

Shared levels and vision synchro mastery for **FINAL FANTASY RESONANCE**, as a [MogHub](https://github.com/jesus-seijas-sp/ffr-moghub) plugin.

No character falls behind. Every character who has joined catches up to the level of the furthest one, and every vision's synchro mastery catches up to the best one.

## Features

| Setting | What it does | Default |
|---|---|---|
| **Share EXP** | Every character who has joined (including those who have left for now or for good) gets the level of the furthest one, plus the same share of the bar to the next level. Characters who have not joined yet are left alone. | On |
| **Share vision synchro** | Every vision you own, with every character, gets the highest synchro mastery points of any vision/character pair, capped at each vision's maximum. | On |

- Values only ever go up. Nothing is lowered.
- Changes happen **after each battle** (once you are back on the map) and **after a save is loaded**, never during a battle, an encounter or a loading screen.
- The new values go into your save the next time the game saves, so they stay even if you remove the mod.
- Awakening (item upgrades 0–3) is not touched.

You change the settings in the game (main menu → **Mods** → **Shared Progress**), and they work with a controller. They are saved in `config.ini` next to the plugin.

Menu and messages are translated into English, German, French, Spanish, Japanese, Korean and Chinese (Simplified and Traditional).

## Requirements

- [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) (tested with 4.0.0 experimental)
- [MogHub](https://github.com/jesus-seijas-sp/ffr-moghub) (tested with 1.0.1)

## Installation

1. Install UE4SS and MogHub as their own instructions describe.
2. Download `FFR_SharedProgress-<version>.zip` from the [latest release](https://github.com/sbstnmrwld/FFR_SharedProgress/releases/latest) and extract it into
   `FINAL FANTASY RESONANCE\FFRS\Binaries\Win64\ue4ss\Mods\`
3. Start the game. The plugin appears under **Mods** in the main menu.

> **Note:** this mod changes your save permanently. Back up your save first if you might want the old values back.

## How it works

The plugin uses the game's own blueprint libraries:

- **Roster:** `CPP_BFL_SaveDataUnit.GetSaveDataUnitParameterListFromJoinStatus` for join statuses Join, Leave and TemporalLeave.
- **Levels:** the game has two EXP curves, both ending at level 99. The plugin therefore carries over the level and bar share (`CPP_BFL_Unit.GetLevelReachWithExp` / `GetExpForReachLevel`) instead of raw EXP. It writes them with `SetPlayableUnitExperience`, which also updates max HP and MP.
- **Synchro:** `CPP_BFL_Vision.HasVision` and `Get/SetSynchroMasteryPoint(vision, unit)`. The game works out the mastery rank from the points itself. Visions with a steeper curve can show a lower rank for the same points.
- The title screen has its own save object, so the plugin only runs once a real map (not Title/Boot) is loaded.

## AI disclosure

This mod was made by sbstnmrwld with the help of AI: [Claude Code](https://claude.com/claude-code) by Anthropic.

- **AI-generated:** the Lua code, the menu translations in `lang/` and this README, written by Claude based on sbstnmrwld's design and requests.
- **Done by a human:** the feature design, decisions and testing in the game, all by sbstnmrwld.
- **Not included:** AI-generated images, audio, voices or models. The mod only uses the game's own data and visuals.

Commits made with AI help name Claude as co-author.

## License

[MIT](LICENSE): you may use, change and share this mod, also in your own mods, as long as the copyright notice is kept. Final Fantasy Resonance and all game data belong to their owners and are not covered by this license.
