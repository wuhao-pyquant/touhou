# Phase 6 Art Production Design

## Goal

Produce and import a unified, hand-painted production-grade visual asset library for the original night-festival danmaku game, using the Phase 5 six-stage content and the existing `AssetRegistry` paths as the stable target surface.

This phase follows the approved visual direction **B: style lock plus batched full production**. The goal is still a full asset library, but production must proceed through a locked style bible, asset manifest, batch generation, QA, and import gates so that quality and style remain consistent.

## Non-Negotiable Gameplay Readability Standard

Art must serve gameplay. No asset is acceptable if it harms player readability, bullet recognition, enemy recognition, or UI clarity.

This standard applies throughout Phase 6:

- Enemy bullets, player bullets, items, enemies, bosses, background layers, bomb effects, UI overlays, and spell-card visuals must remain visually separable at 720x960 during dense gameplay.
- Background art must stay behind gameplay. It may be rich and hand-painted, but it must avoid bright bullet-like dots, high-contrast moving shapes near active lanes, and foreground clutter that can be confused with bullets or items.
- Bullet assets must preserve clear centers, readable silhouettes, consistent collision expectation, and strong color/family identity.
- Items must be more collectible-looking than bullet-like, with distinct silhouettes for power, point, bomb fragment, life fragment, Night Festival Seal, and full power.
- Boss, enemy, and protagonist sprites must not hide or mimic bullets. Battle sprites need strong silhouette separation from bullet colors and the background.
- Bomb effects may be spectacular, but must clearly communicate ownership as player effects and must not obscure live enemy bullets longer than the existing bomb clear window.
- UI and spell-card announcement art must never cover the active hitbox area or current danger zone without gameplay pause/transition intent.
- QA must inspect every imported asset in a gameplay-like composition, not only as isolated image files.

Any generated art that is beautiful but reduces playability must be revised or rejected.

## Scope

In scope for Phase 6:

- A project-local style bible that defines the unified hand-painted art direction.
- A machine-readable asset manifest derived from `autoload/asset_registry.gd`, Phase 3 protagonists, Phase 4 bullet/item systems, and Phase 5 stage/boss content.
- Hand-painted style raster assets for:
  - Three protagonist portraits.
  - Three protagonist battle spritesheets.
  - Three protagonist shot atlases.
  - Three protagonist bomb atlases.
  - Three protagonist ending illustrations.
  - Twelve boss portraits.
  - Twelve boss battle sprites.
  - Twelve spell-card backgrounds.
  - Six layered stage backgrounds with far, mid, front, and atmosphere layers.
  - Enemy family visuals for stage reskins where needed.
  - Bullet family atlases for the eight enemy bullet families.
  - Item icons for six core item types.
  - Title/menu/key UI art needed to move away from procedural placeholder feel.
- Import metadata and validation tests proving referenced assets exist and meet basic size/format constraints.
- Runtime integration that uses asset registry paths and preserves existing gameplay behavior.

Out of scope for Phase 6:

- Music and SFX expansion. That remains Phase 7.
- Final difficulty tuning and practice/final QA. That remains Phase 8.
- Full visual-novel branching art.
- Existing Touhou Project characters, names, art, music, or protected assets.

## Style Direction

The approved style target is high-detail hand-painted Japanese night-festival fantasy:

- Rich shrine, yokai market, bamboo mist, tengu mountain, oni banquet, and divine night-festival motifs.
- Painterly anime character rendering with detailed fabric, hair ornaments, paper charms, lantern glow, and controlled magical effects.
- Warm lantern golds and reds for festival identity, balanced with stage-specific palettes:
  - Stage 1: warm shrine lanterns and approachable reds.
  - Stage 2: market gold, mask colors, coin highlights, tool motifs.
  - Stage 3: cool moonlit blues, bamboo greens, fog translucency.
  - Stage 4: high-altitude blue-gray wind, paper white, feather accents.
  - Stage 5: deep reds, drum wood, oni fire, sake lacquer.
  - Stage 6: divine blue-black sky, endless lantern rivers, spirit fire, faith particles.
- Every asset prompt must explicitly say the game is original and must avoid existing Touhou Project characters, costumes, exact symbols, logos, music, or protected names.

## Asset Production Strategy

Phase 6 uses four production gates:

1. **Style Bible Gate**
   - Produce a written `docs/art/style_bible.md`.
   - Produce a small set of style reference images or contact sheets.
   - Lock palette, line/detail density, lighting language, silhouette rules, and readability rules.

2. **Manifest Gate**
   - Generate `assets/manifest/phase6_asset_manifest.json`.
   - Each manifest entry includes id, category, registry path, source prompt id, dimensions, alpha requirement, readability notes, and status.
   - Tests fail if registry-referenced required assets are missing.

3. **Batch Generation Gate**
   - Batch 1: protagonist portraits/sprites/bombs/shots/endings.
   - Batch 2: boss portraits/sprites/spell backgrounds.
   - Batch 3: six layered stage backgrounds.
   - Batch 4: bullet families, item icons, enemy family reskins, UI key art.
   - Each batch gets review contact sheets before being accepted.

4. **Import And QA Gate**
   - Move accepted assets into stable `assets/` paths.
   - Run format/size checks and scene smoke checks.
   - Generate a gameplay readability contact sheet with representative gameplay layers.

## Tooling

Default generation path:

- Use the built-in `imagegen` skill and `image_gen` tool for production bitmap drafts and final raster images.
- For project-bound assets, generated files must be copied into the workspace. No referenced asset may remain only under the default Codex generated-images directory.

Transparency path:

- For simple cutouts, generate on a flat chroma-key background and remove the key locally with the installed imagegen helper.
- For complex true transparency cases such as hair, smoke, translucent spirit fire, or detailed character edges, ask before switching to CLI fallback with model-native transparency, because that requires an `OPENAI_API_KEY`.

Local processing:

- Use deterministic local scripts for cropping, contact sheet creation, chroma-key removal, dimension checks, and manifest validation.
- Generated assets must be non-destructively stored under their final registry paths or a clearly named `assets/source/phase6/` draft/source area before acceptance.

Possible optional tools:

- Cowart may be used for visual review boards, but it is not required for runtime assets.
- No additional plugin install is required at the start of Phase 6. If a later batch needs a specialized generation or audio tool that is not installed, ask the user before installing.

## Runtime Integration Rules

Phase 6 should not rewrite gameplay systems. It should integrate visuals conservatively:

- Keep `AssetRegistry` as the authoritative path map.
- Add asset validation tests before runtime rendering changes.
- Add rendering helpers only where the current procedural drawing must reference imported PNGs.
- Keep procedural fallbacks during import so missing assets fail tests but do not make editor smoke checks impossible while a batch is in progress.
- Avoid node-heavy backgrounds; layer backgrounds through cached textures or simple draw calls.
- Keep 720x960 internal viewport behavior unchanged.
- Preserve Phase 2 UI flow, Phase 3 protagonist selection, Phase 4 gameplay data, and Phase 5 six-stage routing.

## QA Standards

Every accepted asset must pass:

- **Existence:** final path exists at the registry path.
- **Format:** PNG, readable by Godot, no corrupt image data.
- **Dimensions:** suitable for its role and not oversized for runtime.
- **Alpha:** alpha channel required for character sprites, bullets, items, bombs, and UI overlays.
- **Readability:** asset passes visual inspection against gameplay composite sheets.
- **Style consistency:** asset follows the locked style bible and stage palette.
- **No protected IP:** no existing Touhou Project characters, exact costumes, names, logos, or recognizable protected art.

Readability QA must include:

- Bullets over every stage background family.
- Items over dense bullet scenes.
- Player sprite over boss/background/bullet compositions.
- Bomb effects over active bullets.
- UI overlays over stage and boss scenes.

## File Targets

Expected new or modified files:

- `docs/art/style_bible.md`
- `docs/art/phase6_asset_prompts.md`
- `assets/manifest/phase6_asset_manifest.json`
- `tools/art/phase6_manifest.gd` or equivalent validation helper.
- `tools/art/phase6_contact_sheet.py` or equivalent deterministic image utility.
- `tests/assert_phase6_asset_manifest.gd`
- `tests/assert_phase6_asset_files.gd`
- `tests/assert_phase6_readability_contract.gd`
- Final PNG assets under the existing `assets/` tree referenced by `AssetRegistry`.

## Success Criteria

Phase 6 is complete when:

- The style bible is written and used by every generation prompt.
- The manifest covers every visual asset path required by `AssetRegistry` plus bullet/item/UI additions.
- Accepted PNG assets exist at all required final registry paths.
- Validation tests pass in headless Godot.
- Contact sheets exist for human visual review.
- Gameplay smoke still starts successfully.
- No asset batch violates the gameplay readability standard.

## User Approval State

The user selected **B: style lock plus batched full production** and added the following binding requirement:

> Design must pay attention to whether art conflicts with gameplay. Recognition between all elements must be clear and must not affect the game itself. This requirement must be written into execution standards and followed throughout.

This spec treats that requirement as a non-negotiable QA gate for all Phase 6 work.
