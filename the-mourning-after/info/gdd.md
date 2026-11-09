# The Mourning After – Complete Game Design Document

> Naming: HERO = PERRIN, VILLAIN = CONSTANCE.

## START GAME

- If this is the player's first time playing:
  - **CUTSCENE – inciting incident**
    CONSTANCE at the city centre of SILVALUCA, casting a spell that drains citizens' lifetimes, and the devastating effects of this.
  - **NARRATIVE BEAT – motivation**
    PERRIN is instructed by his aged MOTHER to seek out the witch he'd seen and bring justice.
- Else:
  - [Optional] Interact with various objects in BASE for further dialogue
  - START RUN

## PREPARE FOR RUN

Note: The game's save/load system will auto-save upon every COMBAT ROOM clear, BOSS clear, and FATE BARGAIN, and the player can manually save before quitting at any point other than in the middle of a COMBAT ROOM – force quit here will wipe the run.

- If this is the player's first run:
  - **NARRATIVE BEAT – doubt**
    PERRIN gets a starting loadout of 50 HP and 0.5x move speed, as well as a wood sword. He feels weak and unconfident in his abilities. He senses the presence of FATE 1 (formerly, ARCHI) and prays, offering RESIDUE in exchange for luck.
  - **[FORCED] FATE 1 BARGAIN**
    Count of RESIDUE in PERRIN's inventory is set from 2 → 1 and his starting loadout changes to 100 HP, 1x move speed, and bone sword.
  - **CUTSCENE – first venture**
    PERRIN sets out from BASE, which is a tower as part of a wall guarding the borders of SILVALUCA, and enters the forests outside, armed and ready to slay enemies.
- Else:
  - **RANDOMIZATION – starting stats & weapon**
    PERRIN gets a starting loadout of 50–200 HP and 0.5x–2x move speed, as well as a wood/bone/bronze/iron sword.
  - **[OPTIONAL] FATE 1 BARGAIN**
    Possible if count of RESIDUE in PERRIN's inventory is at least 1. Consumes 1 RESIDUE and randomizes starting stats & weapon again. Maximum of 1 bargain per run.

## START ROGUELIKE RUN

### FOREST SIDE

- **COMBAT 1**
  2 or 3 COMBAT ROOMS (layout randomized with elimination) with a blocked path to the next room, and a randomized mob cap consisting of DEFORMED HUMANS and LOW LEVEL MUTANTS. If PERRIN has >0 HP remaining when all mobs are killed, gain loot & unblock the path to the next room. Else, trigger FATE 3 BARGAIN.
- **NON COMBAT**
  A clearing with a pond from which PERRIN can drink to restore half of the health he is missing.
- **COMBAT 2**
  2 or 3 COMBAT ROOMS (layout randomized with elimination) with a blocked path to the next room, and a randomized mob cap consisting of DEFORMED HUMANS and LOW LEVEL MUTANTS. If PERRIN has >0 HP remaining when all mobs are killed, gain loot & unblock the path to the next room. Else, trigger FATE 3 BARGAIN.

### BOSS SELECTION

- If this is the player's first time making it to the boss fight:
  - **NARRATIVE BEAT – fear**
    PERRIN glances through the path and sees BOSS CHAMBER – RUDRAMA. He's scared to face her, senses the presence of FATE 2 (formerly, SEIRA) and prays, offering RESIDUE in exchange for a different opponent.
  - **[FORCED] FATE 2 BARGAIN**
    Count of RESIDUE in PERRIN's inventory is set from 1 → 0 and PERRIN crosses the path again, this time to BOSS CHAMBER – SHUYI instead.
- Else:
  - **RANDOMIZATION – boss fight**
    PERRIN glances through the path and sees BOSS CHAMBER – GWENITH/SHUYI/RUDRAMA.
  - **[OPTIONAL] FATE 2 BARGAIN**
    Possible if count of RESIDUE in PERRIN's inventory is at least 1. Consumes 1 RESIDUE and randomizes BOSS CHAMBER again with elimination. Maximum of 1 bargain per run.

### BOSS

- **NARRATIVE BEAT**
  The BOSS attempts to dissuade PERRIN from going further with some meaningful dialogue.
- **WIN**
  PERRIN has >0 HP remaining and celebrates his victory over the boss with some meaningful dialogue.
- **LOSS**
  PERRIN reaches 0 HP while the boss is still alive, triggers FATE 3 BARGAIN.

### CULT SIDE

- **COMBAT 3**
  2 or 3 COMBAT ROOMS (layout randomized with elimination; location varies based on which BOSS was fought) with a blocked path to the next room, and a randomized mob cap consisting of DEFORMED HUMANS and LOW LEVEL MUTANTS. If PERRIN has >0 HP remaining when all mobs are killed, gain loot & unblock the path to the next room. Else, trigger FATE 3 BARGAIN.
- **NON COMBAT**
  Location varies based on which BOSS was fought. Optionally interact with items in the environment for lore, heal using HUYANA's supplies.
- **COMBAT 4**
  2 or 3 COMBAT ROOMS (layout randomized with elimination; location varies based on which BOSS was fought) with a blocked path to the next room, and a randomized mob cap consisting of DEFORMED HUMANS and LOW LEVEL MUTANTS. If PERRIN has >0 HP remaining when all mobs are killed, gain loot & unblock the path to the next room. Else, trigger FATE 3 BARGAIN.

### REACHING THE SANCTUARY

- If the player has made it to the final boss fight:
  - The game saves a snapshot of PERRIN's max HP, movement speed, # of dashes, weapon and buffs, and which boss was killed on this run, to be used later during the montage & final boss fight (as villain).
  - **NARRATIVE BEAT – denied glory**
    PERRIN steels his nerves and bursts through the path into HUYANA, finding the ruined SANCTUARY and CONSTANCE in it. He threatens her, but she doesn't give him the fight he demands, instead seeming to bow her head and give up.
  - **CUTSCENE – false credits**
    PERRIN, confused, lunges at CONSTANCE, then the game hard cuts to black, and credits start to roll.
  - **CUTSCENE – the plague**
    We watch from CONSTANCE's perspective as BURHANA falls to a deadly disease, leaving a few survivors who establish HUYANA in the forest and dedicate themselves to the cause of curing death.
- Else:
  - **FATE 3 BARGAIN**
    PERRIN is resurrected and taken back to BASE, to PREPARE FOR RUN again.

## START HUYANA'S STORY

### LORE

- **ALTAR**
  Spawn as CONSTANCE and interact with a few items in the room before unlocking the path to the SANCTUARY.
- **SANCTUARY**
  Enter the SANCTUARY and interact with GWENITH, SHUYI and RUDRAMA at their work stations to begin the day/night cycle.

### TUTORIAL

Request and repair mechanics are taught first, then their consequence (SANCTUARY HEALTH).

- **NIGHT 0**
  Textual instructions are displayed explaining what human members bring in, what each work station needs & produces, and how to make requests from GWENITH, SHUYI, and RUDRAMA based on MUTANTS' needs.
- **DAY 1**
  CONSTANCE auto-walks between stations to demonstrate RESOURCE MANAGEMENT.
- **NIGHT 1**
  SANCTUARY HEALTH is introduced, currently at 100, along with a warning that unfulfilled requests during the day will reduce it irreversibly.

## START RESOURCE MANAGEMENT

Note: During the Day/Night Cycle, if the Night reveals that a SANCTUARY HEALTH threshold has been reached (75/50/25), clicking proceed will cue in the next STORY EVENT, and only after that does the next Day begin. The game also auto-saves upon each request being fulfilled or expiring, and at every Night. Manual save is possible; force-quitting just resets to the latest save.

Pacing: plays like a restaurant sim, but less fast-paced. GWENITH, SHUYI and RUDRAMA work through requests on their own, slowly. CONSTANCE can (and is encouraged to, but doesn't have to) carry requests and items between them faster than they would manage alone, leading to fewer misses and slowing the decay of SANCTUARY HEALTH. SANCTUARY HEALTH never goes back up.

- **SANCTUARY HEALTH > 75**
  - **DAY X**
    Human members' contributions are added in batches throughout the day, which GWENITH takes and uses to produce food for human members (automatic, uses up some of her CAPACITY). Between batches, GWENITH's CAPACITY for requests for MUTANT food (Infused Dew, Willow Bark, Graceroot) and MUTANT medicine INGREDIENTS (Bloodflower, Obsidian Grass, Pearls of Night) increases. Once these are grown, MUTANTS can be fed, or INGREDIENTS can be handed off to SHUYI to synthesize into specific medicines (Haemoshear, Nacrescorch, Capillanyx) by request, depending on the MUTANTS' (timed) needs that show up throughout the day. Periodically, CONTAINMENT INTEGRITY lowers in some CONTAINMENTS, which can be fixed by asking RUDRAMA to repair them (takes time).
  - **NIGHT X**
    Unfulfilled MUTANT needs and unfixed CONTAINMENTS (every 10% lost counts as a unit) reduce SANCTUARY HEALTH by some % which is TBD. This is displayed to the player, and when they click to proceed, the next day starts.
- **GWENITH'S STORY EVENT**
  - **NARRATIVE BEAT – possibility**
    GWENITH reveals the fruits of her experiments on MUTANTS to CONSTANCE, who has the first epiphany about the big spell.
- **SANCTUARY HEALTH > 50**
  - **DAY X** – Same as before, but incoming resources reduce.
  - **NIGHT X** – Same as before.
- **SHUYI'S STORY EVENT**
  - **NARRATIVE BEAT – strategy**
    SHUYI warns CONSTANCE about conserving resources for the MUTANTS, which leads to a second epiphany.
- **SANCTUARY HEALTH > 25**
  - **DAY X** – Same as before, but incoming resources reduce drastically.
  - **NIGHT X** – Same as before.
- **RUDRAMA'S STORY EVENT**
  - **NARRATIVE BEAT – anxiety**
    RUDRAMA encourages CONSTANCE to try more extreme methods, anything to make things work, and it inspires a third epiphany.
- **SANCTUARY HEALTH > 0**
  - **NARRATIVE BEAT – fate**
    ARCHI, SEIRA, and KANO (in human form) approach CONSTANCE and volunteer for the most ambitious experiments she can think of. They carry it out at the SANCTUARY's bonfire and it fails; the three sisters disappear. CONSTANCE has her final epiphany.

## FINAL DECISION

- **BUILD UP**
  - **NARRATIVE BEAT – choice**
    CONSTANCE runs to the ALTAR flanked by GWENITH, SHUYI, and RUDRAMA. She reveals her completed spell to them and they weigh in. CONSTANCE weighs the risks it could mean for the SILVALU people.
- If the player chooses 'No':
  - **CUTSCENE – back to burhana**
    In choosing not to kick off the inciting incident, the sisters of HUYANA perish and are reunited with their dead from BURHANA.
  - **SECRET ENDING**
    The game seems to delete itself – the save is wiped, a flag is written, and every later launch shows only a black screen.
- If the player chooses 'Yes':
  - **CUTSCENE – huyana's hubris**
    CONSTANCE casts the spell, and we watch the inciting incident play out again, but with added perspective now.
  - **CUTSCENE – montage**
    A brief montage plays, showcasing PERRIN's valor as he fought in the final run of the roguelike. A hard cut to black, followed by a fast-forward.

## TRUE ENDINGS

- **FINAL BOSS FIGHT**
  - **NARRATIVE BEAT – for anything but glory**
    Still in CONSTANCE's perspective: she leaves the ALTAR and enters the SANCTUARY as PERRIN arrives there from the cult routes, no longer controlled by the player, demanding a fight. CONSTANCE considers surrender, then feels the presence of all three FATES compelling her to resolve things. She makes her mind up and gives PERRIN his final boss fight.
  - **COMBAT**
    The player fights as CONSTANCE against PERRIN, who bears the final stats and weapon that the player had gained before the false credits. The fight takes place in the SANCTUARY.
- If CONSTANCE wins:
  - **CUTSCENE – victory of the time thief**
    Specifics TBD
- If PERRIN wins:
  - **CUTSCENE – losing a lost cause**
    Specifics TBD

## DESIGN CHANGES

These changes were made after the original design. The sections above are left as originally written; where they disagree, the notes below take priority.

- **FATE 3 BARGAIN (changed)**
  *Originally:* when PERRIN reaches 0 HP, FATE 3 BARGAIN kicks in automatically, and PERRIN is resurrected and taken back to BASE to PREPARE FOR RUN again.
  *Now:* when PERRIN reaches 0 HP, combat pauses and FATE 3 offers a bargain on screen to revive PERRIN where he fell and continue the run.
  - The cost rises each time within a run: the 1st revive costs 2 RESIDUE and the 2nd costs 3. There is no 3rd revive.
  - If PERRIN doesn't have enough RESIDUE for the next revive (or has used both), there is no offer, and he dies as before: resurrected and taken back to BASE.
  - If he can afford it, the player chooses between:
    - **Bargain:** spend the RESIDUE and resume the fight after a 3-second countdown.
    - **Die:** turn the offer down, and go back to BASE to start over.

- **BARGAIN COSTS (changed)**
  *Originally:* every FATE bargain cost 1 RESIDUE, and the optional FATE 1 and FATE 2 bargains were limited to 1 per run.
  *Now:*
  - **FATE 1 (re-seed starting stats & weapon):** 1 RESIDUE, no limit on how many times per run.
  - **FATE 2 (re-roll the BOSS CHAMBER):** 2 RESIDUE, once per run.
  - **FATE 3 (revive):** 2 RESIDUE the first time and 3 the second; no third time.
  - The forced bargains on a fresh save still play out as written: FATE 1 takes RESIDUE from 2 → 1 and FATE 2 from 1 → 0.
