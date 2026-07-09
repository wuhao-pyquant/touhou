# Phase 6 Asset Prompt Matrix

Use this matrix as the source language for Phase 6 generation. Each prompt must preserve the style bible, the original IP restriction, and the gameplay readability contract.

## Global Prompt Prefix

Hand-painted Japanese night-festival fantasy for an original night-festival danmaku game, production game asset, painterly anime rendering, lantern-lit atmosphere, clean gameplay silhouettes, no copyrighted Touhou character, no protected names, no exact costumes, no logos.

## Global Negative Prompt

No copyrighted Touhou character, no protected character likeness, no exact shrine maiden or magician costume from existing games, no logos, no music references, no bullet-like background dots, no small bright confetti that resembles bullets or items, no high-contrast clutter in active lanes, no unreadable silhouettes, no muddy low-contrast gameplay shapes.

## Readability constraints

All assets must remain readable at 720x960 during dense-play conditions. Backgrounds stay behind bullets and items. Character sprites need strong silhouettes and must not mimic bullet or item shapes. Spell auras and bomb effects must communicate ownership and must not hide live enemy bullets beyond intended clear timing.

## Protagonist Names

- Mika: registry id `miko`, balanced boundary shrine protagonist.
- Ren: registry id `magician`, ranged festival spellcaster.
- Shiori: registry id `swordswoman`, half-yokai spirit-blade swordswoman.

## Boss Name Matrix

- Stage 1: Aoi maps to `lantern_tsukumogami`; Madara maps to `festival_guide_fox`.
- Stage 2: Kirika maps to `abacus_tsukumogami`; Yukari maps to `oni_market_leader`.
- Stage 3: Sena maps to `lost_rabbit_yokai`; Oboro maps to `bamboo_illusionist`.
- Stage 4: Hina maps to `rookie_crow_tengu`; Kasumi maps to `mountain_wind_tengu`.
- Stage 5: Rei maps to `little_oni_drummer`; Tsukiko maps to `banquet_oni_princess`.
- Stage 6: Noa maps to `festival_fox_miko`; Astralis maps to `hyakki_night_festival_god`.

## stage_01_background_far

Target path: `res://assets/backgrounds/stage1_shrine_approach_far.png`

Prompt: Global Prompt Prefix, far background layer for Stage 1 `shrine_approach`, warm shrine lanterns and approachable reds under early-night blue shadows, distant shrine road, soft tree masses, lantern glow as broad painted pools, low detail and low contrast in the active playfield.

Readability constraints: no bullet-like background dots, no bead strings, no tiny star particles, no high-contrast foreground clutter, reserve the clearest contrast for bullets and items.

## stage_01_background_mid

Target path: `res://assets/backgrounds/stage1_shrine_approach_mid.png`

Prompt: Global Prompt Prefix, mid layer for Stage 1 `shrine_approach`, painted shrine approach with torii silhouettes, paper charms, warm lantern stands, readable depth bands, festival invitation mood.

Readability constraints: keep small charms and lantern flames broad, dimmed, and away from bullet lanes; no bullet-like background dots.

## stage_01_background_front

Target path: `res://assets/backgrounds/stage1_shrine_approach_front.png`

Prompt: Global Prompt Prefix, front framing layer for Stage 1, soft shrine eaves, rope, leaves, and lantern edges placed outside active lanes.

Readability constraints: frame only, no active-lane clutter, no bright small shapes.

## stage_01_background_atmosphere

Target path: `res://assets/backgrounds/stage1_shrine_approach_atmosphere.png`

Prompt: Global Prompt Prefix, transparent atmosphere layer with warm lantern haze and broad drifting paper glow for Stage 1.

Readability constraints: large soft forms only, low opacity, no bullet-like background dots.

## stage_02_background_set

Target paths: `res://assets/backgrounds/stage2_yokai_market_far.png`, `stage2_yokai_market_mid.png`, `stage2_yokai_market_front.png`, `stage2_yokai_market_atmosphere.png`

Prompt: Global Prompt Prefix, layered yokai market with gold stall light, masks, coin highlights, tool motifs, lively but readable market depth. Far layer broad roofs and lights; mid layer stalls and signs; front layer edge framing; atmosphere warm steam and glow.

Readability constraints: coin highlights must be large and dim, not bullet-like; active lanes stay uncluttered; no bullet-like background dots.

## stage_03_background_set

Target paths: `res://assets/backgrounds/stage3_mist_bamboo_grove_far.png`, `stage3_mist_bamboo_grove_mid.png`, `stage3_mist_bamboo_grove_front.png`, `stage3_mist_bamboo_grove_atmosphere.png`

Prompt: Global Prompt Prefix, mist bamboo grove, cool moonlit blues, bamboo greens, layered fog, wrong-path atmosphere, hand-painted depth.

Readability constraints: fog must be translucent and broad; bamboo highlights cannot resemble needle bullets; no small bright motes.

## stage_04_background_set

Target paths: `res://assets/backgrounds/stage4_tengu_mountain_path_far.png`, `stage4_tengu_mountain_path_mid.png`, `stage4_tengu_mountain_path_front.png`, `stage4_tengu_mountain_path_atmosphere.png`

Prompt: Global Prompt Prefix, tengu mountain path, blue-gray high-altitude wind, paper white accents, feather motifs, distant mountain air, crisp gaps for gameplay.

Readability constraints: feather and paper shapes stay large and subdued so they do not mimic talisman or needle bullets.

## stage_05_background_set

Target paths: `res://assets/backgrounds/stage5_oni_banquet_hall_far.png`, `stage5_oni_banquet_hall_mid.png`, `stage5_oni_banquet_hall_front.png`, `stage5_oni_banquet_hall_atmosphere.png`

Prompt: Global Prompt Prefix, oni banquet hall, deep reds, drum wood, oni fire, sake lacquer, heavy shadow bands, festival heat and rhythm.

Readability constraints: embers must be broad low-opacity streaks, not bullet-like dots; red fire must not hide red talisman bullets.

## stage_06_background_set

Target paths: `res://assets/backgrounds/stage6_night_festival_divine_realm_far.png`, `stage6_night_festival_divine_realm_mid.png`, `stage6_night_festival_divine_realm_front.png`, `stage6_night_festival_divine_realm_atmosphere.png`

Prompt: Global Prompt Prefix, divine night-festival realm, blue-black sky, endless lantern rivers, spirit fire, faith particles as broad painterly fields, final-stage scale and sacred pressure.

Readability constraints: faith particles must not be small bright bullet-like dots; lantern rivers sit behind gameplay with low contrast in active lanes.

## protagonist_mika_portrait

Target path: `res://assets/characters/protagonists/miko_portrait.png`

Prompt: Global Prompt Prefix, Mika original boundary shrine protagonist portrait, balanced and calm, red-white shrine-inspired clothing that is original, paper charms, lantern rim light, readable facial expression and fabric detail.

Readability constraints: portrait can be detailed, but motifs must not copy protected costumes or symbols.

## protagonist_mika_gameplay_sprite

Target path: `res://assets/characters/protagonists/miko_sprite_sheet.png`

Prompt: Global Prompt Prefix, Mika gameplay sprite sheet, small-scale boundary shrine protagonist, clean red-white silhouette, charm accents simplified, clear facing, animation-ready neutral and movement frames.

Readability constraints: strong outline at small size, no bullet-shaped ornaments, no red glow that hides red enemy bullets, transparent background required.

## protagonist_mika_shot_and_bomb

Target paths: `res://assets/effects/player/miko_shots.png`, `res://assets/effects/bombs/great_boundary_bloom.png`

Prompt: Global Prompt Prefix, Mika `Ofuda Trace`, `Yin-Yang Focus`, and `Great Boundary Bloom` player effects, boundary charms and rings, player-owned color language distinct from enemy talisman bullets.

Readability constraints: player effects must not be confused with enemy bullets; bomb bloom must clear visually without hiding remaining danger.

## protagonist_ren_assets

Target paths: `res://assets/characters/protagonists/magician_portrait.png`, `res://assets/characters/protagonists/magician_sprite_sheet.png`, `res://assets/effects/player/magician_shots.png`, `res://assets/effects/bombs/festival_master_spark.png`, `res://assets/endings/magician_ending.png`

Prompt: Global Prompt Prefix, Ren original festival spellcaster, dark cloth with gold and violet accents, star-dust tools, controlled lantern magic, `Stardust Spread`, `Magic Laser`, and `Festival Master Spark`.

Readability constraints: star effects must remain visibly player-owned and distinct from enemy star bullets; laser has clean lane edges and readable warning.

## protagonist_shiori_assets

Target paths: `res://assets/characters/protagonists/swordswoman_portrait.png`, `res://assets/characters/protagonists/swordswoman_sprite_sheet.png`, `res://assets/effects/player/swordswoman_shots.png`, `res://assets/effects/bombs/instant_slash_boundary.png`, `res://assets/endings/swordswoman_ending.png`

Prompt: Global Prompt Prefix, Shiori original half-yokai spirit-blade swordswoman, lean readable silhouette, blade wave motifs, green-cyan spirit edge light, `Sword Wave Fan`, `Returning Spirit Blades`, and `Instant Slash Boundary`.

Readability constraints: spirit blades must not resemble collectibles or needle bullets; slash bomb keeps enemy bullets visible after the clear pulse.

## boss_01a_aoi_assets

Target paths: `res://assets/characters/bosses/lantern_tsukumogami_portrait.png`, `res://assets/characters/bosses/lantern_tsukumogami_sprite.png`, `res://assets/ui/spell_backgrounds/lantern_tsukumogami.png`

Prompt: Global Prompt Prefix, Aoi original lantern tsukumogami midboss for shrine approach, friendly but mischievous lantern spirit, warm small-lantern theme.

Readability constraints: lantern glow stays broad, not bullet-like; sprite silhouette remains readable over Stage 1.

## boss_01b_madara_assets

Target paths: `res://assets/characters/bosses/festival_guide_fox_portrait.png`, `res://assets/characters/bosses/festival_guide_fox_sprite.png`, `res://assets/ui/spell_backgrounds/festival_guide_fox.png`

Prompt: Global Prompt Prefix, Madara original festival guide fox boss, shrine approach guide, paper butterfly and lantern motifs, confident fox silhouette.

Readability constraints: paper butterflies in spell art must not blend with enemy butterfly bullets.

## boss_02a_kirika_assets

Target paths: `res://assets/characters/bosses/abacus_tsukumogami_portrait.png`, `res://assets/characters/bosses/abacus_tsukumogami_sprite.png`, `res://assets/ui/spell_backgrounds/abacus_tsukumogami.png`

Prompt: Global Prompt Prefix, Kirika original abacus tsukumogami midboss, market beads and counting-frame motifs, antique tool spirit.

Readability constraints: abacus beads must not look like bullet rows; spell background uses large muted bead shapes only.

## boss_02b_yukari_assets

Target paths: `res://assets/characters/bosses/oni_market_leader_portrait.png`, `res://assets/characters/bosses/oni_market_leader_sprite.png`, `res://assets/ui/spell_backgrounds/oni_market_leader.png`

Prompt: Global Prompt Prefix, Yukari original oni market leader boss, trade banners, lacquer and coin motifs, assertive marketplace silhouette.

Readability constraints: coin highlights are broad decorative shapes, not point items or bullets.

## boss_03a_sena_assets

Target paths: `res://assets/characters/bosses/lost_rabbit_yokai_portrait.png`, `res://assets/characters/bosses/lost_rabbit_yokai_sprite.png`, `res://assets/ui/spell_backgrounds/lost_rabbit_yokai.png`

Prompt: Global Prompt Prefix, Sena original lost rabbit yokai midboss, bamboo fog, memory-path motif, soft moonlit palette.

Readability constraints: pale fog must not erase bullet silhouettes.

## boss_03b_oboro_assets

Target paths: `res://assets/characters/bosses/bamboo_illusionist_portrait.png`, `res://assets/characters/bosses/bamboo_illusionist_sprite.png`, `res://assets/ui/spell_backgrounds/bamboo_illusionist.png`

Prompt: Global Prompt Prefix, Oboro original bamboo illusionist boss, moonlit bamboo blades, mirrored fog, elegant illusion magic.

Readability constraints: bamboo blade motifs stay visually separate from needle bullets.

## boss_04a_hina_assets

Target paths: `res://assets/characters/bosses/rookie_crow_tengu_portrait.png`, `res://assets/characters/bosses/rookie_crow_tengu_sprite.png`, `res://assets/ui/spell_backgrounds/rookie_crow_tengu.png`

Prompt: Global Prompt Prefix, Hina original rookie crow tengu midboss, paper reports, small wing silhouette, nervous speed and wind.

Readability constraints: paper sheets cannot look like talisman bullets in active zones.

## boss_04b_kasumi_assets

Target paths: `res://assets/characters/bosses/mountain_wind_tengu_portrait.png`, `res://assets/characters/bosses/mountain_wind_tengu_sprite.png`, `res://assets/ui/spell_backgrounds/mountain_wind_tengu.png`

Prompt: Global Prompt Prefix, Kasumi original mountain wind tengu boss, commanding wind, blue-gray mountain light, feather and newspaper motifs.

Readability constraints: wind streaks stay behind bullet paths and never mask needle-speed threats.

## boss_05a_rei_assets

Target paths: `res://assets/characters/bosses/little_oni_drummer_portrait.png`, `res://assets/characters/bosses/little_oni_drummer_sprite.png`, `res://assets/ui/spell_backgrounds/little_oni_drummer.png`

Prompt: Global Prompt Prefix, Rei original little oni drummer midboss, festival drum, rhythmic pose, warm red hall light.

Readability constraints: drum sparks are broad and dim; do not mimic large_orb or red talisman bullets.

## boss_05b_tsukiko_assets

Target paths: `res://assets/characters/bosses/banquet_oni_princess_portrait.png`, `res://assets/characters/bosses/banquet_oni_princess_sprite.png`, `res://assets/ui/spell_backgrounds/banquet_oni_princess.png`

Prompt: Global Prompt Prefix, Tsukiko original banquet oni princess boss, lacquer cup, oni fire, confident banquet ruler, deep red and gold palette.

Readability constraints: red fire and lacquer shine must not hide enemy bullet rims.

## boss_06a_noa_assets

Target paths: `res://assets/characters/bosses/festival_fox_miko_portrait.png`, `res://assets/characters/bosses/festival_fox_miko_sprite.png`, `res://assets/ui/spell_backgrounds/festival_fox_miko.png`

Prompt: Global Prompt Prefix, Noa original festival fox miko midboss, divine eve of the night festival, fox fire, paper charms, sacred lantern glow.

Readability constraints: fox fire stays broad and readable as aura, not bullet clusters.

## boss_06b_astralis_assets

Target paths: `res://assets/characters/bosses/hyakki_night_festival_god_portrait.png`, `res://assets/characters/bosses/hyakki_night_festival_god_sprite.png`, `res://assets/ui/spell_backgrounds/hyakki_night_festival_god.png`

Prompt: Global Prompt Prefix, Astralis original Hyakki Night Festival god final boss, the festival elevated into divine existence through excitement, belief, memory, and yokai power, blue-black divine sky, endless lantern river, sacred final silhouette.

Readability constraints: divine particles must be broad, low contrast, and never bullet-like; final boss sprite remains readable against Stage 6.

## boss_06b_spell_aura

Target category: final boss spell aura and spell-card background treatment for `hyakki_night_festival_god`.

Prompt: Global Prompt Prefix, Astralis final spell aura, sacred lantern halo, blue-black and gold divine ring, broad spirit-fire arcs, centered boss aura with clear silhouette gap, production spell-card visual for an original night-festival danmaku game.

Readability constraints: no bullet-like background dots, no small bead rings, no dense foreground sparkles, aura stays behind the boss and below enemy bullets in visual priority.

## bullet_family_atlases

Target category: enemy bullet family atlases for `circle`, `rice`, `butterfly`, `needle`, `talisman`, `star`, `laser`, and `large_orb`.

Prompt: Global Prompt Prefix, clean enemy bullet sprites, family-specific silhouettes and colors, clear centers, crisp rims, readable collision expectation, transparent background.

Readability constraints: each family must be distinct at small size and over every stage background; no item-like sparkle on bullets.

## item_icons

Target category: item icons for `power`, `point`, `bomb_fragment`, `life_fragment`, `night_festival_seal`, and `full_power`.

Prompt: Global Prompt Prefix, collectible item icons with unique silhouettes, polished festival-token rendering, transparent background, readable at small gameplay size.

Readability constraints: items must look collectible, not dangerous; no round bullet silhouettes for fragments or seals.

## ui_key_art

Target category: title, menu, selection, pause, and spell announcement UI art.

Prompt: Global Prompt Prefix, restrained night-festival UI panels and key art, paper texture, lantern edge light, clean text-safe areas, original game identity.

Readability constraints: UI overlays must not cover hitbox or danger zones during active play; spell announcement art only enters during intended transition timing.
