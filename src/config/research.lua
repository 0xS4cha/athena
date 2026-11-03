local Research = {}

Research.tiers = {
    { baseCost = 100000, incomeSeconds = 30, seconds = 60 },
    { baseCost = 250000, incomeSeconds = 45, seconds = 90 },
    { baseCost = 500000, incomeSeconds = 60, seconds = 120 },
    { baseCost = 1000000, incomeSeconds = 90, seconds = 180 }
}

Research.maxQueue = 5
Research.fundingShare = 0.5
Research.friendDiscount = 0.2
Research.commonDiscount = 0.15
Research.commonShare = 0.5
Research.stolenProgress = 0.5
Research.aiStartTicks = 2400
Research.aiGoldShare = 0.4

Research.branches = {
    { id = "economy", label = "ECONOMY", icon = "Coin.png", color = { 1, 0.82, 0.25, 1 } },
    { id = "military", label = "MILITARY", icon = "Skull.png", color = { 0.95, 0.35, 0.3, 1 } },
    { id = "navy", label = "NAVY", icon = "Wrench3.png", color = { 0.45, 0.75, 1, 1 } },
    { id = "strategic", label = "STRATEGIC", icon = "PotionRed.png", color = { 0.45, 0.85, 0.3, 1 } }
}

Research.effects = {
    income = { label = "Worker income", kind = "percent" },
    adminRange = { label = "Administration range", kind = "tiles" },
    housing = { label = "Housing capacity", kind = "percent" },
    tradeGold = { label = "Trade and train gold", kind = "percent" },
    buildCost = { label = "Building cost", kind = "percent", lowerIsBetter = true },
    mineIncome = { label = "Mine income", kind = "percent" },
    upkeep = { label = "Barracks and radar upkeep", kind = "percent", lowerIsBetter = true },
    conquest = { label = "Conquest cost", kind = "percent", lowerIsBetter = true },
    attackSpeed = { label = "Attack speed", kind = "percent" },
    supply = { label = "Supply penalty", kind = "percent", lowerIsBetter = true },
    defense = { label = "Defense", kind = "percent" },
    retreat = { label = "Troops saved on retreat", kind = "percent" },
    navalCost = { label = "Warship and submarine cost", kind = "percent", lowerIsBetter = true },
    navalHealth = { label = "Warship and submarine health", kind = "percent" },
    navalDamage = { label = "Warship and submarine damage", kind = "percent" },
    boats = { label = "Transport boats", kind = "count" },
    boatSpeed = { label = "Transport boat speed", kind = "percent" },
    sonarEvasion = { label = "Sonar range against your submarines", kind = "percent", lowerIsBetter = true },
    radarRange = { label = "Radar range", kind = "percent" },
    siloReload = { label = "Silo reload time", kind = "percent", lowerIsBetter = true },
    samRange = { label = "SAM range", kind = "percent" },
    samReload = { label = "SAM reload time", kind = "percent", lowerIsBetter = true },
    samCost = { label = "SAM cost", kind = "percent", lowerIsBetter = true },
    nukeCost = { label = "Nuke cost", kind = "percent", lowerIsBetter = true },
    nukeSpeed = { label = "Nuke speed", kind = "percent" },
    bunkerShelter = { label = "Bunker shelter", kind = "percent" },
    fallout = { label = "Conquest cost on fallout", kind = "percent", lowerIsBetter = true }
}

Research.list = {
    {
        id = "taxation", branch = "economy", tier = 1, column = 1.5, label = "Taxation", icon = "Coin.png", trait = "greed",
        text = "A census and a tax office in every town.",
        effects = { income = 0.05 }
    },
    {
        id = "urbanPlanning", branch = "economy", tier = 2, column = 1, label = "Urban Planning", icon = "Home.png", trait = "greed", requires = { "taxation" },
        text = "Wide empires stay governable and tiny ones less crowded.",
        effects = { adminRange = 15, housing = 0.1 }
    },
    {
        id = "tradeGuilds", branch = "economy", tier = 2, column = 2, label = "Trade Guilds", icon = "Cash.png", trait = "greed", requires = { "taxation" },
        text = "Merchants organize the sea lanes and the railways.",
        effects = { tradeGold = 0.15 }
    },
    {
        id = "freeMarket", branch = "economy", tier = 3, column = 1, label = "Free Market", icon = "Cash2.png", trait = "greed", group = "economicDoctrine", requiresAny = { "urbanPlanning", "tradeGuilds" },
        text = "Doctrine. More money flows, but construction gets expensive.",
        effects = { income = 0.06, tradeGold = 0.05, buildCost = 0.08 }
    },
    {
        id = "publicWorks", branch = "economy", tier = 3, column = 2, label = "Public Works", icon = "Hammer.png", trait = "caution", group = "economicDoctrine", requiresAny = { "urbanPlanning", "tradeGuilds" },
        text = "Doctrine. The state builds cheaply, paid by a little of your income.",
        effects = { buildCost = -0.12, income = -0.03 }
    },
    {
        id = "industry", branch = "economy", tier = 4, column = 1.5, label = "Industry", icon = "Wrench.png", trait = "greed", requiresAny = { "freeMarket", "publicWorks" },
        text = "Machines in the mines and cheaper garrisons.",
        effects = { mineIncome = 0.25, upkeep = -0.25 }
    },
    {
        id = "drill", branch = "military", tier = 1, column = 1.5, label = "Drill", icon = "Backpack.png", trait = "aggression",
        text = "Trained soldiers waste fewer lives in the assault.",
        effects = { conquest = -0.04 }
    },
    {
        id = "forcedMarch", branch = "military", tier = 2, column = 1, label = "Forced March", icon = "Luggage.png", trait = "aggression", requires = { "drill" },
        text = "Fronts move faster and supply lines stretch further.",
        effects = { attackSpeed = 0.1, supply = -0.15 }
    },
    {
        id = "fortifications", branch = "military", tier = 2, column = 2, label = "Fortifications", icon = "Locked.png", trait = "caution", requires = { "drill" },
        text = "Trenches along every border.",
        effects = { defense = 0.06 }
    },
    {
        id = "blitzkrieg", branch = "military", tier = 3, column = 1, label = "Blitzkrieg", icon = "Power.png", trait = "aggression", group = "militaryDoctrine", requiresAny = { "forcedMarch", "fortifications" },
        text = "Doctrine. Everything goes into the attack, nothing into the rear.",
        effects = { attackSpeed = 0.1, conquest = -0.04, defense = -0.06 }
    },
    {
        id = "totalDefense", branch = "military", tier = 3, column = 2, label = "Total Defense", icon = "Medicine.png", trait = "caution", group = "militaryDoctrine", requiresAny = { "forcedMarch", "fortifications" },
        text = "Doctrine. Your land becomes a fortress that struggles to strike back.",
        effects = { defense = 0.08, conquest = 0.04 }
    },
    {
        id = "veterans", branch = "military", tier = 4, column = 1.5, label = "Veterans", icon = "Trophy.png", trait = "aggression", requiresAny = { "blitzkrieg", "totalDefense" },
        text = "Seasoned officers save their men when a battle turns.",
        effects = { conquest = -0.03, retreat = 0.1 }
    },
    {
        id = "shipyards", branch = "navy", tier = 1, column = 1.5, label = "Shipyards", icon = "Wrench3.png", trait = "naval",
        text = "Standard parts for every hull.",
        effects = { navalCost = -0.1 }
    },
    {
        id = "ironclads", branch = "navy", tier = 2, column = 1, label = "Ironclads", icon = "Battery.png", trait = "naval", requires = { "shipyards" },
        text = "Armored hulls survive longer.",
        effects = { navalHealth = 0.2 }
    },
    {
        id = "gunnery", branch = "navy", tier = 2, column = 2, label = "Gunnery", icon = "MagnifyingGlass.png", trait = "naval", requires = { "shipyards" },
        text = "Better guns and torpedoes.",
        effects = { navalDamage = 0.15 }
    },
    {
        id = "seaPower", branch = "navy", tier = 3, column = 1, label = "Sea Power", icon = "CatchingNet.png", trait = "aggression", group = "navalDoctrine", requiresAny = { "ironclads", "gunnery" },
        text = "Doctrine. More invasions overseas, on top of a costlier fleet.",
        effects = { boats = 2, boatSpeed = 0.15, navalCost = 0.08 }
    },
    {
        id = "wolfpack", branch = "navy", tier = 3, column = 2, label = "Wolfpack", icon = "Download.png", trait = "opportunism", group = "navalDoctrine", requiresAny = { "ironclads", "gunnery" },
        text = "Doctrine. Silent hulls slip past sonar, but carry less armor.",
        effects = { sonarEvasion = -0.35, navalHealth = -0.1 }
    },
    {
        id = "merchantMarine", branch = "navy", tier = 4, column = 1.5, label = "Merchant Marine", icon = "Basket.png", trait = "greed", requiresAny = { "seaPower", "wolfpack" },
        text = "Escorted convoys bring more home.",
        effects = { tradeGold = 0.1 }
    },
    {
        id = "earlyWarning", branch = "strategic", tier = 1, column = 1.5, label = "Early Warning", icon = "Monitor.png", trait = "caution",
        text = "Stronger radars see further.",
        effects = { radarRange = 0.15 }
    },
    {
        id = "rapidReload", branch = "strategic", tier = 2, column = 1, label = "Rapid Reload", icon = "Plug.png", trait = "nuclear", needsNukes = true, requires = { "earlyWarning" },
        text = "Silos are ready to fire again sooner.",
        effects = { siloReload = -0.25 }
    },
    {
        id = "interceptors", branch = "strategic", tier = 2, column = 2, label = "Interceptors", icon = "Eye.png", trait = "caution", needsNukes = true, requires = { "earlyWarning" },
        text = "SAM launchers reach further and reload faster.",
        effects = { samRange = 0.15, samReload = -0.15 }
    },
    {
        id = "firstStrike", branch = "strategic", tier = 3, column = 1, label = "First Strike", icon = "Skull.png", trait = "nuclear", needsNukes = true, group = "nuclearDoctrine", requiresAny = { "rapidReload", "interceptors" },
        text = "Doctrine. Cheap and fast warheads, while your shield costs more.",
        effects = { nukeCost = -0.15, nukeSpeed = 0.15, samCost = 0.2 }
    },
    {
        id = "civilDefense", branch = "strategic", tier = 3, column = 2, label = "Civil Defense", icon = "Briefcase.png", trait = "caution", needsNukes = true, group = "nuclearDoctrine", requiresAny = { "rapidReload", "interceptors" },
        text = "Doctrine. A protected population and a costlier arsenal.",
        effects = { bunkerShelter = 0.1, samCost = -0.2, nukeCost = 0.1 }
    },
    {
        id = "decontamination", branch = "strategic", tier = 4, column = 1.5, label = "Decontamination", icon = "Bottle.png", trait = "caution", needsNukes = true, requiresAny = { "firstStrike", "civilDefense" },
        text = "Engineers clear a path through the fallout.",
        effects = { fallout = -0.25 }
    }
}

Research.byId = {}
for _, tech in ipairs(Research.list) do
    Research.byId[tech.id] = tech
end

return Research
