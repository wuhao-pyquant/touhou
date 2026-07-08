# Touhou Full Production Design

## Purpose

Upgrade the current Godot 4.7 prototype into a complete original Japanese-style danmaku shooting game. The game targets a high-end Windows PC baseline, uses a 720x960 internal viewport, and aims for stable 60 FPS with dense bullet patterns, full hand-painted production assets, and a complete six-stage story mode.

The existing project is a compact single-scene prototype with most gameplay in `scripts/main.gd`. It already has basic player shooting, enemy waves, boss cards, bombs, BGM/SFX, and a minimal title/pause state. The production version should keep the responsive danmaku feel but move away from the single-file procedural-art structure toward data-driven gameplay and a formal asset pipeline.

## Confirmed Direction

- Theme: original Japanese Touhou-style fantasy, not using existing Touhou Project characters, names, art, music, or other protected assets.
- Core incident: "Hyakki Night Festival Incident", an endless yokai night festival that refuses to end.
- Visual quality: full hand-painted production grade for characters, enemies, items, bomb effects, UI key art, and layered backgrounds.
- Asset format: PNG atlases, spritesheets, layered backgrounds, and limited shader effects.
- Music direction: Japanese festival instrumentation plus electronic rock.
- Game size: three playable protagonists, six stages, twelve major opponents.
- Difficulty baseline: standard Touhou-style Normal, route-learning required but fair.
- Technical target: 720x960 internal viewport, high-density bullets, high-quality 2D art, stable 60 FPS on AMD 5800X + RTX 3070 + 64 GB RAM.

## Overall Scope

The full production version includes:

- Three original playable protagonists: shrine maiden, magician, and half-yokai swordswoman.
- Two fixed shot types per protagonist, selected before starting a run.
- One dedicated bomb per protagonist.
- Six full stages:
  1. Shrine Approach
  2. Yokai Market
  3. Mist Bamboo Grove
  4. Tengu Mountain Path
  5. Oni Banquet Hall
  6. Night Festival Divine Realm
- One midboss and one stage boss per stage, for twelve major opponents.
- Short story scenes before and after stages, boss-entry dialogue, and one ending per protagonist.
- Complete menu flow: title screen, start game, character select, shot type select, practice mode, settings, pause menu, results, game over, all clear.
- Formal gameplay systems for enemies, bullets, bosses, items, scoring, bombs, resources, and practice unlocks.

## World And Story

Every hundred years, the yokai of the region hold the Hyakki Night Festival, a ritual celebration that temporarily softens the boundary between humans, yokai, tools, spirits, and gods. This year the festival does not end. The night is fixed in place, lantern paths keep reappearing, human settlements begin to obey festival rules, and ordinary tools awaken as if the celebration has become a new law of nature.

The protagonists investigate from different starting points:

- Shrine maiden: protects the shrine boundary and investigates why the festival has overridden local rites.
- Magician: pursues the abnormal magical density and the source of the endless lantern energy.
- Half-yokai swordswoman: tracks the disturbance through yokai territories and tests whether the festival is a threat or a challenge.

The final reveal is that the festival itself is being elevated into a godlike existence through accumulated excitement, belief, memory, and yokai power. The final boss does not simply want destruction; she wants humans and yokai to live forever inside a boundary of celebration, performance, rivalry, and night.

## Stage And Boss Structure

### Stage 1: Shrine Approach

Mood: bright, welcoming, and readable. The festival seems harmless.

Visuals: lantern rows, shrine steps, paper charms, low-level spirits, torii silhouettes.

Gameplay role: tutorial-level density with clear aimed shots, small rings, and basic collection routes.

Midboss: lantern tsukumogami girl.

Stage boss: festival guide fox.

Story beat: the protagonists learn that the lantern path is rearranging itself and guiding visitors deeper into the festival.

### Stage 2: Yokai Market

Mood: lively but unstable. Market goods and tools begin turning into bullet patterns.

Visuals: stalls, banners, coins, abacuses, masks, food smoke, awakened tools.

Gameplay role: horizontal pressure, item-themed bullets, denser enemy formations.

Midboss: abacus tsukumogami.

Stage boss: oni-market merchant leader.

Story beat: the market has stopped trading goods and now trades memories, names, and festival permissions.

### Stage 3: Mist Bamboo Grove

Mood: disorienting and dreamlike. Festival paths loop through fog and bamboo.

Visuals: bamboo layers, mist curtains, dim lanterns, false path markers, moonlit silhouettes.

Gameplay role: delayed bullets, mist-veiled waves, route memory, misdirection without unfair invisibility.

Midboss: lost rabbit yokai.

Stage boss: bamboo-grove illusionist.

Story beat: the festival is no longer just a place. It edits direction and time.

### Stage 4: Tengu Mountain Path

Mood: fast, windy, and investigative. Tengu try to report the incident but become bound by festival rules.

Visuals: mountain path, storm ribbons, news sheets, feathers, wind trails, high-altitude lanterns.

Gameplay role: faster bullets, wind-blade patterns, aimed shots combined with lane pressure.

Midboss: rookie crow tengu reporter.

Stage boss: mountain wind tengu.

Story beat: the protagonists discover that information about the incident is being rewritten as entertainment.

### Stage 5: Oni Banquet Hall

Mood: dangerous celebration. The festival's source is near an oni banquet.

Visuals: giant drums, sake bowls, red lanterns, wooden banquet halls, oni silhouettes, rhythmic fire.

Gameplay role: resource pressure, large-orb space control, rhythm bullets, higher midboss and boss intensity.

Midboss: little oni drummer.

Stage boss: drunken banquet oni princess.

Story beat: the oni are not the masterminds. Their banquet energy is feeding something beyond them.

### Stage 6: Night Festival Divine Realm

Mood: sacred, overwhelming, and theatrical. The festival has become a divine domain.

Visuals: floating torii, endless lantern rivers, broken sky, faith particles, spirit fire, shrine-stage architecture.

Gameplay role: final synthesis of aimed shots, rings, delayed waves, lasers, large-orb control, and high-density spell cards.

Midboss: fox shrine maiden elevated by the festival.

Final boss: god of the Hyakki Night Festival.

Story beat: the protagonists confront the new festival deity and force the night to return to being a festival rather than a prison.

## Protagonists

The first production version has three protagonists. Each has two shot types selected before the run and one dedicated bomb.

### Shrine Maiden

Role: balanced, forgiving, strong tracking, stable bomb.

Shot Type A: tracking paper talismans.

- Lower single-shot damage.
- High coverage and strong safety.
- Good for learning stages and handling uneven enemy placement.

Shot Type B: focused yin-yang orb shot.

- Higher forward damage.
- Better boss DPS.
- Requires stronger positioning.

Bomb: Great Boundary Bloom.

- Clears nearby enemy bullets immediately.
- Expands a boundary field for sustained protection.
- Temporarily weakens boss bullet density or clears incoming waves on pulses.
- Works with both tracking and focused shots.

### Magician

Role: high damage, direct fire, resource burst.

Shot Type A: star-dust spread.

- Wide coverage.
- Stronger at closer range.
- Good at clearing stage waves but less precise against bosses.

Shot Type B: magic laser.

- Very high forward DPS.
- Strong against bosses.
- Weaker against side lanes and mixed waves.

Bomb: Festival Master Spark.

- Short, high-damage forward blast.
- Clears a direct lane through enemy bullets.
- Strongest damage bomb, but more directional than the shrine maiden bomb.

### Half-Yokai Swordswoman

Role: mobility, mid-range pressure, high-risk reward.

Shot Type A: sword-wave fan.

- Forward medium-range coverage.
- Strong against stage waves.
- Good when sweeping lanes.

Shot Type B: returning spirit blades.

- Blades orbit, launch, and return.
- Rewards close and mid-range boss positioning.
- Strong when routed, weaker when played passively.

Bomb: Instant Slash Boundary.

- Brief invincibility.
- Multi-hit slashes along the movement direction.
- Clears a path rather than the entire screen.
- Supports aggressive survival and high-pressure routing.

## Enemy And Bullet Design

Regular enemies use five behavior families:

- Low yokai: simple entry paths, light aimed shots, tutorial patterns.
- Fast attackers: quick lane entries, short-lived pressure, route checks.
- Formation shooters: synchronized patterns, rings, spreads, walls.
- Elite yokai: more HP, richer bullet patterns, stronger drops.
- Mechanism enemies: stage-specific behavior such as delayed shots, wind pushes, rhythm pulses, or object bullets.

Enemy families are visually reskinned per stage while preserving behavior clarity. Stage 2 uses tool and market motifs, Stage 4 uses wind and paper motifs, Stage 5 uses drums and oni fire motifs, and Stage 6 uses divine lantern and faith motifs.

Enemy bullet families:

- Circle bullets: baseline pressure and rings.
- Rice bullets: woven paths and flowing curves.
- Butterfly bullets: decorative spread and boss identity.
- Needle bullets: fast aimed pressure.
- Talisman bullets: shrine and spell-card motifs.
- Star bullets: magical spread and celebratory patterns.
- Lasers: warning-line attacks and lane denial.
- Large orbs: slow space control and final-stage pressure.

Visual rules:

- Enemy bullets and player bullets must never share confusing color language.
- Dangerous bullets need readable centers and consistent collision radius.
- Dense attacks should prefer layered readable patterns over random bullet noise.
- Lasers require warning telegraphs before active collision.
- Large orbs should move slowly enough to leave fair route choices.

## Boss And Spell Card Structure

Stage bosses:

- Stages 1-4: one nonspell and three spell cards.
- Stages 5-6: two nonspells and four spell cards.

Midbosses:

- One nonspell and one short spell card.

Boss state flow:

1. Entry animation.
2. Dialogue or spell announcement.
3. Nonspell or spell active.
4. Clear, timeout, or transition.
5. Defeat animation and stage transition.

Spell names use Chinese-first display with optional Japanese-style flavor terms. They should express story and attack identity rather than only abstract pattern names.

## Items, Resources, And Scoring

The weapon-switch item system is removed from core gameplay because shot type is selected before a run. Drops become a standard danmaku resource loop:

- Small power: raises or maintains shot power.
- Point item: score value depends on collection height or point-of-collection state.
- Bomb fragment: three fragments form one bomb.
- Life fragment: five fragments form one life.
- Night Festival Seal: high-risk score multiplier or spell-card bonus resource.
- Full power item: rare recovery item after death or scripted moments.

Scoring goals:

- Encourage top-of-screen collection without forcing unsafe play every wave.
- Reward no-miss and no-bomb spell card clears.
- Preserve graze as a visible skill reward.
- Use Night Festival Seals as a stage-specific high-risk bonus that reinforces the setting.

## Difficulty And Balance

The baseline is standard Touhou-style Normal.

Target experience:

- New players can learn and clear the first three stages with practice.
- Experienced players can clear all six stages after route learning.
- Deaths should feel traceable to positioning, routing, or resource choices.
- Randomness may add texture but must not decide survival.

Stage curve:

- Stage 1: basic dodging, collection, and first spell patterns.
- Stage 2: horizontal pressure and object bullets.
- Stage 3: delayed attacks, mist routes, and memory checks.
- Stage 4: speed increase, wind motifs, and aimed pressure.
- Stage 5: resource pressure, rhythm bullets, and large-orb control.
- Stage 6: comprehensive test with dense but readable final patterns.

Resource balance:

- Early stages give enough bomb fragments to teach bomb usage.
- Later stages make bombs valuable but not mandatory for every hard pattern.
- Boss HP and timer values must account for all six protagonist shot types.
- The magician's focused laser should not trivialize bosses, and the swordswoman's high-risk options should not become mandatory for score routing.

## Art Asset Library

All production assets target full hand-painted quality. Runtime integration uses PNG atlases, spritesheets, layered backgrounds, and limited shader effects.

Asset categories:

- Protagonist portraits and ending art.
- Protagonist battle sprites and animation frames.
- Protagonist shots, focus effects, hitbox indicators, and bomb effects.
- Twelve boss portraits, expression variants, battle sprites, entry effects, defeat effects, and spell-card backgrounds.
- Thirty regular enemy sets or strong variants, five behavior families across six stages.
- Eight enemy bullet families with four to six color and size variants each.
- Player bullet atlas for six shot types.
- Item icons for power, point, bomb fragment, life fragment, Night Festival Seal, and full power.
- Six layered stage backgrounds, each with far, mid, foreground, fog or particles, and stage-specific animated elements.
- UI assets for title, menus, character select, settings, HUD, spell-card announcement, pause, results, game over, and all clear.
- Effects for graze, hit, clear, bomb, spell transition, boss aura, stage transition, and item collection.

Asset naming must be stable and descriptive. Code should reference assets through an asset registry rather than hard-coded scattered paths.

## Music And SFX

The soundtrack has twelve main tracks:

- One stage theme per stage.
- One boss theme per stage.

Style:

- Japanese festival instruments such as taiko, flute, shamisen-like plucks, koto-like accents, and chant-like motifs.
- Electronic rock structure with drums, bass, synth lead, fast melodic lines, and stronger boss intensity.
- Stage tracks escalate from festive and playful to sacred and dangerous.
- Boss tracks use higher BPM, stronger drums, sharper leads, and more aggressive harmonic motion.

SFX library:

- Player shot variants.
- Enemy hit and boss hit.
- Enemy defeat and boss phase clear.
- Graze.
- Item collection.
- Bomb start, bomb loop, and bomb finish.
- Menu navigation and selection.
- Spell-card announcement.
- Laser warning.
- Life and bomb gain.
- Player hit and deathbomb window.

Audio should be managed centrally and preloaded or cached to avoid transition hitches.

## Technical Architecture

The current single-file prototype should be split into focused systems.

Proposed modules:

- `GameManager`: global state, selected protagonist, selected shot type, difficulty, score, lives, bombs, graze, resources, and high-level game state.
- `StageDirector`: stage configuration, wave script loading, background configuration, boss routing, BGM routing, and stage clear flow.
- `PlayerController`: movement, focus mode, shot logic, bomb logic, deathbomb, invincibility, and protagonist-specific data.
- `BulletManager`: enemy bullet pool, player bullet pool, movement, lifetimes, collision metadata, draw grouping, and clear operations.
- `EnemyManager`: regular enemy spawning, movement, shooting, HP, death handling, and drop spawning.
- `BossController`: boss state machine, nonspell and spell-card sequencing, HP/timer, declarations, transitions, and defeat.
- `ItemManager`: item spawning, floating, fall movement, collection, top collection line, fragments, and scoring.
- `AssetRegistry`: centralized atlas, sprite, background, audio, shader, and UI asset paths.
- `UIManager`: title screen, character select, practice mode, settings, pause menu, HUD, results, game over, and all clear.

Data-driven content:

- Protagonists and shot types should be configured as data resources or dictionaries with stable schema.
- Stage waves should move out of raw code branches into stage data files or focused stage scripts.
- Boss spell definitions should separate metadata from execution functions.
- Bullet visual definitions should be shared across gameplay and rendering.

## Performance Design

The target machine is high end, but the game should still avoid waste. Godot 2D bullet hell performance is most likely to bottleneck on CPU-side data structures, per-bullet draw overhead, and collision checks rather than raw GPU capacity.

Required performance changes:

- Replace bullet dictionaries on hot paths with array-backed structures, typed arrays, or lightweight pooled objects.
- Keep enemy bullets, player bullets, items, enemies, and particles pooled.
- Group bullet rendering by texture/material/color class.
- Use MultiMeshInstance2D, batched CanvasItem drawing, or equivalent grouped rendering instead of one node per bullet.
- Use spatial grid or partitioned collision checks.
- Check player collision only against nearby enemy bullets.
- Check enemy and boss collision only against relevant player bullet partitions.
- Avoid repeated allocation in `_process`.
- Avoid loading or creating resources during active gameplay.
- Keep background art layered but not node-heavy.
- Add a debug performance HUD with FPS, active enemy bullets, active player bullets, active enemies, item count, particle count, and draw group count.

Performance goal:

- 720x960 internal viewport.
- Stable 60 FPS on AMD 5800X + RTX 3070 + 64 GB RAM.
- High-density boss patterns without visible stutter.
- Bombs and spell-card transitions should not create one-frame hitches.

## User Interface

Title screen:

- Full hand-painted night festival shrine key art.
- Three protagonist silhouettes or portraits.
- Menu entries: Start Game, Practice, Settings, Exit.

Character select:

- Three protagonists.
- Type A and Type B shot selection per protagonist.
- Displays speed, shot coverage, focused damage, bomb behavior, and difficulty hints.

HUD:

- Score, graze, power, lives, bombs, fragments, stage name, boss HP, spell timer, and active spell name.
- Must fit 720x960 without overlapping the playfield.
- Bullet brightness and player hitbox readability are more important than decorative HUD density.

Pause:

- Esc pauses gameplay logic and timers.
- Screen darkens while preserving current bullet state visually.
- Menu entries: Continue, Restart Stage, Settings, Return To Main Menu, Exit Game.
- Music volume lowers or applies a simple pause filter.
- Resuming a boss spell must not reset random seed, timer, or bullet state.

Settings:

- Master, BGM, and SFX volume.
- Windowed/fullscreen.
- Bullet brightness.
- Always show focus hitbox.
- Performance HUD toggle.
- Optional input guide.

Practice:

- At minimum, data model and menu path exist in the first production architecture.
- Stage practice can unlock after reaching or clearing stages.
- Spell practice can be a later expansion if needed.

## Implementation Strategy

This design is too large for one implementation plan. It should be split into sequential implementation specs and plans:

1. Architecture and performance foundation.
2. 720x960 viewport, UI shell, title, pause, settings, and character select.
3. Protagonist system with three characters, six shot types, and three bombs.
4. Bullet, enemy, item, and scoring data systems.
5. Six-stage wave and boss content pass using stable final asset registry paths.
6. Full art asset generation and import pipeline.
7. Music and SFX expansion to twelve BGM tracks and full SFX set.
8. Balance, polish, practice mode, and final QA.

Each implementation plan must produce a playable and testable milestone. The first plan should not try to generate all art and all six stages before the architecture is ready.

## Non-Goals For The First Production Pass

- No use of existing Touhou Project characters, music, names, or art.
- No online leaderboard.
- No replay system unless added as a later plan.
- No mobile or web export target.
- No full visual-novel branching routes.
- No per-stage long cutscenes.
- No multiplayer.

## Verification Expectations

Every milestone should include:

- Godot headless scene parse/start check.
- Manual play check for title, character select, stage flow, pause, and boss transition.
- Performance check with debug HUD under dense bullet scenarios.
- Asset load check to catch missing paths and oversized textures.
- Regression check that pausing, restarting, and returning to title do not corrupt game state.

Because the current directory is not a Git repository, this design document cannot be committed from this workspace.
