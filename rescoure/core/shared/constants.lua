-- FiveCore Constants & Enums

GENDER_MALE   = 0
GENDER_FEMALE = 1

CHARACTER_STATES = {
    IDLE      = "idle",
    SELECTING = "selecting",
    CREATING  = "creating",
    SPAWNING  = "spawning",
    LOADED    = "loaded",
}

MONEY_TYPES = {
    CASH = "cash",
    BANK = "bank",
}

EVENTS = {
    -- ─── Server → Client ───────────────────────────────
    PLAYER_LOADED     = "fivecore:playerDataLoaded",
    MONEY_UPDATED     = "fivecore:moneyUpdated",
    STATUS_UPDATED    = "fivecore:statusUpdated",
    CHAR_DELETED      = "fivecore:characterDeleted",
    NOTIFY            = "fivecore:notify",
    LOADING_STEP      = "loading:updateStep",

    -- ─── Client → Server ───────────────────────────────
    REQ_CHAR_LIST     = "fivecore:requestCharacterList",
    CREATE_CHAR       = "fivecore:createCharacter",
    SELECT_CHAR       = "fivecore:selectCharacter",
    DELETE_CHAR       = "fivecore:deleteCharacter",
    REQ_SPAWN         = "fivecore:requestSpawn",
    SYNC_STATUS       = "fivecore:syncStatus",
    SAVE_POSITION     = "fivecore:savePosition",
}

NOTIFY_TYPES = {
    SUCCESS = "success",
    ERROR   = "error",
    INFO    = "info",
    WARNING = "warning",
}

LOADING_STEPS = {
    CONNECTING    = { step = 1, text = "Verbinde mit Server..."   },
    ACCOUNT       = { step = 2, text = "Lade Account..."          },
    CHAR_LIST     = { step = 3, text = "Lade Charakterliste..."   },
    CHAR_SELECTED = { step = 4, text = "Charakter ausgewählt..."  },
    WORLD         = { step = 5, text = "Lade Spielwelt..."        },
    DONE          = { step = 6, text = "Willkommen auf FiveCore!" },
}
