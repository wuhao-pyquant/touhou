# Phase 6 Style Bible

This document locks the art direction for the original night-festival danmaku game. All Phase 6 image prompts, imports, contact sheets, and QA decisions must follow this contract before an asset can be accepted into the project.

## Project Identity

The game is an original night-festival danmaku game about shrine paths, yokai markets, mist bamboo, tengu mountain wind, oni banquet heat, and a divine lantern realm. It is not a Touhou Project work, crossover, remake, or clone.

## Style Pillars

- Hand-painted Japanese night-festival fantasy.
- Painterly anime characters with clear silhouettes, layered fabric, hair ornaments, paper charms, lantern glow, and controlled magical effects.
- Backgrounds use visible brush texture, soft depth separation, and limited high-frequency detail in the active playfield.
- Effects may be luminous, but gameplay elements keep the highest contrast and cleanest edges.
- UI art is decorative but restrained, with readable shapes and no clutter behind active text or the hitbox lane.

## Original-IP Rules

- Use original characters only.
- Use no copyrighted Touhou character names, likenesses, costumes, exact symbols, logos, music references, protected spell names, or protected story elements.
- Every generated prompt must say the game is original.
- The phrase "Touhou-like" must not appear in image prompts; use "original night-festival danmaku game" instead.

## Gameplay Readability Contract

Art serves gameplay. Dense-play readability is mandatory at the internal 720x960 viewport.

Non-negotiable checks:

- Enemy bullets, player bullets, items, enemies, bosses, background layers, bomb effects, UI overlays, and spell-card visuals must be visually separable during dense gameplay.
- Backgrounds must stay behind gameplay. Use depth, lower contrast, and softened detail in active lanes.
- Use no bullet-like background dots, no bright bead strings, no small star fields, and no loose confetti clusters that can be mistaken for bullets or items.
- Bullet assets must keep clear centers, readable silhouettes, expected collision size, and strong family identity.
- Items must look collectible rather than dangerous, with silhouettes distinct from circle, rice, butterfly, needle, talisman, star, laser, and large_orb bullet families.
- Boss, enemy, and protagonist sprites must never hide bullets, mimic bullets, or share the dominant live bullet color without an outline or value separation.
- Bomb effects may be spectacular, but they must read as player-owned effects and must not obscure live enemy bullets beyond the existing clear window.
- UI and spell-card announcement art must not cover the active hitbox area or current danger zone unless the gameplay state is paused or transitioning.
- Any beautiful asset that weakens bullet recognition, enemy recognition, item recognition, or UI clarity must be revised or rejected.

## Shape Language

Playable protagonists:

- Mika maps to protagonist id `miko`: balanced shrine-bound support, red and white base, boundary charm geometry, rounded readable sprite mass.
- Ren maps to protagonist id `magician`: range spellcaster, dark cloth with gold and violet accents, star-dust magic kept distinct from enemy star bullets.
- Shiori maps to protagonist id `swordswoman`: half-yokai swordswoman, lean silhouette, spirit blade accents, green-cyan highlights kept distinct from collectible items.

Gameplay silhouettes must read from the outer contour first. Internal decoration is secondary and must not create bullet-like dots, item-like sparkles, or unclear collision expectations.

## Color Language

- Lantern gold: warm highlights, signage, flame edges, charm trim.
- Shrine red: accent rails, seals, bows, danger-neutral festival motifs.
- Ink blue-black: night sky, deep shadow, readable negative space.
- Paper white: talismans, UI panel accents, spell-card callouts.

Player-owned effects should remain visually separate from enemy bullets. If colors overlap, separate them through outline value, shape, animation language, or placement.

## Bullet And Bomb Readability

- `circle`: round small pressure, clean rim, bright center.
- `rice`: oval rice shape, cyan family identity, narrow collision expectation.
- `butterfly`: decorative but not fragile, wings readable as enemy bullets.
- `needle`: thin fast threat, pointed silhouette, yellow-orange identity.
- `talisman`: rectangular paper charm, red identity, no item-like sparkle.
- `star`: blue star bullet, simple enough to read at speed.
- `laser`: lane warning and beam identity, clear edge and telegraph.
- `large_orb`: large space-control orb with clear boundary and visible center.
- Bomb effects must communicate player ownership, clear timing, and post-clear danger visibility.

## Character Rendering Standard

- Gameplay sprites need clear outer contours and readable facing at small scale.
- Portraits can carry more fabric detail than gameplay sprites.
- Battle sprites use simplified internal detail and high-value outline separation.
- Transparent gameplay assets must not include noisy halos or stray opaque pixels.

## Enemy And Boss Rendering Standard

Stage boss pairs:

- Stage 1: Aoi as `lantern_tsukumogami`, Madara as `festival_guide_fox`.
- Stage 2: Kirika as `abacus_tsukumogami`, Yukari as `oni_market_leader`.
- Stage 3: Sena as `lost_rabbit_yokai`, Oboro as `bamboo_illusionist`.
- Stage 4: Hina as `rookie_crow_tengu`, Kasumi as `mountain_wind_tengu`.
- Stage 5: Rei as `little_oni_drummer`, Tsukiko as `banquet_oni_princess`.
- Stage 6: Noa as `festival_fox_miko`, Astralis as `hyakki_night_festival_god`.

Boss spell auras stay outside the boss silhouette enough to preserve boss recognition.

## Background Rendering Standard

- Far layers use broad silhouettes and sky value only, with the lowest contrast.
- Mid layers carry the main setting identity, readable depth, and no bullet-like background dots.
- Front layers use soft framing elements outside active lanes; never foreground clutter over the player route.
- Atmosphere layers use fog, wind, ember, or spirit overlays with broad shapes and low opacity.

## UI Rendering Standard

UI overlays must preserve text-safe areas, hitbox visibility, danger-zone visibility, and spell-card timing. Decorative paper texture, lantern rim light, and festival trim are acceptable only when they do not reduce active-play clarity.

## Stage Palettes

- Stage 1 `shrine_approach`: warm shrine lanterns, approachable reds, aged wood, early-night blue shadows.
- Stage 2 `yokai_market`: market gold, mask colors, coin highlights, tool motifs, warm stall light.
- Stage 3 `mist_bamboo_grove`: moonlit blues, bamboo greens, fog translucency, low-contrast distant detail.
- Stage 4 `tengu_mountain_path`: high-altitude blue-gray wind, paper white, feather accents, crisp air gaps.
- Stage 5 `oni_banquet_hall`: deep reds, drum wood, oni fire, sake lacquer, heavy shadow bands.
- Stage 6 `night_festival_divine_realm`: divine blue-black sky, endless lantern rivers, spirit fire, faith particles kept broad and non-bullet-like.

## Prompt Negative Constraints

Every production prompt must include local negative constraints. Required negatives include no copyrighted Touhou character, no protected names, no exact costumes, no logos, no bullet-like background dots for backgrounds, no small bright confetti that resembles bullets or items, no high-contrast clutter in active lanes, no unreadable silhouettes, and no muddy low-contrast gameplay shapes.

## Acceptance Checklist

Before acceptance, inspect the asset in a gameplay-like composition:

- Bullets over each background family.
- Items over dense bullet scenes.
- Player sprite over boss, background, and bullets.
- Bomb effects over active bullets.
- UI overlays over stage and boss scenes.

If the composite is unclear, revise the asset before import.
