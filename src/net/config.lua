local GameConfig = require("src.config.game")

local CONFIG = {
    version = 2,
    address = "*",
    port = 6789,
    localAddress = "127.0.0.1",
    localPorts = { 6790, 6809 },
    lanPorts = { 6789, 6799 },
    discoveryPort = 6788,
    discoveryInterval = 1,
    discoveryExpire = 4,
    maxPeers = 64,
    channels = 1,
    tickRate = GameConfig.tickRate,
    timeout = 5000,
    maxRoomPlayers = 8,
    hashTicks = 10,
    frameHistory = 256,
    snapshotTicks = 200,
    catchUpTicks = 100,
    maxIntentsPerTick = 32,
    emptyRoomSeconds = 120,
    soloEmptySeconds = 5,
    maxFramesPerTick = 8
}

return CONFIG
