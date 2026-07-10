# Phase 6 Art Production Implementation Plan

> **For implementers:** REQUIRED SKILLS: `superpowers:executing-plans`, `superpowers:subagent-driven-development`, `superpowers:test-driven-development`, `superpowers:verification-before-completion`, and `imagegen` for asset creation batches.

## Objective

Complete Phase 6 of the original Superpowers project plan by producing and integrating a coherent, production-grade, hand-painted visual asset library for the Godot danmaku game.

The approved direction is **Style B: style lock plus batched full production**. The asset style must be close to hand-painted game illustration quality, unified across protagonists, enemies, bosses, bullets, bombs, items, backgrounds, UI, and review composites.

## Binding Execution Standard

Every implementation step must obey this gameplay-first art standard:

1. **Art serves gameplay.** Reject or revise any asset that reduces bullet readability, player hitbox clarity, enemy recognition, item recognition, UI clarity, or boss attack legibility.
2. **Dense-play readability is mandatory.** Assets must remain distinguishable in 720x960 gameplay-like composites with many enemy bullets, player shots, items, enemies, spell effects, and background layers visible together.
3. **Backgrounds stay behind gameplay.** Background layers must not contain bullet-like dots, high-contrast moving foreground clutter, or shapes that can be confused with bullets, drops, enemies, or the player.
4. **Bullets keep visual contracts.** Bullet families must preserve readable centers, collision expectation, silhouette identity, color-family identity, and safe contrast against all six stage backgrounds.
5. **Items cannot look hostile.** Core drops must look collectible and must not mimic bullet shape, bullet color priority, or enemy projectile glow.
6. **Bombs are spectacular but readable.** Bomb visuals must clearly read as player-owned, briefly suppress visual noise where intended, and must not hide dangerous live bullets outside the game’s designed clear window.
7. **Sprites cannot hide hazards.** Player, enemy, and boss sprites must not contain small bullet-like ornaments near gameplay scale. Boss silhouettes must stay readable without covering dense projectile patterns.
8. **UI respects danger zones.** Pause overlays, spell-card banners, and menu visuals must not obscure the player hitbox or active danger area during live gameplay.
9. **QA uses composites, not isolated beauty shots.** An asset is accepted only after contact-sheet review and at least one gameplay-like composite check against the relevant background and projectile density.

## Current Baseline

- Branch: `feature/art-production-phase6`
- Phase 6 spec commit: `165786c docs: define phase 6 art production standard`
- Phase 6 spec: `docs/superpowers/specs/2026-07-09-phase6-art-production-design.md`
- Prior integrated baseline: Phase 5 merged and pushed on `master` at `041e002382dc1264477e6b2a9aebdca5ba9eaf83`
- Do not track `.superpowers/`.

## Target File Layout

Create or update these paths:

```text
docs/art/style_bible.md
docs/art/phase6_asset_prompts.md
docs/art/review/phase6_style_reference.png
docs/art/review/phase6_protagonists_contact_sheet.png
docs/art/review/phase6_bosses_contact_sheet.png
docs/art/review/phase6_backgrounds_contact_sheet.png
docs/art/review/phase6_gameplay_readability_composite.png
docs/art/review/phase6_asset_acceptance.md

assets/manifest/phase6_asset_manifest.json
assets/source/phase6/style/
assets/source/phase6/protagonists/
assets/source/phase6/bosses/
assets/source/phase6/backgrounds/
assets/source/phase6/enemies/
assets/source/phase6/bullets/
assets/source/phase6/bombs/
assets/source/phase6/items/
assets/source/phase6/ui/

assets/characters/protagonists/
assets/characters/bosses/
assets/characters/enemies/
assets/backgrounds/stage_01/
assets/backgrounds/stage_02/
assets/backgrounds/stage_03/
assets/backgrounds/stage_04/
assets/backgrounds/stage_05/
assets/backgrounds/stage_06/
assets/effects/bullets/
assets/effects/bombs/
assets/items/
assets/ui/

tools/art/phase6_asset_manifest_builder.py
tools/art/phase6_validate_assets.py
tools/art/phase6_contact_sheet.py

tests/assert_phase6_style_contract.gd
tests/assert_phase6_asset_manifest.gd
tests/assert_phase6_asset_files.gd
tests/assert_phase6_asset_registry.gd
```

## Asset Manifest Contract

The manifest is the source of truth for Phase 6 asset generation, validation, and contact sheets. Each entry must include:

```json
{
  "id": "stage_01_background_far",
  "category": "background",
  "stage": 1,
  "role": "far_layer",
  "final_path": "res://assets/backgrounds/stage_01/far.png",
  "source_path": "res://assets/source/phase6/backgrounds/stage_01_far_source.png",
  "width": 720,
  "height": 960,
  "transparent": false,
  "readability_role": "low-contrast atmospheric backdrop; cannot contain bullet-like dots",
  "palette": ["#152033", "#31545f", "#d2c487"],
  "status": "pending_generation",
  "prompt_id": "stage_01_background_far"
}
```

Allowed `status` values:

- `pending_generation`
- `generated_needs_review`
- `accepted`
- `rejected`

The final Phase 6 state must have all required production entries marked `accepted`.

## Required Asset Inventory

Create at least these production assets:

| Category | Count | Final dimensions | Notes |
| --- | ---: | --- | --- |
| Style reference | 1 | 1536x1024 or larger | Drives all prompts and review |
| Protagonist gameplay sprites | 3 | 384x384 transparent | One per playable character |
| Protagonist portraits | 3 | 512x768 transparent or clean alpha | Menu/dialogue use |
| Protagonist focus/option effect sheets | 3 | 512x512 transparent | Player-owned visual language |
| Boss gameplay sprites | 12 | 512x512 transparent | Two bosses per stage, stage-themed |
| Boss portraits | 12 | 768x1024 transparent or clean alpha | Story/spell-card use |
| Boss spell aura sheets | 12 | 720x720 transparent | Spectacular but bullet-readable |
| Stage backgrounds | 24 | 720x960 | Four layers per six stages: far, mid, near, spell |
| Enemy family sprites | 8 | 256x256 transparent | Distinct silhouettes and non-bullet ornaments |
| Enemy bullet families | 12 | 128x128 transparent | Clear centers and silhouettes |
| Player bullet families | 6 | 128x128 transparent | Player-owned color language |
| Bomb effect plates | 9 | 720x960 transparent | Three bombs, three plates each |
| Item/drop icons | 8 | 128x128 transparent | Collectible silhouette, not bullet-like |
| UI/key art | 8 | mixed | Title, pause, spell banner, menu frame, icons |

## Style Bible Requirements

Create `docs/art/style_bible.md` with these exact sections:

```markdown
# Touhou-Inspired Original Danmaku Art Bible

## Project Identity
## Style Pillars
## Original-IP Rules
## Gameplay Readability Contract
## Shape Language
## Color Language
## Bullet And Bomb Readability
## Character Rendering Standard
## Enemy And Boss Rendering Standard
## Background Rendering Standard
## UI Rendering Standard
## Stage Palettes
## Prompt Negative Constraints
## Acceptance Checklist
```

`Gameplay Readability Contract` must include the nine binding execution standards from this plan.

## Prompt Matrix Requirements

Create `docs/art/phase6_asset_prompts.md` with one prompt block per manifest `prompt_id`. Each block must include:

```markdown
## stage_01_background_far

- Target: `res://assets/backgrounds/stage_01/far.png`
- Gameplay role: low-contrast far background
- Positive prompt: ...
- Negative prompt: ...
- Readability constraints: ...
- Review composite: stage_01 dense bullet sample
```

Every negative prompt must include:

```text
no copyrighted Touhou character, no existing franchise character, no bullet-like background dots, no UI text baked into gameplay art, no unreadable dark-on-dark silhouette, no low-resolution pixel art, no muddy blur, no heavy bloom hiding projectile centers
```

## Task 1: Style Bible And Prompt Matrix

**Files**

- Add `docs/art/style_bible.md`
- Add `docs/art/phase6_asset_prompts.md`
- Add `tests/assert_phase6_style_contract.gd`

**Test first**

Create `tests/assert_phase6_style_contract.gd`:

```gdscript
extends SceneTree

func _init() -> void:
	var bible := FileAccess.get_file_as_string("res://docs/art/style_bible.md")
	assert(bible.contains("## Gameplay Readability Contract"))
	assert(bible.contains("Art serves gameplay"))
	assert(bible.contains("Dense-play readability is mandatory"))
	assert(bible.contains("no copyrighted Touhou character"))
	assert(bible.contains("no bullet-like background dots"))

	var prompts := FileAccess.get_file_as_string("res://docs/art/phase6_asset_prompts.md")
	assert(prompts.contains("## stage_01_background_far"))
	assert(prompts.contains("## protagonist_mika_gameplay_sprite"))
	assert(prompts.contains("## boss_06b_spell_aura"))
	assert(prompts.contains("Readability constraints"))
	quit(0)
```

**Run**

```powershell
godot --headless --script tests/assert_phase6_style_contract.gd
```

Expected before implementation: fails because files are missing.

**Implement**

Write the style bible and prompt matrix from the Phase 6 spec. Use original character names and setting language from existing game docs/scripts when present. If names are not already present, introduce original names in the prompt matrix and keep them consistent:

- Protagonists: Mika, Ren, Shiori
- Stage boss pairs: Aoi/Madara, Kirika/Yukari, Sena/Oboro, Hina/Kasumi, Rei/Tsukiko, Noa/Astralis

Do not use protected Touhou character names or likenesses.

**Pass condition**

The style contract test passes.

## Task 2: Manifest Builder And AssetRegistry Surface

**Files**

- Add `tools/art/phase6_asset_manifest_builder.py`
- Add `assets/manifest/phase6_asset_manifest.json`
- Update `autoload/asset_registry.gd`
- Add `tests/assert_phase6_asset_manifest.gd`
- Add `tests/assert_phase6_asset_registry.gd`

**Test first**

Create `tests/assert_phase6_asset_manifest.gd`:

```gdscript
extends SceneTree

func _init() -> void:
	var manifest_text := FileAccess.get_file_as_string("res://assets/manifest/phase6_asset_manifest.json")
	assert(manifest_text.length() > 0)
	var parsed: Variant = JSON.parse_string(manifest_text)
	assert(typeof(parsed) == TYPE_DICTIONARY)
	assert(parsed.has("version"))
	assert(parsed.has("assets"))
	assert(parsed["assets"].size() >= 98)

	var accepted_statuses := {"pending_generation": true, "generated_needs_review": true, "accepted": true, "rejected": true}
	var ids := {}
	for asset in parsed["assets"]:
		assert(asset.has("id"))
		assert(not ids.has(asset["id"]))
		ids[asset["id"]] = true
		assert(asset.has("final_path"))
		assert(asset["final_path"].begins_with("res://assets/"))
		assert(asset.has("width") and asset["width"] > 0)
		assert(asset.has("height") and asset["height"] > 0)
		assert(asset.has("status") and accepted_statuses.has(asset["status"]))
		assert(asset.has("readability_role") and str(asset["readability_role"]).length() >= 24)
		assert(asset.has("prompt_id") and str(asset["prompt_id"]).length() > 0)

	assert(ids.has("stage_01_background_far"))
	assert(ids.has("stage_06_background_spell"))
	assert(ids.has("protagonist_mika_gameplay_sprite"))
	assert(ids.has("boss_06b_spell_aura"))
	assert(ids.has("enemy_bullet_lotus_core"))
	assert(ids.has("item_power_large"))
	quit(0)
```

Create `tests/assert_phase6_asset_registry.gd`:

```gdscript
extends SceneTree

func _init() -> void:
	var registry := preload("res://autoload/asset_registry.gd").new()
	assert(registry.has_method("stage_background_layers"))
	assert(registry.has_method("protagonist_assets"))
	assert(registry.has_method("boss_assets"))
	assert(registry.has_method("enemy_family_assets"))
	assert(registry.has_method("bullet_family_assets"))
	assert(registry.has_method("bomb_assets"))
	assert(registry.has_method("item_assets"))
	assert(registry.has_method("ui_assets"))

	var stage_layers: Dictionary = registry.stage_background_layers(1)
	assert(stage_layers.has("far"))
	assert(stage_layers.has("mid"))
	assert(stage_layers.has("near"))
	assert(stage_layers.has("spell"))
	assert(str(stage_layers["far"]).ends_with("assets/backgrounds/stage_01/far.png"))

	var bullets: Dictionary = registry.bullet_family_assets()
	assert(bullets.has("enemy_bullet_lotus_core"))
	assert(bullets.has("player_bullet_focus_lance"))
	quit(0)
```

**Run**

```powershell
python tools/art/phase6_asset_manifest_builder.py
godot --headless --script tests/assert_phase6_asset_manifest.gd
godot --headless --script tests/assert_phase6_asset_registry.gd
```

Expected before implementation: tests fail because builder, manifest, and registry methods are missing.

**Implement**

`phase6_asset_manifest_builder.py` must deterministically generate the manifest inventory. Keep all paths stable and original. Use `json.dump(..., indent=2, ensure_ascii=False)`.

Update `AssetRegistry` without removing prior Phase 5 methods. Add dictionaries and getter methods for:

- `stage_background_layers(stage_id: int) -> Dictionary`
- `protagonist_assets(protagonist_id := "") -> Dictionary`
- `boss_assets(boss_id := "") -> Dictionary`
- `enemy_family_assets() -> Dictionary`
- `bullet_family_assets() -> Dictionary`
- `bomb_assets() -> Dictionary`
- `item_assets() -> Dictionary`
- `ui_assets() -> Dictionary`

All getters must return `res://` paths and keep procedural fallbacks possible when files do not exist.

**Pass condition**

Manifest and registry tests pass with entries still allowed to be `pending_generation`.

## Task 3: Validation And Contact Sheet Tooling

**Files**

- Add `tools/art/phase6_validate_assets.py`
- Add `tools/art/phase6_contact_sheet.py`
- Add `tests/assert_phase6_asset_files.gd`
- Add `docs/art/review/phase6_asset_acceptance.md`

**Test first**

Create `tests/assert_phase6_asset_files.gd`:

```gdscript
extends SceneTree

func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/manifest/phase6_asset_manifest.json"))
	assert(typeof(parsed) == TYPE_DICTIONARY)
	for asset in parsed["assets"]:
		if asset["status"] != "accepted":
			continue
		var final_path := str(asset["final_path"])
		assert(FileAccess.file_exists(final_path))
		var image := Image.new()
		var err := image.load(final_path)
		assert(err == OK)
		assert(image.get_width() == int(asset["width"]))
		assert(image.get_height() == int(asset["height"]))
		if bool(asset["transparent"]):
			assert(image.detect_alpha() != Image.ALPHA_NONE)
	quit(0)
```

**Run**

```powershell
python tools/art/phase6_validate_assets.py
python tools/art/phase6_contact_sheet.py
godot --headless --script tests/assert_phase6_asset_files.gd
```

Expected before implementation: validation scripts missing. After implementation, scripts pass with no accepted assets or with accepted assets that exist.

**Implement**

`phase6_validate_assets.py` must:

- Load the manifest.
- Validate JSON schema fields.
- For `accepted` assets, verify file existence.
- Read PNG dimensions from file headers without relying on a heavyweight runtime.
- Validate alpha requirement for transparent accepted assets using Pillow if available; otherwise print a warning and leave alpha verification to Godot test.
- Emit a clear summary: total assets, accepted assets, missing accepted files, dimension mismatches.
- Exit non-zero on missing or dimension-mismatched accepted files.

`phase6_contact_sheet.py` must:

- Use Pillow if available.
- Build contact sheets for style, protagonists, bosses, backgrounds, and gameplay readability.
- Place labels outside asset art or in a reserved margin so labels never obscure gameplay evidence.
- Generate review outputs into `docs/art/review/`.
- Exit non-zero if accepted assets required for a requested sheet are missing.
- Support `--allow-partial` for early batch review.

`phase6_asset_acceptance.md` must define the sign-off table:

```markdown
| Asset id | Status | Gameplay readability | Style match | Notes |
```

**Pass condition**

Validation scripts run successfully. The file test passes for accepted entries.

## Task 4: Generate Style Reference And Protagonist Batch

**Files**

- Add final protagonist assets under `assets/characters/protagonists/`
- Add source assets under `assets/source/phase6/protagonists/`
- Add `docs/art/review/phase6_style_reference.png`
- Add `docs/art/review/phase6_protagonists_contact_sheet.png`
- Update manifest statuses for protagonist/style assets to `accepted`
- Update `docs/art/review/phase6_asset_acceptance.md`

**Image generation method**

Use the `imagegen` skill and `image_gen` tool for raster generation. Prompt from `docs/art/phase6_asset_prompts.md`. Generate style reference first, then use its content as the visual anchor in subsequent prompts through explicit textual style reuse:

```text
hand-painted premium anime game illustration, original shrine-fantasy danmaku world, elegant ink-and-gouache texture, crisp gameplay silhouette, restrained bloom, clean alpha-ready subject, clear color ownership, high detail where large, simplified where gameplay-scaled
```

For transparent gameplay sprites, use a solid chroma background if the generator does not return alpha. Remove chroma with a deterministic local tool and inspect the result before acceptance. If true alpha generation requires a paid or remote CLI that is not configured, ask the user before installing or configuring it.

**Gameplay constraints**

- Player sprites use cool cyan/white/gold ownership language.
- Do not place red/orange hostile bullet glows on player sprites.
- Player hitbox area must remain visually calm.
- Focus/option effects must not look like enemy bullets.

**Review**

Run:

```powershell
python tools/art/phase6_validate_assets.py
python tools/art/phase6_contact_sheet.py --sheet protagonists
godot --headless --script tests/assert_phase6_asset_files.gd
```

Open `docs/art/review/phase6_protagonists_contact_sheet.png` visually. Reject and regenerate any protagonist whose silhouette or effects could be mistaken for bullets/items.

**Pass condition**

All protagonist and style reference entries are `accepted`, dimensions match, alpha is present where required, and contact sheet is generated.

## Task 5: Generate Boss Batch

**Files**

- Add final boss assets under `assets/characters/bosses/`
- Add source boss assets under `assets/source/phase6/bosses/`
- Add `docs/art/review/phase6_bosses_contact_sheet.png`
- Update manifest statuses for boss assets to `accepted`
- Update acceptance notes

**Image generation method**

Use `imagegen` with one prompt per boss gameplay sprite, portrait, and spell aura. Keep each boss original and stage-aligned:

- Stage 1: Aoi/Madara, paper-lantern forest shrine, beginner-readable shapes
- Stage 2: Kirika/Yukari, rain canal and mirror-water motifs
- Stage 3: Sena/Oboro, clockwork archive and paper talisman geometry
- Stage 4: Hina/Kasumi, storm observatory and celestial instruments
- Stage 5: Rei/Tsukiko, ruined moon garden and ghost-light motifs
- Stage 6: Noa/Astralis, astral shrine engine and final luminous geometry

**Gameplay constraints**

- Boss gameplay sprite must not include tiny floating particles that resemble bullets.
- Spell aura must be visually player-opposed but should not hide bullet centers.
- Portraits can be detailed; gameplay sprites must simplify detail at 512x512 scale.

**Review**

Run:

```powershell
python tools/art/phase6_validate_assets.py
python tools/art/phase6_contact_sheet.py --sheet bosses
godot --headless --script tests/assert_phase6_asset_files.gd
```

Inspect boss sheet. Reject any sprite whose accessories or aura create bullet confusion.

**Pass condition**

All boss entries are `accepted`, dimensions match, transparency is valid, and contact sheet is generated.

## Task 6: Generate Six Stage Background Batches

**Files**

- Add stage backgrounds under `assets/backgrounds/stage_01/` through `stage_06/`
- Add sources under `assets/source/phase6/backgrounds/`
- Add `docs/art/review/phase6_backgrounds_contact_sheet.png`
- Update manifest statuses and acceptance notes

**Image generation method**

Use `imagegen` for far, mid, near, and spell layers per stage. Generate each stage as a coherent set:

1. Stage 1: twilight shrine approach, cedar silhouettes, lantern warmth
2. Stage 2: rain canal, reflective paper umbrellas, blue-green restraint
3. Stage 3: hidden archive, brass clockwork, parchment and teal shadows
4. Stage 4: storm observatory, cloud breaks, violet sky and copper instruments
5. Stage 5: ruined moon garden, pale blossoms, silver and muted crimson
6. Stage 6: astral shrine engine, luminous void geometry, white-gold finality

**Gameplay constraints**

- Far and mid layers must be low-contrast.
- Near layers must avoid high-frequency foreground clutter near the central player lanes.
- Spell layers can be dramatic but must avoid bullet-like dots and projectile-colored micro-glows.
- No baked text.

**Review**

Run:

```powershell
python tools/art/phase6_validate_assets.py
python tools/art/phase6_contact_sheet.py --sheet backgrounds
godot --headless --script tests/assert_phase6_asset_files.gd
```

Inspect all backgrounds at 720x960 and in reduced thumbnail form. Reject any layer that creates false projectile signals.

**Pass condition**

All 24 background entries are `accepted`, dimensions match, and contact sheet is generated.

## Task 7: Generate Gameplay Clarity Batch

**Files**

- Add enemy sprites under `assets/characters/enemies/`
- Add bullet sprites under `assets/effects/bullets/`
- Add bomb plates under `assets/effects/bombs/`
- Add item icons under `assets/items/`
- Add UI art under `assets/ui/`
- Add `docs/art/review/phase6_gameplay_readability_composite.png`
- Update manifest statuses and acceptance notes

**Image generation method**

Use `imagegen` for enemy families, bullet families, bomb effects, item icons, and UI art. Generate small gameplay elements with stronger silhouette discipline than large illustrations.

**Required bullet families**

- `enemy_bullet_lotus_core`
- `enemy_bullet_ember_needle`
- `enemy_bullet_mirror_drop`
- `enemy_bullet_clock_gear`
- `enemy_bullet_storm_arc`
- `enemy_bullet_moon_wisp`
- `enemy_bullet_astral_star`
- `enemy_bullet_warning_ring`
- `enemy_bullet_slow_orb`
- `enemy_bullet_fast_shard`
- `enemy_bullet_spiral_seed`
- `enemy_bullet_boss_sigil`

**Required player bullet families**

- `player_bullet_focus_lance`
- `player_bullet_spread_petal`
- `player_bullet_orbit_star`
- `player_bullet_homing_charm`
- `player_bullet_bomb_seed`
- `player_bullet_graze_spark`

**Required item icons**

- `item_power_small`
- `item_power_large`
- `item_score_small`
- `item_score_large`
- `item_life_fragment`
- `item_bomb_fragment`
- `item_full_power`
- `item_story_token`

**Gameplay constraints**

- Hostile bullets get warm/magenta/violet/red emphasis.
- Player bullets get cyan/white/gold emphasis.
- Items use solid collectible silhouettes and do not use hostile red bullet centers.
- Enemy sprites use darker organic silhouettes and do not contain bright projectile dots.
- UI art must frame the game and not compete with live bullet fields.

**Review**

Run:

```powershell
python tools/art/phase6_validate_assets.py
python tools/art/phase6_contact_sheet.py --sheet gameplay
godot --headless --script tests/assert_phase6_asset_files.gd
```

Inspect `phase6_gameplay_readability_composite.png` at full size and at 50% zoom. Reject any bullet, item, bomb, enemy, or UI element that becomes ambiguous.

**Pass condition**

All gameplay clarity entries are `accepted`, validation passes, and the readability composite is generated.

## Task 8: Runtime Integration With Fallbacks

**Files**

- Update `scripts/main.gd`
- Update `autoload/asset_registry.gd` only if additional getters are needed
- Add focused tests if runtime helpers are extracted

**Implementation**

Integrate accepted assets without destabilizing gameplay:

1. Add a texture cache helper in `scripts/main.gd`:

```gdscript
var asset_texture_cache: Dictionary = {}

func get_asset_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if asset_texture_cache.has(path):
		return asset_texture_cache[path]
	if not ResourceLoader.exists(path):
		asset_texture_cache[path] = null
		return null
	var tex := load(path)
	asset_texture_cache[path] = tex
	return tex
```

2. Stage background rendering:
   - Try `AssetRegistry.stage_background_layers(stage_id)`.
   - Draw far and mid as low-contrast full-screen layers.
   - Draw near with reduced opacity or motion parallax that cannot resemble bullets.
   - Use spell layer only during boss/spell state.
   - Keep the procedural background as fallback if assets are missing.

3. Character rendering:
   - Draw protagonist gameplay sprite centered on the player when present.
   - Keep existing hitbox visualization and movement logic unchanged.
   - Draw boss sprite when present; keep current boss HP and attack state unchanged.
   - Keep procedural fallback for missing files.

4. Gameplay element rendering:
   - Bullet art must be optional and cached.
   - Preserve collision radius logic; image size cannot change hitboxes.
   - Items use item icons where present.
   - Bomb plates can be drawn during bomb state with opacity caps and clear ownership color.

5. UI rendering:
   - Title, pause, and spell-card art may use `AssetRegistry.ui_assets()`.
   - Pause overlay must not hide essential context more than current pause behavior.

**Performance constraints**

- Load textures once and cache them.
- Do not create textures per frame.
- Avoid adding one node per bullet.
- Keep bullet draw loops using canvas drawing or texture draw calls.
- Keep generated background files to predictable 720x960 dimensions.

**Tests and smoke**

Run existing tests plus a launch smoke:

```powershell
godot --headless --script tests/assert_phase6_asset_registry.gd
godot --headless --script tests/assert_phase6_asset_files.gd
godot --headless --quit-after 3
```

If a browser or viewport smoke exists from prior phases, run it too.

**Pass condition**

The game starts with accepted art paths available, preserves procedural fallbacks, and does not change collision/gameplay behavior.

## Task 9: Phase 6 Final Verification, Commit, Merge, Push

**Verification**

Run:

```powershell
python tools/art/phase6_asset_manifest_builder.py
python tools/art/phase6_validate_assets.py
python tools/art/phase6_contact_sheet.py
godot --headless --script tests/assert_phase6_style_contract.gd
godot --headless --script tests/assert_phase6_asset_manifest.gd
godot --headless --script tests/assert_phase6_asset_registry.gd
godot --headless --script tests/assert_phase6_asset_files.gd
godot --headless --quit-after 3
git status --short
```

Visually inspect:

- `docs/art/review/phase6_style_reference.png`
- `docs/art/review/phase6_protagonists_contact_sheet.png`
- `docs/art/review/phase6_bosses_contact_sheet.png`
- `docs/art/review/phase6_backgrounds_contact_sheet.png`
- `docs/art/review/phase6_gameplay_readability_composite.png`

**Completion criteria**

- All manifest entries required by Phase 6 are `accepted`.
- All accepted assets exist at final paths with correct dimensions.
- Alpha-required assets load with alpha.
- Contact sheets and readability composite exist.
- Runtime uses assets with fallbacks and texture caching.
- Godot tests and smoke pass.
- `git status --short` contains only intentional Phase 6 files.

**Commit and integrate**

```powershell
git add docs/art assets autoload/asset_registry.gd scripts/main.gd tools/art tests docs/superpowers/plans/2026-07-09-art-production-phase6.md
git commit -m "feat: add phase 6 hand-painted art asset pipeline"
git checkout master
git merge --no-ff feature/art-production-phase6
git push origin master
```

If binary assets make the commit unexpectedly large, stop and report the size before pushing.

## Delegation Plan

Use subagents/workers for independent parts:

1. **Documentation worker:** style bible, prompt matrix, acceptance checklist.
2. **Registry/tooling worker:** manifest builder, validation, contact sheet scripts, tests.
3. **Runtime integration worker:** `AssetRegistry` and `scripts/main.gd` fallback-aware rendering.
4. **Asset production lead in main session:** image generation, visual review, acceptance decisions, and final gameplay-readability gate. Keep image generation in the main session unless the available subagent environment explicitly exposes the same `imagegen` capability.

The main session must keep final approval authority for style consistency and gameplay readability.
