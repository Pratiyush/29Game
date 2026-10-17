package com.game29.room;

import java.util.List;

/** The reactions players may send. Free text is not allowed, so there is nothing to moderate. */
public final class Emotes {
    private Emotes() {}

    public static final List<String> ALLOWED = List.of(
            "👍", "👏", "😂", "😮", "😎", "😡", "🙏", "🔥",
            "Well played!", "Nice bid!", "Hurry up!", "Oops!");

    public static final int AVATARS = 16;

    /** Minimum gap between two emotes from the same player. */
    public static final long COOLDOWN_MS = 1500;
}
