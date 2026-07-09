# Six-Stage Content Phase 5 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` to implement and review this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Continue the approved total plan with Phase 5: replace temporary stage fallbacks with complete six-stage wave, midboss, and boss content using stable content data and runtime routing.

**Architecture:** Keep this phase focused on playable six-stage content. Do not generate/import the hand-painted asset library, expand music production, or perform final all-phase balance QA here. Add a focused stage content database and a small StageDirector runtime helper, then wire `scripts/main.gd` to consume stage data for wave spawning and boss card loading.

**Tech Stack:** Godot 4.7 GDScript, headless SceneTree tests under `tests/`, existing single-scene gameplay loop, existing `GameDatabase`, `AssetRegistry`, `AudioManager`, and Phase 4 enemy/item/bullet systems.

## Global Constraints

- Original total spec file: `docs/superpowers/specs/2026-07-09-touhou-full-production-design.md`.
- This is Phase 5 only: six-stage wave and boss content pass using stable final asset registry paths.
- Do not generate/import final AI art assets in this phase; Phase 6 owns the full art asset generation/import pipeline.
- Do not create or use existing Touhou Project characters, music, names, or art.
- Preserve 720x960 viewport, title/character/shot flow, settings, pause, restart-stage, protagonist shots/bombs, and Phase 4 data systems.
- Remove the Phase 1 fallback behavior for stages 4-6. Every stage must have explicit controller data, wave schedule, midboss metadata, and boss metadata.
- Stage bosses:
  - Stages 1-4: one nonspell and three spell cards.
  - Stages 5-6: two nonspells and four spell cards.
- Midbosses: each stage has one nonspell and one short spell card in metadata.
- Spell/card names must be Chinese-first display strings.
- Stage curve:
  - Stage 1: basic dodging, collection, and first spell patterns.
  - Stage 2: horizontal pressure and object bullets.
  - Stage 3: delayed attacks, mist routes, and memory checks.
  - Stage 4: speed increase, wind motifs, and aimed pressure.
  - Stage 5: resource pressure, rhythm bullets, and large-orb control.
  - Stage 6: comprehensive test with dense but readable final patterns.

---

## File Structure

- `scripts/data/stage_content_database.gd`: source of truth for stage controller data, wave schedules, midboss metadata, and boss card metadata.
- `scripts/runtime/stage_director.gd`: pure helper that validates/returns stage config and due wave events.
- `scripts/main.gd`: integration only: load stage controllers, execute due wave events, load boss cards from stage content, dispatch new boss pattern aliases.
- `tests/assert_phase5_stage_content_database.gd`: data schema, counts, curve identity, and Chinese-first card contracts.
- `tests/assert_phase5_stage_director.gd`: StageDirector routing and no-fallback wave timing contract.
- `tests/assert_phase5_main_stage_routing.gd`: main-loop integration for stages 1-6, especially stages 4-6.
- `tests/assert_viewport_config.gd`: update the old fallback regression to require explicit stage content.

---

### Task 1: Stage Content Database Contracts

**Files:**
- Create: `tests/assert_phase5_stage_content_database.gd`
- Create: `scripts/data/stage_content_database.gd`

**Interfaces:**
- Produces:
  - `StageContentDatabase.stage_count() -> int`
  - `StageContentDatabase.stage_config(stage_index: int) -> Dictionary`
  - `StageContentDatabase.wave_schedule(stage_index: int) -> Array`
  - `StageContentDatabase.midboss_definition(stage_index: int) -> Dictionary`
  - `StageContentDatabase.boss_definition(stage_index: int) -> Dictionary`
  - `StageContentDatabase.boss_cards(stage_index: int) -> Array`
  - `StageContentDatabase.pattern_aliases() -> Dictionary`

- [ ] Write failing test for six explicit stage configs, stage ids, boss times, non-empty wave schedules, stage curve tags, Chinese-first midboss/boss cards, and exact boss card counts.
- [ ] Add `stage_content_database.gd` with six stage entries and no fallback-generated stage content.
- [ ] Add wave schedules with authored event dictionaries shaped for main integration:
  - `time`, `x`, `y`, `hp`, `pattern`, `move`, `vx`, `vy`, `move_data`, `strong`.
  - Optional `repeat`, `spacing_x`, `spacing_y`, and `variants` for compact groups.
- [ ] Add boss metadata using existing runtime bullet pattern ids plus aliases for new stage themes.
- [ ] Run `assert_phase5_stage_content_database.gd` and `assert_game_database.gd`.
- [ ] Commit: `feat: add phase 5 stage content database`.

---

### Task 2: StageDirector Runtime Helper

**Files:**
- Create: `tests/assert_phase5_stage_director.gd`
- Create: `scripts/runtime/stage_director.gd`

**Interfaces:**
- Consumes: `StageContentDatabase`.
- Produces:
  - `StageDirector.stage_controller(stage_index: int) -> Dictionary`
  - `StageDirector.due_wave_events(stage_index: int, timer: int, triggered: Dictionary) -> Array`
  - `StageDirector.boss_cards(stage_index: int) -> Array`
  - `StageDirector.boss_definition(stage_index: int) -> Dictionary`
  - `StageDirector.midboss_definition(stage_index: int) -> Dictionary`

- [ ] Write failing tests proving StageDirector returns explicit controllers for stages 1-6, rejects invalid stage indexes with `{}`, exposes no `fallback_from`, and emits each wave event once.
- [ ] Implement StageDirector as a small pure helper that duplicates returned data.
- [ ] Ensure `due_wave_events()` expands compact repeated events into spawn-ready dictionaries without mutating the source schedule.
- [ ] Run `assert_phase5_stage_director.gd` and `assert_phase5_stage_content_database.gd`.
- [ ] Commit: `feat: add stage director for six-stage content`.

---

### Task 3: Main Stage Wave Routing

**Files:**
- Create: `tests/assert_phase5_main_stage_routing.gd`
- Modify: `scripts/main.gd`
- Modify: `tests/assert_viewport_config.gd`

**Interfaces:**
- Consumes: `StageDirector.stage_controller()` and `StageDirector.due_wave_events()`.
- Produces:
  - `scripts/main.gd` owns one `stage_director` helper instance.
  - `_load_stage(stage)` loads explicit data for all six stages.
  - `_stage_waves(timer)` uses due events from `stage_controller.waves`.
  - `_spawn_stage_wave_event(event)` maps event data to `_spawn_enemy(...)`.

- [ ] Write failing main routing test: stages 1-6 load explicit `stage_id`, `curve_tag`, `boss_time`, `waves`, and `boss_spawned`; stages 4-6 must not have `fallback_from`.
- [ ] Add a focused test that calls `_stage_waves()` on representative stage 4, 5, and 6 event times and confirms enemy patterns/strong flags reflect wind, rhythm, and final-density content.
- [ ] Replace `_load_stage()` fallback match with StageDirector-loaded controller data.
- [ ] Replace `_stage_waves()` fallback branching with data-driven wave event execution.
- [ ] Keep legacy `_waves_s1/_waves_s2/_waves_s3` helpers only if temporary compatibility requires them; they must no longer be called for stage routing.
- [ ] Update `assert_viewport_config.gd` from "fallback exists" to "explicit stage content exists".
- [ ] Run `assert_phase5_main_stage_routing.gd`, `assert_viewport_config.gd`, and Phase 4 main integration tests.
- [ ] Commit: `feat: route stages through phase 5 content data`.

---

### Task 4: Boss And Midboss Content Routing

**Files:**
- Modify: `tests/assert_phase5_main_stage_routing.gd`
- Modify: `scripts/main.gd`

**Interfaces:**
- Consumes: `StageDirector.boss_cards(stage_index)` and `StageContentDatabase.pattern_aliases()`.
- Produces:
  - `_load_boss_cards()` loads all stages from StageDirector.
  - Boss card dictionaries include metadata keys: `name`, `hp`, `time`, `pattern`, `kind`, `stage_index`, `boss_id`.
  - `_boss_fire_pattern()` dispatches all Phase 5 pattern aliases to existing compact bullet functions.

- [ ] Extend tests to assert main `_load_boss_cards()` gives stages 1-4 exactly four boss cards and stages 5-6 exactly six boss cards.
- [ ] Assert every boss card has Chinese-first `name`, valid `kind` (`nonspell` or `spell`), positive `hp`, positive `time`, and recognized `pattern`.
- [ ] Wire `_load_boss_cards()` to StageDirector; remove Stage 4-6 fallback card reuse.
- [ ] Add boss pattern aliases for wind, rhythm, large-orb, and final dense patterns by mapping to existing boss bullet implementations or new compact wrappers.
- [ ] Apply existing stage boss HP multiplier when cards are loaded, without changing the authored base HP metadata.
- [ ] Run `assert_phase5_main_stage_routing.gd`, `assert_viewport_config.gd`, and boss/main regression tests.
- [ ] Commit: `feat: load six-stage boss card content`.

---

### Task 5: Phase 5 Verification And Integration

**Files:**
- Modify this plan file only if checkboxes are updated by the controller.

- [ ] Run full focused verification:
  - `assert_viewport_config.gd`
  - `assert_game_database.gd`
  - `assert_asset_registry.gd`
  - `assert_bullet_manager.gd`
  - `assert_performance_monitor.gd`
  - `assert_ui_shell_model.gd`
  - `assert_pause_contract.gd`
  - `assert_phase2_settings_effects.gd`
  - `assert_phase3_protagonist_profiles.gd`
  - `assert_phase3_shot_patterns.gd`
  - `assert_phase3_bomb_contract.gd`
  - `assert_phase3_ui_loadout_contract.gd`
  - `assert_phase4_data_systems.gd`
  - `assert_phase4_enemy_pattern_executor.gd`
  - `assert_phase4_item_reward_system.gd`
  - `assert_phase4_main_data_integration.gd`
  - `assert_phase5_stage_content_database.gd`
  - `assert_phase5_stage_director.gd`
  - `assert_phase5_main_stage_routing.gd`
  - `res://scenes/main.tscn` smoke with `--quit-after 5`
- [ ] Run `git diff --check`.
- [ ] Check `git status -sb` and `git ls-files .superpowers`; `.superpowers` must remain untracked.
- [ ] Use `superpowers:requesting-code-review` final whole-branch review. Fix Critical/Important findings.
- [ ] Merge to `master` and push to `origin/master` as already requested by the user:
  - `git switch master`
  - `git merge --ff-only feature/six-stage-content-phase5`
  - `git push origin master`

---

## Self-Review

- Spec coverage: This plan covers approved Phase 5: complete six-stage wave and boss content routing with no Phase 1 fallback.
- Out of scope by design: full hand-painted art generation/import remains Phase 6, music/SFX expansion remains Phase 7, and final balance/practice/final QA remains Phase 8.
- Risk management: main gameplay changes are integration-only and backed by pure data/helper tests before scene tests.
- Placeholder scan: no unresolved placeholder markers or unspecified test command remains.
