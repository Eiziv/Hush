# Hush

## v1.0.0

First release.

- One clean window per whisper conversation, for characters and Battle.net, in chat bubbles: theirs on the left, yours on the right.
- Whispers leave the normal chat. `/w Name`, `/r`, Whisper buttons and clicked names open Hush instead (optional).
- R opens the last whisper window. During encounters, keys and PvP matches Hush steps aside and moves whispers into their windows afterwards.
- Ten soft message sounds made for Hush, or the game's whisper sound, any SharedMedia sound, or none.
- Minimize with `_` or Escape; a minimap button and the addon compartment list your conversations and count unread lines.
- Your EllesmereUI font and accent colour by default, any SharedMedia font, or a font file of your own.
- Nothing runs per frame.
- A small public API for other addons: `Hush.GetUnreadCount`, `Hush.RegisterCallback` and more.
