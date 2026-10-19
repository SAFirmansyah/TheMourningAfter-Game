# The Mourning After – Components

> Naming: Hero = Perrin, Villain = Constance, Farmer = Gwenith, Medic = Shuyi, Guard = Rudrama.

## Presentation

- 2.5D, close to Cult of the Lamb. All assets are 2D, placed on a 3D plane.
- Perspective camera follows the player at a fixed 25° pitch and fixed zoom; the player cannot pan, rotate or zoom it.
- Characters and location objects are "cards" that turn to face the camera's position (not parallel to the screen).
- Art style TBD: pixel-art backgrounds with painted characters, or everything painted.

## Cutscenes

- The Plague
- Inciting Incident
- First Venture
- False Credits
- Back to Burhana
- Huyana's Hubris
- Montage
- True Endings

## Base locations

- Hero's room in the army base: contains his mother, some personal belongings, an armor stand, a prayer area, a sword stand, some books and scrolls
- The Cult's Altar: contains mutated pets, bookshelf, Villain and her dead kid's personal belongings, writing board, bloodstained altar, money vault, forestry tools
- The Cult's Sanctuary (can access Altar from here): has containments for mutants, farm plots, lab stations, anvils, bonfire area, a path to the altar, and a blocked path that leads outside opposite the path to the altar
- The Kingdom is named Silvaluca, the Cult is Huyana, and the civilization they originated from was Burhana

## Characters

- Hero (Perrin)
- Hero's mother (Avelina)
- Hero's deceased father (Bardolf)
- Villain (Constance)
- Farmer (Gwenith)
- Medic (Shuyi)
- Guard (Rudrama)
- 3 Fates (Archi, Seira, Kano)

## Fate bargains

- Magical residue is the cost of a bargain – this is the only item gained that persists after resurrection. Hero starts out with 2 residue left over from the spell in the inciting incident.
- Fate 1 re-seeds the hero's stats values & weapon
- Fate 2 re-rolls which first boss to fight on a given run
- Fate 3 consumes no residue and automatically resurrects the hero

## Hero's stats

- Max Health (50–200 pt)
- Move speed (0.5x–2x)
- 1 Dash (grants invulnerability frames)

## Hero's weapons

- Wood sword (low damage, high speed, offers occasional self-heals)
- Bone sword (medium damage, medium speed, adds poison chip damage to mobs for a certain duration)
- Bronze sword (high damage, low speed, % chance of stunning mobs except bosses)
- Iron sword (high damage, low speed, % chance of dealing critical damage)
- Exact stats for damage & speed TBD

## Sword moveset

- LMB for attack
- Q for heavy attack (much slower but can one-shot deformed humans; needed to get past the Guard's shield)

## Buffs

- Unlock a second dash
- Incoming damage reduction (exact % TBD)

## Roguelike loop overview

- Combat 1st half: 2–3 combat rooms, 1st non-combat room, 2–3 combat rooms
- Boss fight
- Combat 2nd half, route changes depending on which boss was fought: 2–3 combat rooms, 2nd non-combat room, 2–3 combat rooms
- Final boss fight (surprise, it's getting skipped)

## Mobs

- Deformed humans (weak, found in greater numbers) drop simple loot that can be used to upgrade the weapon's attack/speed, or the player's health/speed
- Low-level mutants (stronger, fewer found in each room) drop higher-grade loot with which to gain buffs or magic residue (0–3 residue generated per run)
- All mob drops and buffs/upgrades gained are lost upon death
- Exact stats for mob count, mob behavior, and loot chances TBD

## Combat rooms

- In combat 1st half, the rooms are in the forest between the Kingdom and the Cult
- In combat 2nd half, the rooms depend on which boss was fought: if Gwenith, it's farmlands and gardens. If Shuyi, it's labs and research rooms. If Rudrama, it's barbed wire containments and training grounds
- Clear combat rooms by killing all mobs in the room

## Non-combat rooms

- The first one (Forest side) is a small clearing with a pond that heals if drunk from (restores 50% of missing HP)
- The second one (Cult side) depends on which boss was fought: if Gwenith, it's a barn. If Shuyi, it's a medical bay. If Rudrama, it's a forge

## First boss

- Happens just after the Kingdom border, trying to stop you from entering the forest/Cult side. Can be re-rolled exactly once per run
- Option 1: Gwenith (Farmer) – fights with sickles (short range) and throws projectile potions that can harm you or land on the ground to create a temporary AOE
- Option 2: Shuyi (Medic) – fights with a 'rod of asclepius' staff (long range) and can heal herself mid-fight
- Option 3: Rudrama (Guard) – fights with an axe (mid range) and shield, melee tank with defense

## Interactions

- Press E to interact with items or NPCs in locations, collect loot/accept rewards
- LMB to further dialogue

## Resource management overview

- Feel: a restaurant sim, but less fast-paced. Constance can (and is encouraged to, but doesn't have to) handle requests between Gwenith, Shuyi and Rudrama faster than they would on their own, leading to fewer misses and slower Sanctuary Health decay.
- Gwenith requires seeds. She grows everything:
  - Human food, automatically (this takes up some of her capacity)
  - Mutant food (Infused Dew, Willow Bark, Graceroot), slowly or on request, if she has the capacity for it
  - Medicine ingredients (Bloodflower, Obsidian Grass, Pearls of Night), on request, if she has the capacity for it
  - Capacity math TBD
- Shuyi requires medicine ingredients from Gwenith and combines them into specific medicines for mutants upon request
- Rudrama requires metal and repairs containment facilities upon request
- The player is on a day/night cycle (length TBD), with each day presenting a number of tasks – feed mutants (increased demands daily), cure mutants' diseases (request the right medicines), and fix containment weaknesses (request Rudrama to repair on time)
- Unfulfilled requests by night lead to starvation, sickness, and escapes, reducing Sanctuary Health, a value that goes from 100% to 0%
- The resource management aspect is not something the player can beat, only prolong. Human needs (food & medicine from Gwenith directly) are taken care of automatically, and Gwenith/Shuyi/Rudrama's needs will be too. But as the human population declines, their needs and contributions both go down
- Exact quantities TBD

## Mutant food & medicine

- Mutants are of three varieties based on their diet, which can be Infused Dew, Willow Bark, or Graceroot. All mutants are sorted into containments based on this, so each containment will only request that one kind of food.
- Any containment can however develop any kind of sickness, requiring one of three medicines: Haemoshear, Nacrescorch, or Capillanyx.
- Haemoshear is synthesized using Bloodflower and Obsidian Grass; Nacrescorch using Obsidian Grass and Pearls of Night; Capillanyx using Pearls of Night and Bloodflower.

## Sanctuary story beats

- At 75% health, trigger Gwenith's story beat
- At 50% health, trigger Shuyi's story beat
- At 25% health, trigger Rudrama's story beat
- At 0% health, trigger the Fates' story beat
- Sanctuary health, populations, etc., are not visible on screen during the day. SH changes are shown at night.

## Final boss (fight as Constance)

- Takes place in the Sanctuary: Constance enters from the Altar as Perrin enters from the cult routes of the roguelike
- Constance's special abilities: spellcasting, summoning deformed humans & low-level mutants for support
- Constance's borrowed abilities: projectile potions / self-healing / shield defense, except the one belonging to the boss Perrin killed earlier
- Perrin fights with the loadout the player obtained
- Perrin's moveset also applies to Constance, but she starts with 100 HP, 1x movement speed, and 1 dash. She fights with a staff that has the same stats as a base Iron Sword
- "Victory of the time thief" ending if Constance wins, "Losing a lost cause" ending if Perrin wins
