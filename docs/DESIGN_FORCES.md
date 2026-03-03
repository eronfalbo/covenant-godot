# The Two Forces — Design Specification

Two meters run through the entire game. They are the hidden physics
behind the covenant's fate. The player sees them from Year 1 on Ararat
and carries them all the way to the Dispersion.

---

## Force 1: Assimilation

**The single thread from Cain to Babel.**

Assimilation is the turning outward — away from the fire, the altar,
the covenant. It is always the same force, but what it looks like
changes because the world changes around it.

### Phase Evolution

| Phase | Meter Name | What the Force IS | Player Sees |
|-------|-----------|-------------------|-------------|
| Ararat | Assimilation (Outwardness) | Eyes drift from altar to horizon. No city to join — just the pull toward land, settling, the field over the offering. Cain before the city. | "Quiet" → "Restless" → "Drawn to the horizon" → "The mountain feels small" |
| Shinar (early) | Assimilation (Sedentariness) | The brothers have settled on the plain. The pull is to stay put, build permanent, stop being nomads-of-the-covenant and become people-of-a-place. Risk: wanting a homeland. | TBD |
| Shinar (mid) | Assimilation (City-Dwelling) | Ham's settlement is real. Markets, walls, specialization. The covenant community looks backward by comparison. Risk: the city is more attractive. | TBD |
| Babel (early) | Assimilation (Centralisation) | One man, one throne, one system. Nimrod. Everyone serves the project. The tower demands total participation. | TBD |
| Babel (late) | Assimilation (Naming) | "Let us make a name for ourselves" (Gen 11:4). The attempt to fix meaning in human terms. Cataloging, archiving, defining. This IS the step before worship — naming what you've built makes it sacred. | TBD |
| Consecrating | Assimilation (Worship) | The name becomes the god. The temple replaces the altar. Baal. Game over at 100%. | TBD |

### The Naming Insight

Naming comes AFTER centralisation, not before. You centralise around
a throne, then you NAME what you've built. "Let us make a name for
ourselves" is not the beginning of Babel — it is the consecration of
it. The name becomes the idol. This is the step between political
power and spiritual replacement.

### Mechanical Sources (Ararat)

- **Passive drift**: +0.1/season (entropy — time erodes inwardness)
- **Material focus**: gathering/building allocation > tending/teaching → up to +0.25/season
- **Skipping sacrifice**: +0.2/season after 2 consecutive seasons
- **Brakes**: tending AND teaching together halves growth
- **Cap**: ~15% on Ararat

### Mechanical Effects

- **Root decay multiplier**: `effective_decay = base * (1 + assimilation * 0.02)`
  - At 5 assimilation: 1.1x (invisible)
  - At 15 assimilation: 1.3x (Ararat cap, noticeable)
  - At 50 assimilation: 2.0x (Shinar, urgent)
- **Future**: drifters (people who lose covenant identity), building effectiveness loss, profession assimilation risk

### Key Event: Ham Exits the Covenant

When Ham officially breaks away (event TBD, likely late Shinar),
assimilation DROPS drastically. The covenant is purified — the people
who remain are the ones who chose to stay. But this also makes the
remaining community smaller and more vulnerable to hostility.

---

## Force 2: Hostility

**The world's response to covenant existence.**

Hostility is not steady pressure — it is bursts. Spikes. Pogroms, not
erosion. Between spikes, life feels normal. This is how it works in
real life. There are moments that are worse, then things go back to
normal. The game tells the story of the secret physics behind this.

### Phase Evolution

| Phase | Meter Name | What the Force IS | Manifestation |
|-------|-----------|-------------------|---------------|
| Ararat | Hostility (Elements) | Only weather can be hostile. The animals walked off the ark WITH them — they're family still. | Storms, cold, drought. Food/livestock loss. |
| Shinar (early) | Hostility (Nature) | Animals begin to forget. The natural world grows indifferent, then hostile. | Animal attacks, crop blight, predators taking livestock. |
| Shinar (mid) | Hostility (Social) | The city doesn't trust the people who won't join. "Why won't you come to the market on our day?" | Trade restrictions, social isolation, slander. |
| Babel | Hostility (Political) | Nimrod needs everyone. Refusal is treason. The covenant community is a threat to unity. | Forced labor, tribute demands, persecution. |
| Dispersion | Hostility (Hatred of Shem) | Not a reaction to behavior. A reaction to existence. The world hates the reminder that the fire was supposed to be tended. This IS anti-semitism. | Targeted violence, expulsion, destruction. |

### The Anti-Semitism Arc

Anti-semitism is not introduced as a concept. It emerges from the
mechanics. The player experiences:

1. Weather that doesn't cooperate (elements)
2. Animals that turn aggressive (nature)
3. Neighbors who distrust them (social)
4. A state that demands compliance (political)
5. A world that hates them for existing (hatred of Shem)

By the end, the player feels it: "This isn't about what we DO.
It's about what we ARE." That is the moment they understand
anti-semitism not as a historical phenomenon but as a force.

### Spike Mechanics

Hostility doesn't rise steadily. It SPIKES.

- **Base hostility**: trends toward `(100 - tree_of_life) * 0.15`
  - High fire → hostility trends to 0. Low fire → trends to ~10-15.
- **Spike trigger probability** (per season):
  - `(70 - tree_of_life) * 0.003` if fire < 70
  - `+ assimilation * 0.005` if assimilation > 5
  - Capped at 25% per season on Ararat
- **Spike duration**: 2-3 seasons
- **Spike effects**: food loss, livestock loss, narrative event
- **Spike residue**: each spike leaves +2 permanent hostility (scars accumulate)
- **Between spikes**: hostility recedes. This is the "normal" that makes the next spike feel worse.

### Future Spike Mechanics (Post-Ararat)

- **Killer hostility**: at 100%, game over (community destroyed)
- **Killer assimilation**: at 100%, game over (covenant replaced)
- **Death spiral**: high assimilation → more spikes → more fear → more assimilation → one meter hits 100
- **The only brake is the fire**: high Tree of Life resists both forces

---

## The Feedback Loop

```
                    ┌──────────────────────────────┐
                    │                              │
                    ▼                              │
            ASSIMILATION ──────► ROOT DECAY ──► TREE OF LIFE drops
                    │                              │
                    │                              ▼
                    │                         HOSTILITY rises
                    │                              │
                    │                              ▼
                    └──── fear drives ◄──── SPIKES (food/livestock loss)
                         more assimilation
```

The player who focuses only on material production sees:
1. Assimilation rises → roots decay faster
2. Roots weaken → fire drops
3. Fire drops → hostility rises
4. Hostility spikes → food/livestock lost
5. Fear of loss → more material focus → more assimilation

The only way to break the cycle is the inward acts: tending, teaching,
sacrifice. The fire sustains the roots, the roots slow assimilation,
low assimilation prevents hostility spikes.

---

## The Baal Cycle Stages (existing code: BAAL_STAGES)

These map to the Assimilation phases. Currently in game_state.gd:

```
Stage 0 - Gathering (threshold 0):    "Market camps, paths worn into the dust"
Stage 1 - Naming (threshold 20):      "The settlement has a name."
Stage 2 - Walling (threshold 40):     "Walls rise. Us and them."
Stage 3 - Enthroning (threshold 60):  "A man crowned."
Stage 4 - Consecrating (threshold 80): "A temple rises. Game over."
```

NOTE: These thresholds are keyed to ham_centralisation (0-100 internal
variable). The player-facing Assimilation meter is a separate but
related concept. In future phases, assimilation and ham_centralisation
may converge or diverge depending on whether Ham has exited the
covenant. When Ham leaves, his centralisation continues independently
but the covenant's assimilation drops.

---

## Implementation Status

### Done (Ararat / Tutorial)
- [x] assimilation variable (0-100, capped ~15 on Ararat)
- [x] hostility variable (0-100, capped ~12 on Ararat)
- [x] Assimilation grows from material focus, slowed by inward acts
- [x] Assimilation multiplies root decay
- [x] Hostility driven by tree_of_life neglect
- [x] Hostility spikes (2-3 season bursts, food/livestock loss)
- [x] Both meters in HUD with descriptive labels
- [x] Both meters on departure screen
- [x] Food-low warning at ≤4 food
- [x] ararat_legacy captures both meters for Shinar

### TODO (Shinar / Post-Tutorial)
- [ ] Phase name evolution (Outwardness → Sedentariness → City-Dwelling)
- [ ] Hostility name evolution (Elements → Nature → Social)
- [ ] Assimilation uncapped, new sources (city proximity, drifters, profession risk)
- [ ] Hostility uncapped, new spike types (animal attacks, trade embargo, tribute)
- [ ] Ham's exit event: assimilation drops, community shrinks
- [ ] Killer levels: assimilation 100% or hostility 100% = game over
- [ ] Death spiral feedback loop fully active
- [ ] Anti-semitism emergence: hostility narrative shifts from nature to social to political
- [ ] Drifter system: people leaving covenant based on assimilation + profession assim_risk
- [ ] Building effectiveness loss as assimilation rises
