# Hush

<img src="logo.png" alt="Hush" width="128">

A World of Warcraft addon that puts each whisper conversation in its own clean window, like WIM, without the extras. It is styled to sit next to EllesmereUI.

- One window per person, for character whispers and Battle.net whispers.
- Whispers are taken out of the normal chat (optional).
- `/w Name`, `/r`, right-click Whisper, the friends list and clicking a name all open Hush instead of the chat box, like WIM (can be turned off).
- Your reply key (R) opens the last whisper window. Shift-clicked links go into the window you are typing in.
- `_` or Escape minimizes windows, `×` closes them. A minimized window keeps its conversation, and new whispers to it are counted on the minimap button instead of popping it up (optional).
- The minimap button (also in the addon list under the minimap) lists your open and recent conversations. Right-click it for settings.
- The last 100 lines per person are kept for 30 days.
- Font follows your EllesmereUI font by default. Any SharedMedia font works, or a file of your own.

## Light on purpose

Nothing runs per frame. Hush only does work when a whisper arrives or you type, and closed windows are hidden and reused.

## Encounters, keys and PvP

During these the game hides chat from addons and blocks them from sending. Hush then leaves whispers in the normal chat, gives R back to the normal reply, takes nothing over, and moves the whispers into their windows once chat unlocks.

Taking a whisper over from the chat box (`/w Name`, Whisper buttons) means closing Blizzard's chat box from addon code, which marks it as touched by an addon. WIM does the same. In a later key or boss fight the game may then block messages typed in the normal chat box until you `/reload`. If the game blocks something because of Hush, Hush says so in chat. `/hush check` shows whether the chat box has been touched this session. The R key does not touch the chat box, so with the takeover turned off Hush never does.

## Commands

| Command | What it does |
| --- | --- |
| `/hush` | Settings |
| `/hush Name` | Opens a window to whisper someone |
| `/hush font <name or path>` | A SharedMedia font name, or a file such as `Interface\AddOns\MyFonts\MyFont.ttf` |
| `/hush reset` | Resets where new windows open and their size |
| `/hush check` | Whether Hush has touched Blizzard's chat box this session |

Drag a window by its name, resize it from the bottom right corner. New windows open where you last moved one. Drag the minimap button to move it round the minimap; with EllesmereUI's minimap it sits in the button flyout with the others.

The artwork is in `art/` as SVG; `logo.png` and `media/*.png` are rendered from it with `rsvg-convert`.

## Install

Put the folder in `World of Warcraft/_retail_/Interface/AddOns/Hush`. Retail only.
