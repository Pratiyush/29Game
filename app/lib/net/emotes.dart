/// Quick reactions and avatar count, shared with the backend (backend/.../room/Emotes.java).
/// Free text is deliberately not allowed, so there is nothing to moderate.
library;

const allowedEmotes = [
  '👍',
  '👏',
  '😂',
  '😮',
  '😎',
  '😡',
  '🙏',
  '🔥',
  'Well played!',
  'Nice bid!',
  'Hurry up!',
  'Oops!',
];

/// Number of bundled portraits: assets/avatars/a00.png .. a15.png.
const avatarCount = 16;

/// Minimum gap between two emotes from the same player.
const emoteCooldown = Duration(milliseconds: 1500);
