# Covenant — Design Notes

Current source of truth is the Godot game itself. This file tracks design decisions,
known constraints, and autoplay observations. The Notion workspace is deprecated as
reference — everything salvageable has been moved to game files.

---

## Game State (as built)

### Tutorial Scope: Years 0-7 on Ararat
- 8 souls → grows via birth events (Torah-exact) and percentage growth
- 4 seasons per year: Autumn, Winter, Spring, Summer
- Player allocates workers each season: Gather, Tend Fire, Tend Livestock, Build, Teach
- Simplified economy: food, livestock, provisions, living_fire (Tree of Life)
- 8 Roots (pillars) scored 0-10 each

### Resources
| Resource | Purpose |
|----------|---------|
| Food | Fed and consumed each season. Famine = death. |
| Livestock | Breeds, caps at capacity, overflow → food. |
| Provisions | Building material, produced by work allocation. |
| Living Fire (Tree of Life) | The master variable. Decays naturally. Tended by fire-keepers. |

### Population Clans
- `bnei_brit_shem` (starts 4): Shem + wife + grows
- `bnei_brit_ham` (starts 2): Ham + wife + grows
- `bnei_brit_yephet` (starts 2): Japheth + wife + grows
- Growth: percentage-based, Autumn only (Shem 5%, Ham 7%, Japheth 5.5%)

### Birth Events (Torah-exact)
| Event | Year | Season | Child | Source |
|-------|------|--------|-------|--------|
| A14b | 0 | 3 | Canaan (Ham) | Sanhedrin 108b |
| R1.5 | 1 | 3 | Gomer (Japheth) | Gen 10:2 |
| R2.1b | 2 | 0 | Arpachshad (Shem) | Gen 11:10 |

---

## Design Decisions

### Fire is NOT a danger in the tutorial
Fire (Tree of Life) should not kill the player during Y0-7. There is too much unity and
holiness in this period. Food/famine is the correct and only killer. Fire danger is a
post-tutorial mechanic when the family fractures.

### Canaan reveal structure
Canaan is NOT mentioned before the biblical quote in A12. The tent scene diagnosis
REVEALS Canaan as a secret child. The only hint is A11's belly brush. Sequence:
A11 (belly brush) → A12 (Gen 9:25 drops "Canaan") → A13 (diagnosis over unborn) → A14b (birth).

### Shem/Ham character dynamic
- **Shem** = outward, wants to GO. Seed of Abraham. Fill the earth. Carry the chain into the world.
- **Ham** = centralizer, wants to STAY. Build deeper, build stronger. Warmth (חם). Sedentary.
- **Japheth** = tactical. Agrees with Shem about Shinar because two rivers = natural walls.
- Family does NOT split at end of tutorial. ALL go to Shinar together.

### Bnei Elohim theology (the game's chiddush)
- Clay from which God made Adam. 100k years of pre-Adamic humanity.
- Never ate from Tree of Knowledge → no covenant, no liability.
- Physically stronger (never left nature). No language like ours.
- God spared them because they were never bound.
- Pre-flood: captured daughters of Adam → fruit without covenant → Nephilim.
- Post-flood: hide the women (birth of tzniut) when discovered.
- Discovery must be GROUNDBREAKING for the player — it's novel theology.

### Population mechanic on Bnei Elohim discovery
When Bnei Elohim discovered (Y7), population awareness jumps to hundreds.
UI should eventually show Bnei Brit / Bnei Elohim separation. (Not yet implemented.)

---

## Autoplay Observations (3×20-run report, 2026-02-25)

### MECHANICS (20 strategies)
- Deaths: 11/20 (55%), all famine. Intentionally hard.
- Root decay FIXED: survivors average 2.7-7.5 (was universal 0)
  - Tutorial uses per-root decay rates (Star Watch 0.02, Living Tongue 0.01, etc.)
  - Sacrifice-heavy strategies maintain roots at 7.5
  - No-sacrifice penalty is the main late-game root decay driver
  - Root cascade only activates Y5+ (no cascade on Ararat with 8 souls)
- Fire never dangerous. Min 41%, max 100%. BY DESIGN for tutorial.
- Livestock overflow working (6 runs triggered it).
- Building feels optional (1 run survived with only 2 tents).

### NARRATIVE (20 runs + static analysis)
- Zero structural errors: no missing fields, orphan flags, duplicate IDs, or unknown ops.
- 60 total events. All flag chains intact.
- Static analysis clean: all advisors valid, all effects valid.

### UI & LANGUAGE (20 checks)
- Zero errors, zero forbidden words, zero modern words, zero consistency issues.
- Remaining observations (acceptable by design):
  - A12 choice "..." is intentional (tent scene shock)
  - 2 long choice labels (R7.0 81 chars, R7.1 82 chars) — borderline
  - Y0 density (17 events) — tutorial by design
  - 8 long narratives (>12 blocks) — pivotal moments

---

## Event Chain Summary

### Year 0 (ararat_year0.json): 17 events
A01 → A01b → A02 → A03 → A04 → A05 → A06 → A07 → A08 → A09 →
A10 → A11 (belly brush) → A12 (curse/quote) → A13 (diagnosis) →
A14 (mourning) → A14b (Canaan birth) → A15 (reckoning)

### Years 1-7 (ararat_years1_7.json): 43 events
**Narrative arc:**
Y1-3: Family establishes (loom, spring, births, granary, song)
Y3: The Footprint (first hint)
Y4: Cleared Ground + Other Hearth (deniability collapses)
Y5: Red Flowers (territorial boundary) + Wolf and Lamb
Y6: Mountain Sings + Wind + Shem's Absence + The Face (contact)
Y7: Hide Women → Noah's Teaching → The Scout → The Decision (all go to Shinar)

**Bnei Elohim suspense chain (5 beats):**
1. Y3S1 The Footprint — bigger feet, dismissed as Ham's
2. Y4S0 The Cleared Ground — stone circle, cold ash, Noah counting
3. Y4S3 The Other Hearth — niddah alibi collapses, fire without stones
4. Y5S2 The Red Flowers — deliberate boundary line
5. Y6S3 The Face — direct sighting, "the clay before the breath"

**Flag chain for Y7 climax:**
first_encounter_elohim → women_hidden → bnei_elohim_taught → scout_complete → tutorial_decision_made

### Post-tutorial events (milestone-based)
- M-HAM-20/40/60: Ham's settlement growing into Ir-Canaan
- R-DROUGHT, R-SICKNESS, R-WANDERERS, etc.: repeatable hazards

---

## Files Reference
| File | Purpose |
|------|---------|
| `data/events/ararat_year0.json` | Year 0 tutorial events |
| `data/events/ararat_years1_7.json` | Years 1-7 events |
| `scripts/autoloads/game_state.gd` | All game variables, flags, stats |
| `scripts/systems/season_resolver.gd` | Season tick: food, fire, livestock, growth |
| `scripts/systems/effect_resolver.gd` | Processes event effects (modify, set_flag, etc.) |
| `scripts/test/autoplay.gd` | 20-strategy headless test runner |
| `scripts/ui/allocation_screen.gd` | Worker allocation + forecast |
| `scripts/ui/season_summary.gd` | Post-season results display |
| `docs/DESIGN_BIBLE.md` | Theology, characters, language (from Notion) |
| `docs/DESIGN_NOTES.md` | This file |
