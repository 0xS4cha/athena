# Gameplay guide

[Back to the README](../README.md)

## Gameplay

New to the game? Press **Tutorial** in the main menu: it starts a solo game on Iceland against a few easy tribes, with a longer spawn phase and enough gold for a first city and a military port. A panel walks you through 18 steps in four chapters (basics, economy, war and the wider world). Steps that ask for an action complete on their own as soon as you do it and can be skipped; the others wait for **Next** or `Enter`, and **Back** returns to an earlier step. A gold arrow points at the place to click and a gold frame surrounds the panel being explained. The main menu remembers once you have finished it.

- **Spawn phase**: click anywhere on land to choose your starting location, then press `Space` or wait for the countdown.
- **Population**: your maximum population grows with your territory and your cities. Growth is fastest when you are far from the cap.
- **Administration**: land far from your capital and your cities is poorly administered. Within 55 tiles of them it earns full gold, then its income falls with the distance down to 35%. The gold panel shows the share of income lost (`GOLD - 23% LOST`) and hovering your land shows its administration, so wide empires need cities spread across their territory. AI nations build their next city in their least administered region.
- **Housing**: the population brought by cities and farms is limited by your housing capacity (400K plus 250 per tile), so a tiny island packed with cities stops growing. The population panel shows `POP - CROWDED` when you hit it, and the build menu warns that a new city or farm would bring no housing.
- **Troops / Workers**: the slider splits your population. Troops attack and defend; workers produce gold.
- **Attacks**: left-click a neighbour (or the wilderness) to send `Attack Ratio` percent of your troops. The front advances tile by tile. Each tile costs troops depending on terrain (plains < highland < mountain), fallout, the defender's troop density, defense posts, and whether the defender is a traitor. Attacks can be retreated from the Empire panel, and opposite attacks cancel each other out.
- **Biomes**: land is plains, desert, mountain or snow, derived from elevation and latitude. Each biome has a base conquest cost, plus an adaptation penalty that fades as that biome makes up a larger share of your land (full adaptation at 20%). A desert empire struggles to push into snow until it owns some. Your adaptation appears in the Empire panel, and hovering a tile shows your cost multiplier.
- **Boats**: transport ships leave from your **military ports** (2 boats per port, 6 at most). Left-click a coast you do not border to invade it. Without a military port you cannot leave your continent.
- **Capital**: your spawn becomes your capital (+population, defense bonus around it). If it falls, you lose 15% of your troops and your growth and income are halved for 60 s, then a new capital is founded.
- **Supply lines**: attacks get more expensive the farther they are from your capital, cities, military ports and finished rail tracks (up to x3). Toggle the Supply layer with `5` to see your supply range. Hovering a tile shows the multiplier.
- **Naval blockade**: an enemy warship within 18 tiles of a port blockades it. A blockaded trade port stops trading, a blockaded military port cannot launch invasions or build warships. Right-click > Send Warship Here dispatches your nearest warship to a place.
- **Threat map**: press `6` to colour your borders by how dangerous each neighbour is, from green to blinking red. The score weighs their troops (estimated if you cannot observe them) against yours, how much they dislike you, whether they are attacking you, have marked you as a target or are traitors, and whether a pact protects you. Arrows show where the strongest threats would come from.
- **Diplomatic map**: press `7` to recolour every nation by its relation to you: ally, at war, pact, traitor, hostile, friendly, neutral or tribe. It is drawn with a palette shader, so switching it on stays smooth even on the largest maps.
- **Hidden intel**: structures are drawn as small pixel buildings on the map, readable only when zoomed in. Enemy structures, ships and nukes are visible only within 35 tiles of your or your allies' territory or 55 tiles of your warships. Missile silos and SAM launchers stay hidden unless a radar sweeps them. AI nations play under the same fog: they only aim at the structures they have seen. Each strike picks a target at random, weighted by value (capital, silos, cities, factories, ports...) and mixed with random points of the enemy territory, and avoids the areas they nuked recently or that are already irradiated, so their nukes spread over the whole nation instead of hitting the same spot. The troops of nations you do not observe (not you, an ally, a neighbour of you or your allies, or under one of your radars) are only shown as rough estimates like "~300K".
- **Buildings** (right-click > Build), paid in gold with escalating costs. When zoomed in, a small indicator above each of your structures shows what it brings right now: population in blue, gold per second in yellow, upkeep in red. Trade ports show an estimate once their first ship has delivered. A small bar in the bottom-left corner, just above the tile information, lists the key of each building: it dims what you cannot afford yet and lights up the one you are placing.
  - City: raises your maximum population, with diminishing returns for each extra city and within your housing capacity.
  - Trade Port: sends trade ships to nearby trade ports, so both sides earn gold. It is also a rail station.
  - Military Port: launches invasions overseas and builds warships.
  - Factory: lays pixel rail tracks across your own land to its 3 nearest cities and trade ports; trains generate gold. Each train pays less as your rail network grows, so stacking factories next to many cities no longer prints money.
  - Farm: only on plains. Raises your maximum population and speeds up growth, both diminishing with each extra farm and within your housing capacity, with no upkeep. Your plains feed one farm per 2,500 tiles (the first always works): extra farms do nothing until you own more plains, and the build menu warns `No free plains`.
  - Mine: only on mountains or deserts. Produces a steady flow of gold, 50% more on mountains, so the biomes that are hardest to conquer finally pay off. Each extra mine pays less, and your mountains and deserts hold one working mine per 2,000 tiles (the first always works): extra mines stay idle until you own more, and the build menu warns `No free ore`.
  - Barracks: speeds up population growth, trains your armies (each barracks lowers conquest costs, up to -25%) and extends your supply lines. It costs gold upkeep every tick; without the gold to pay, the bonuses stop.
  - Radar: sweeps a 110-tile radius (165 on a mountain) and leaves fading echoes of every enemy structure, ship and nuke its beam passes over. It is the only way to spot enemy missile silos and SAM launchers. Radars share their picture with your allies, are visible to enemy radars from twice their range, cost gold upkeep and are destroyed when captured.
  - Defense Post: raises the cost of attacking nearby tiles.
  - Missile Silo: launches nukes.
  - SAM Launcher: intercepts nukes aimed inside its range.
  - Bunker: shelters everything within 40 tiles from nukes. A blast centred in its range kills 70% fewer troops and workers, each of your buildings in its range has a 60% chance to survive with its tile, and the bunker itself only falls to a direct hit (6 tiles). The nuke preview warns you when a known enemy bunker shelters the target. AI nations build bunkers near their cities once an enemy owns a silo.
  - Nuke warning: you only learn about a nuke aimed at you or your allies once it is detected, either by a radar (yours or an ally's) or when it enters your vision. A radar covering the enemy silo warns you at launch. The warning shows a countdown, the blast zone and the missile's path.
  - Warship: built at a military port; patrols, sinks transports, captures trade ships, and fights other warships. Its depth charges deal 50% more damage to submarines.
  - Submarine: built at a military port; stays hidden from enemies unless a radar covers it, an enemy warship comes within 14 tiles (sonar), or it surfaces for 4 s after firing. It torpedoes transports, sinks trade ships instead of capturing them, and attacks warships as a last resort, so it wages a silent war on the enemy economy. Warships only engage the submarines they detect. Your own submarines are drawn half transparent while submerged. Right-click > Send Submarine Here dispatches one. Opportunist and Warlord AI nations build them to hunt the trade routes of their rivals.
- **Nukes** (right-click > Launch Nuke):
  - Atom Bomb, Hydrogen Bomb, and MIRV (splits into many warheads over the target nation).
  - Hovering a bomb in the menu previews its blast zone on the map: expected destroyed tiles, enemy land, friendly fire (your and your allies' tiles blink in white), known buildings hit, flight time from the silo that will fire, and the known enemy SAMs able to intercept it. Picking a bomb enters aiming mode: the preview follows the mouse, left click launches, right click or Escape cancels.
  - Nuked land loses its owner and gets fallout, which slowly decays and doubles conquest costs.
- **AI personalities**: every AI nation has a personality, shown when you hover its land and at the top of its context menu. It changes how it attacks, builds, negotiates and nukes:
  - Warlord: attacks early with big armies, keeps more troops, builds silos and nukes often, keeps few promises.
  - Merchant: builds cities, ports and factories, lends gold readily, prefers pacts to wars.
  - Guardian: fortifies its borders with defense posts and SAMs and only attacks when much stronger.
  - Diplomat: seeks alliances, supports its allies and rarely betrays.
  - Opportunist: preys on nations that are already under attack and betrays when it pays.
- **AI diplomacy**: AI nations negotiate with a plan rather than at random:
  - Pacts: at war, they offer non-aggression pacts to their other strong neighbours to secure their flanks, and accept them for the same reason. A threatened Guardian asks its stronger neighbours for peace. Before attacking a weak or embattled pact partner, they give the 30 s notice and only strike once the pact has ended.
  - Loans: they lend cheaply to their allies and to whoever fights their enemies, charge more to risky borrowers, and refuse traitors, their enemies, nations that threaten them and borrowers whose income cannot cover the debt. They borrow from their friends to fund a plan (barracks at war, a silo for nuclear powers, the next city for builders) only when their income can repay, save their gold when a deadline gets close, and repay early once they can.
- **Diplomacy** (right-click on another nation):
  - Request or accept an alliance; alliances expire after 5 minutes.
  - Propose a non-aggression pact: neither side can attack the other by land or sea for 10 minutes. Ending a pact gives 30 s of notice and no penalty; nuking a pact partner breaks it and marks you as a traitor.
  - Break an alliance, which marks you as a traitor and halves your defense for 30 s.
  - Embargo, donate troops or gold to allies, mark a player as a target for your allies, send emojis.
  - Request a loan (100K, 500K or 2M gold) from any nation. The lender can lend for free, demand 10% or 25% interest (the borrower then accepts or declines the terms), or refuse. Loans are repaid automatically in installments over 5 minutes, or early from the Empire panel. Whatever is still owed at the deadline is a default: the borrower is marked as a traitor and loses the lender's trust.
- **Coalitions** (right-click on another nation): blocs of up to 6 nations bound by permanent alliances while the coalition lasts.
  - Coalition Against: founds a war coalition against a dominant nation, the land leader or anyone holding 12% of the land. Once it has two members, they pay 20% less to conquer its land, and the target gets +10% defense against everyone so a coalition is not an instant death sentence.
  - Defensive Coalition: founds a coalition for mutual defense and invites that nation. Members get +10% defense against outsiders.
  - The leader invites new members from the context menu; invitations show up in the events panel. Members are allied and share their vision, and their alliances do not expire.
  - The Coalition panel lists the members, the objective and the bonus. Leaving in peace costs nothing, but deserting a war coalition while its target stands marks you as a traitor and breaks your alliances with the members.
  - A war coalition dissolves once its target falls, or drops under 4% of the land without being the leader anymore; a coalition that finds no member dissolves on its own. There is no shared victory: the members become rivals again.
  - AI nations found coalitions against the leader they fear or hate (Diplomats most of all), invite the nations that border or dislike the target, join the coalitions whose target threatens them, and focus their attacks and nukes on it. Threatened Guardians found defensive coalitions with the other neighbours of their threat. Coalition members show a coloured mark in the leaderboard, coalition targets a skull, and hovering a nation shows its coalition.
- **Team games**: pick 2, 3 or 4 teams in New Game or in the lobby. In the lobby every player chooses a side or stays on Auto, which fills the smallest team. Nations fill the teams evenly, grouped by position so that each team starts as a bloc, and every territory takes a shade of its team color. Tribes stay out of the teams.
  - Teammates are allied for the whole game: they share their vision, can donate troops and gold, and can neither attack, nuke nor betray each other.
  - Sides are fixed: alliances, pacts and coalitions are disabled. Loans, embargoes and targets still work, and a nuke aimed at an enemy can still hurt a teammate next to it.
  - A team wins when its members hold 80% of the land together, or when it is the last team standing, even if tribes remain. Every member wins, even one already eliminated. The Teams panel shows the land of each team against that goal and how many members are alive.
- **Victory**: control 80% of the land, or be the last nation standing.
- **Surrender**: the pause menu has a Surrender button (click it twice to confirm). Your nation leaves the game: its land becomes wilderness, its buildings, ships and attacks disappear, and you can keep watching. Teammates keep fighting.
- **Rematch**: at the end of a multiplayer game, everyone still in the room can vote for a rematch. A new game starts on the same settings, with a new seed, as soon as all of them agree. Solo games have Play Again.
- **End of game stats**: the victory and defeat screens chart your share of the land over time against your three strongest rivals, and list your peak and final territory, tiles captured, attacks launched, buildings, nukes launched and nations eliminated. The history is part of the simulation (sampled every 5 seconds), so it survives reconnections and snapshots.

## Research

Press `E` or click the research button next to the gear to open the tree: 24 technologies in four branches (economy, military, navy, strategic), each with four tiers.

- **Queue**: click a technology to queue it with what it requires, up to 5. `Shift` + click researches it first, and a click on a queued one cancels it. Progress is kept.
- **Doctrines**: the third tier of each branch asks for one choice between two doctrines, marked by a gold edge. Each one has a real drawback and excludes the other for the whole game.
- **Paying**: a technology is paid little by little while it runs, so it never takes a lump sum. If you hold less than its price, research only takes half of your income and slows down, which always leaves gold for buildings.
- **Cost**: each tier has a base price and a price in seconds of your income, and you pay the higher one. A large empire therefore pays more, which limits snowballing. The price is locked when the research starts.
- **Sharing**: a technology known by an ally or a teammate is 20% cheaper, and 15% cheaper once half of the nations know it, so those who fall behind catch up.
- **Capitals**: losing your capital pauses your research. Capturing a capital steals plans: one technology the victim knows is immediately half researched, and you only pay for the rest.
- **AI**: on medium and hard, nations research from the 4th minute according to their personality. Tribes and easy nations do not research.

| Tier | Base price | Income share | Time |
| --- | --- | --- | --- |
| 1 | 100K | 30 s | 1 min |
| 2 | 250K | 45 s | 1 min 30 |
| 3 | 500K | 60 s | 2 min |
| 4 | 1M | 90 s | 3 min |

Bonuses stay small next to barracks (-25%) or coalitions (20%): at most +11% income, -11% conquest cost and +14% defense along one path. Researching the whole tree takes over half an hour, so a game forces choices. `research_test` enforces these caps and the payback of economic technologies.

## Game Modes and Rules

The **Rules** button in New Game and in the lobby opens the mode and the custom rules. In a lobby only the host can change them; guests can read them. Picking a mode fills in the rules, and changing a rule switches to Custom (or to the mode it now matches).

| Mode | Rules |
| --- | --- |
| Classic | The standard rules |
| Blitz | 60% of the land to win, 20 minute limit, 1M gold, army x5, income x2, 5 s spawn, fast research |
| Conventional | No nukes, missile silos or SAM launchers |
| Anarchy | No alliances, pacts or coalitions |
| Annihilation | 100% of the land: only the last nation standing wins |

| Rule | Values | Effect |
| --- | --- | --- |
| Land to win | 50% to 100% | Share of the land that wins the game, for a player or a team |
| Time limit | None, 10, 20, 30, 60 min | The largest empire or team wins when it runs out; the clock counts down |
| Starting gold | 0 to 5M | Gold of every player and nation |
| Starting army | x1, x2, x5, x10 | Multiplies the first troops and workers |
| Income | x0.5 to x4 | Multiplies the gold earned by workers |
| Spawn time | 5 to 60 s | Length of the spawn phase |
| Research | Off, Normal, Fast | Removes the research tree, or doubles its speed |
| Nukes | On, Off | Removes silos, SAM launchers and nukes, for the AI too |
| Diplomacy | On, Off | Removes alliances, pacts and coalitions, for the AI too |

The server sanitizes the rules against this list and the simulation enforces them, so every client agrees. The tutorial always uses the classic rules.

## Replays

Every game lasting at least 30 seconds is saved when it ends or when you leave it, in `replays/` in the save directory; the last 20 are kept. The tutorial is not recorded, and neither is a game the client restored from a snapshot, since part of it is missing.

A replay stores the seed, the settings and the frames that carry commands or a state hash, zlib compressed. Since the simulation is deterministic, watching one simply runs the game again from these commands and compares the recorded hashes; a mismatch shows a warning instead of silently diverging. A replay recorded with another network version cannot be opened.

Press **Replays** in the main menu, or **Watch Replay** on the end screen. The whole map is visible, the clock controls pause and speed, and the bar at the bottom jumps 30 seconds or to any point of the timeline. Going back rebuilds the game from the start, so it takes a moment on long games.

## Sound

Every sound is synthesized when the game starts, with no audio file: square, triangle, saw, sine and noise layers shaped by an envelope (`src/modules/audio/synth.lua`), described as recipes in `src/modules/audio/sounds.lua`. The simulation only reports events to an observer, which `src/modules/audio/cues.lua` turns into sounds for the local player, so audio can never affect determinism and the fog stays intact: an enemy nuke is only heard when it explodes within your vision. Set the volume in the Settings screen or from the pause menu.

## Pixel Art

Everything on the map is drawn on the tile grid: buildings, rails, ships with their wake, troops marching to the front, combat flashes, nukes with smoke trails, fireballs, mushroom clouds and scorched craters. The interface uses the [Jersey 10](https://fonts.google.com/specimen/Jersey+10) pixel font (SIL Open Font License, see `assets/fonts/OFL.txt`).

## Controls

| Input | Action |
| --- | --- |
| Left click | Spawn / attack / send boat |
| Right click | Context menu |
| Right drag | Move the camera |
| Mouse wheel | Zoom |
| `Space` | Start the game during the spawn phase |
| `E` | Open the research tree |
| `P` | Pause |
| `+` / `-` | Change game speed (x1, x2, x4, x8) |
| `1` `2` `3` `4` `5` | Toggle terrain, territories, units, names, supply |
| `Enter` | Open the chat in multiplayer (`Tab` switches between all and allies) |
| `H` | Controls help |
| `Escape` | Settings |

Drag a panel by its header to move it. Positions are saved in `hud_config.txt`, and menu choices in `menu_config.txt`, both in the Love2D save directory.
