# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Bimmies is a World of Warcraft addon targeting both **WoW Forever** (Interface 16001, modern/retail-engine client) and **Classic Anniversary** (Interface 11504). The TOC lists both (`## Interface: 16001, 11504`), and the same repo is checked out in both `_forever_` and `_anniversary_` AddOns folders. It is written in Lua using the WoW client API. There is no build system, package manager, or test framework — changes take effect by reloading the UI in-game (`/reload`).

## Development Workflow

- **Test changes:** Log in to WoW and type `/reload` in chat to reload the UI without restarting the client.
- **In-game debug commands:** `/bimmies debug`, `/bimmies hideall`, `/bimmies help`
- **View saved data:** The `BimmiesDB` global is accessible via the WoW Lua console or addons like BugSack/Ace3.

There is no linter, formatter, or CI. The WoW client itself is the runtime.

## Load Order (Critical)

The `.toc` file defines load order and it matters:

1. `Init.lua` — **must be first**: initializes `BimmiesDB` and all settings with defaults on `ADDON_LOADED`
2. `Utils.lua` through `SlashCommands.lua` — modules in any order among themselves
3. `Core.lua` — **must be last**: registers WoW events and calls `Options_CreatePanel()`, `BagHooks_Initialize()`, and `Pickpocket_Initialize()`

Do not change load order without understanding these dependencies.

## Architecture

All functions are global (WoW addon convention). Modules communicate via globals rather than `require`. The single saved variable is `BimmiesDB` (a table persisted across sessions via the `## SavedVariables: BimmiesDB` TOC directive).

### Module Responsibilities

| File | Role |
|---|---|
| `Init.lua` | Initializes `BimmiesDB` and default settings on `ADDON_LOADED` |
| `Core.lua` | Central event dispatcher; wires WoW events to module functions |
| `Utils.lua` | `GetSetting(name, default)` — safe accessor for `BimmiesDB.settings`; also the cross-client API shims (`Bimmies_GetItemInfo`, `Bimmies_GetItemIDFromLink`, `Bimmies_FormatMoney`, `Bimmies_GetLastBagID`, `Bimmies_IsSecret`, `Bimmies_IsAddOnLoaded`) |
| `ItemDeletion.lua` | `Bimmies_DeleteLowestGreyItem()` — keybind target; scans bags for lowest-value grey item and deletes it |
| `AutoSell.lua` | `SellAllGreyItems()`, `SellMarkedItems()` — called on `MERCHANT_SHOW` |
| `AutoRepair.lua` | `AutoRepairGear()` — called on `MERCHANT_SHOW`; prefers guild bank funds |
| `ItemMarking.lua` | `ToggleItemMarked()`, `GetOrCreateOverlay()`, `UpdateButtonOverlay()` — overlay creation and per-slot logic |
| `BagHooks.lua` | `BagHooks_Initialize()`, `UpdateBagItemOverlays()`, `Bimmies_ForEachBlizzardBagButton()` — hooks Blizzard bag frames (classic per-bag frames or modern combined bags) or Bagnon; detects Bagnon at runtime |
| `QuestRewards.lua` | `HighlightBestReward()` — places a gold icon on the highest sell-value quest reward choice |
| `Pickpocket.lua` | `Pickpocket_Initialize()`, `StartPickpocketTracking()`, `ProcessPickpocketLoot()`, `FinalizePickpocketTracking()` — tracks rogue pickpocket earnings via spell cast + loot events; hooks `GameTooltip` to show totals on Pick Pocket tooltip |
| `MinimapButton.lua` | `MinimapButton_Initialize()`, `MinimapButton_Refresh()` — self-contained draggable minimap button (no LibDBIcon); left-click opens settings, Shift+Right-click deletes lowest grey item; position stored as `minimapAngle` |
| `Options.lua` | `Options_CreatePanel()` — creates the ESC > Interface > AddOns settings panel; supports both Classic (`InterfaceOptions_AddCategory`) and Dragonflight+ (`Settings.RegisterCanvasLayoutCategory`) APIs |
| `SlashCommands.lua` | Registers `/bimmies` and `/bim`; default action (no args) calls `Bimmies_DeleteLowestGreyItem()` |
| `SoulShards.lua` | `SoulShards_UpdateSignal()`, `Bimmies_DeleteSoulShard()`, `SoulShards_Status()` — manages soul shard count vs threshold; shows a signal pixel for AHK communication |
| `BimmiesSoulShards.ahk` | AutoHotKey v2 companion script — polls the signal pixel and sends a keypress to trigger in-game shard deletion |
| `Bindings.xml` | Exposes `BIMMIES_DELETE` and `BIMMIES_DELETE_SOULSHARD` keybind categories |

### Event Flow

```
ADDON_LOADED  → Init.lua: initialize BimmiesDB
PLAYER_LOGIN  → Core.lua: Options_CreatePanel, BagHooks_Initialize, Pickpocket_Initialize
MERCHANT_SHOW → AutoRepairGear → SellMarkedItems → SellAllGreyItems
MERCHANT_CLOSED → UpdateBagItemOverlays (0.1s delay)
QUEST_DETAIL / QUEST_COMPLETE → HighlightBestReward (0.1s delay)
QUEST_FINISHED → QuestRewards_Clear
BAG_UPDATE_DELAYED → UpdateBagItemOverlays, SoulShards_UpdateSignal
UNIT_SPELLCAST_SUCCEEDED (player, spellID 921) → StartPickpocketTracking → FinalizePickpocketTracking (2s delay)
CHAT_MSG_LOOT / CHAT_MSG_MONEY → ProcessPickpocketLoot / ProcessPickpocketMoney
```

### Cross-Client Compatibility (Forever vs Classic)

Never branch on client version; feature-detect instead so one codebase runs on both clients:

- **Bags:** Forever uses the retail bag UI (`ContainerFrameCombinedBags`, `frame:EnumerateValidItems()`, `button:GetBagID()`). Classic uses `ContainerFrameNItemM` globals and `ContainerFrame_Update`. Ctrl+Right Click is caught via `button:HookScript("OnClick")` on each button (the classic `ContainerFrameItemButton_OnModifiedClick` global is not expected to exist on Forever).
- **Tooltips:** `OnTooltipSetSpell` is used when present; otherwise `TooltipDataProcessor.AddTooltipPostCall`.
- **Options panel:** templates are chosen with `C_XMLUtil.GetTemplateInfo` (`InterfaceOptionsCheckButtonTemplate`/`OptionsSliderTemplate` may be missing on Forever). `Settings.OpenToCategory` is given the category ID stored in `BimmiesSettingsCategory`.
- **Secret values:** Forever is a modern client with secret values; chat text and spell IDs may be secret in restricted content. Check `Bimmies_IsSecret(v)` before string ops or comparisons on event payloads.

### Bagnon Compatibility

`BagHooks_Initialize()` detects Bagnon at runtime. If found, it monkey-patches `ItemClass.PostClick` and `ItemClass.Update` instead of using `hooksecurefunc` on Blizzard frame globals. A `bagnonButtonCache` (keyed by `"bag_slot"`) avoids repeated frame searches.

### Settings Keys (`BimmiesDB.settings`)

- `enableAutoSellGrey`
- `enableAutoSellMarked`
- `enableAutoRepair`
- `enableQuestRewardHighlight`
- `enablePickpocketTracker`
- `enableMarkingOverlay`
- `enableNoPingChatTabs` (while hovering a chat tab, `BUTTON3` is override-bound to a dummy button so middle-click close doesn't fire Ping; see `NoPingOnChatTabs.lua`, not active in combat)
- `showMinimapButton` (default `true`; `/bimmies minimap` toggles) and `minimapAngle` (degrees, default `220`)
- `enableSoulShardManager` (default `false` — opt-in, requires AHK script)
- `soulShardThreshold` (default `8`)

All boolean settings default to `true` except `enableSoulShardManager`. Use `GetSetting(key, default)` from `Utils.lua` to read them safely.

### Soul Shard Manager — AHK Communication

The soul shard manager uses a **pixel signaling** pattern to bridge the WoW addon sandbox and an external AutoHotKey script:

1. The addon creates a 5x5 green pixel frame at the top-left corner of the screen (`BimmiesSoulShardSignal`)
2. When soul shards exceed the threshold, the frame is shown; otherwise hidden
3. `BimmiesSoulShards.ahk` polls that pixel position every 250ms
4. When green is detected, AHK sends the configured key (default F12)
5. That key must be bound in WoW to the `BIMMIES_DELETE_SOULSHARD` keybind
6. `Bimmies_DeleteSoulShard()` runs with hardware event context, allowing `DeleteCursorItem()`
7. `BAG_UPDATE_DELAYED` fires, `SoulShards_UpdateSignal()` re-evaluates, loop continues until at threshold
