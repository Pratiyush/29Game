package com.game29.room;

import io.smallrye.config.ConfigMapping;
import io.smallrye.config.WithDefault;

@ConfigMapping(prefix = "game29")
public interface GameConfig {

    /** Pause before a bot (or a disconnected player's stand-in) moves, so humans can follow. */
    @WithDefault("700")
    long botDelayMs();

    /** Pause on the round summary before the next deal. */
    @WithDefault("3000")
    long roundPauseMs();

    /** How long quick match waits for other humans before filling the table with bots. */
    @WithDefault("5000")
    long quickMatchWaitMs();

    /** Rooms with no connected human are removed after this long. */
    @WithDefault("600000")
    long idleRoomTtlMs();
}
