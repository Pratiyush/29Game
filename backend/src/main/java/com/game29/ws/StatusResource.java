package com.game29.ws;

import com.game29.room.RoomService;
import jakarta.inject.Inject;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;

import java.util.Map;

@Path("/api/status")
public class StatusResource {

    @Inject
    RoomService rooms;

    @GET
    public Map<String, Object> status() {
        return Map.of("service", "game29", "rooms", rooms.roomCount(), "protocol", 1);
    }
}
