# Phase 6 Asset Prompt Matrix

Use this matrix as the source language for Phase 6 generation. Each asset block follows the same schema: `Target`, `Gameplay role`, `Positive prompt`, `Negative prompt`, `Readability constraints`, and `Review composite`.

Global positive language: hand-painted Japanese night-festival fantasy for an original night-festival danmaku game, production game asset, painterly anime rendering, lantern-lit atmosphere, clean gameplay silhouettes, original character and setting design.

Global negative language: no copyrighted Touhou character, no protected character likeness, no exact costume from existing games, no protected names, no logos, no music references, no unreadable silhouettes, no muddy low-contrast gameplay shapes.

## stage_01_background_far

Target: `res://assets/backgrounds/stage1_shrine_approach_far.png`
Gameplay role: Far background layer for Stage 1 `shrine_approach`.
Positive prompt: Global positive language, warm shrine lanterns and approachable reds under early-night blue shadows, distant shrine road, soft tree masses, lantern glow as broad painted pools, low detail and low contrast in the active playfield.
Negative prompt: Global negative language, no bullet-like background dots, no bead strings, no tiny star particles, no bright confetti, no high-contrast foreground clutter.
Readability constraints: Keep detail soft and broad so bullets, items, enemies, and the player sprite own the sharpest contrast.
Review composite: Test with circle, rice, talisman, star, item, player, and boss overlays at 720x960.

## stage_01_background_mid

Target: `res://assets/backgrounds/stage1_shrine_approach_mid.png`
Gameplay role: Mid background identity layer for Stage 1.
Positive prompt: Global positive language, painted shrine approach with torii silhouettes, paper charms, warm lantern stands, readable depth bands, festival invitation mood.
Negative prompt: Global negative language, no bullet-like background dots, no bead strings, no sharp charm clusters, no tiny lantern flames in active lanes.
Readability constraints: Keep small charms and lantern flames broad, dimmed, and away from bullet lanes.
Review composite: Test under dense Stage 1 bullet patterns and collectible item drops.

## stage_01_background_front

Target: `res://assets/backgrounds/stage1_shrine_approach_front.png`
Gameplay role: Front framing layer for Stage 1.
Positive prompt: Global positive language, soft shrine eaves, rope, leaves, and lantern edges placed outside active lanes.
Negative prompt: Global negative language, no active-lane clutter, no bright small shapes, no hard foreground occlusion.
Readability constraints: Frame only; never cover the player route, hitbox area, bullets, or items.
Review composite: Test with player movement from bottom center to side lanes and confirm no route obstruction.

## stage_01_background_atmosphere

Target: `res://assets/backgrounds/stage1_shrine_approach_atmosphere.png`
Gameplay role: Transparent atmosphere overlay for Stage 1.
Positive prompt: Global positive language, warm lantern haze and broad drifting paper glow for Stage 1.
Negative prompt: Global negative language, no bullet-like background dots, no small paper flecks, no opaque glow clusters.
Readability constraints: Use large soft forms only, low opacity, and no shapes that resemble bullets or items.
Review composite: Test over Stage 1 far and mid layers with dense bullets active.

## stage_02_background_set

Target: `res://assets/backgrounds/stage2_yokai_market_far.png`, `stage2_yokai_market_mid.png`, `stage2_yokai_market_front.png`, `stage2_yokai_market_atmosphere.png`
Gameplay role: Layered Stage 2 `yokai_market` background set.
Positive prompt: Global positive language, yokai market with gold stall light, masks, coin highlights, tool motifs, lively but readable market depth; far layer broad roofs and lights, mid layer stalls and signs, front layer edge framing, atmosphere warm steam and glow.
Negative prompt: Global negative language, no coin-sized bullet-like highlights, no bright bead rows, no clutter in active lanes, no item-like sparkles.
Readability constraints: Coin highlights must be large and dim, active lanes stay uncluttered, and market motion reads behind gameplay.
Review composite: Test all layers together under score-item drops and circle/rice bullet density.

## stage_03_background_set

Target: `res://assets/backgrounds/stage3_mist_bamboo_grove_far.png`, `stage3_mist_bamboo_grove_mid.png`, `stage3_mist_bamboo_grove_front.png`, `stage3_mist_bamboo_grove_atmosphere.png`
Gameplay role: Layered Stage 3 `mist_bamboo_grove` background set.
Positive prompt: Global positive language, cool moonlit blues, bamboo greens, layered fog, wrong-path atmosphere, hand-painted depth.
Negative prompt: Global negative language, no small bright motes, no needle-like bamboo highlights in active lanes, no opaque fog walls.
Readability constraints: Fog must be translucent and broad; bamboo highlights cannot resemble needle bullets.
Review composite: Test with needle, laser, and cyan rice bullet patterns over fog-heavy moments.

## stage_04_background_set

Target: `res://assets/backgrounds/stage4_tengu_mountain_path_far.png`, `stage4_tengu_mountain_path_mid.png`, `stage4_tengu_mountain_path_front.png`, `stage4_tengu_mountain_path_atmosphere.png`
Gameplay role: Layered Stage 4 `tengu_mountain_path` background set.
Positive prompt: Global positive language, blue-gray high-altitude wind, paper white accents, feather motifs, distant mountain air, crisp gaps for gameplay.
Negative prompt: Global negative language, no talisman-like paper clutter, no needle-like feather streaks in active lanes, no high-contrast storm particles.
Readability constraints: Feather and paper shapes stay large and subdued so they do not mimic talisman or needle bullets.
Review composite: Test with fast needle threats and talisman patterns across the full playfield.

## stage_05_background_set

Target: `res://assets/backgrounds/stage5_oni_banquet_hall_far.png`, `stage5_oni_banquet_hall_mid.png`, `stage5_oni_banquet_hall_front.png`, `stage5_oni_banquet_hall_atmosphere.png`
Gameplay role: Layered Stage 5 `oni_banquet_hall` background set.
Positive prompt: Global positive language, deep reds, drum wood, oni fire, sake lacquer, heavy shadow bands, festival heat and rhythm.
Negative prompt: Global negative language, no ember dots, no orb-like fire beads, no red clutter that hides talisman bullets, no glossy item-like sparkles.
Readability constraints: Embers must be broad low-opacity streaks; red fire must not hide red talisman bullets.
Review composite: Test against red talisman bullets, large_orb bullets, and boss silhouettes.

## stage_06_background_set

Target: `res://assets/backgrounds/stage6_night_festival_divine_realm_far.png`, `stage6_night_festival_divine_realm_mid.png`, `stage6_night_festival_divine_realm_front.png`, `stage6_night_festival_divine_realm_atmosphere.png`
Gameplay role: Layered Stage 6 `night_festival_divine_realm` background set.
Positive prompt: Global positive language, divine blue-black sky, endless lantern rivers, spirit fire, faith particles as broad painterly fields, final-stage scale and sacred pressure.
Negative prompt: Global negative language, no small bright faith dots, no bead rings, no star fields, no high-contrast lantern specks in active lanes.
Readability constraints: Faith particles must not be small bright bullet-like dots; lantern rivers sit behind gameplay with low contrast in active lanes.
Review composite: Test with final-boss dense mixed bullet families and spell-card UI overlays.

## protagonist_mika_portrait

Target: `res://assets/characters/protagonists/miko_portrait.png`
Gameplay role: Mika selection, dialogue, and ending portrait.
Positive prompt: Global positive language, Mika original boundary shrine protagonist portrait, balanced and calm, red-white shrine-inspired clothing that is original, paper charms, lantern rim light, readable facial expression and fabric detail.
Negative prompt: Global negative language, no protected shrine-maiden likeness, no exact costume, no copied symbols, no bullet-like charm decoration.
Readability constraints: Portrait can be detailed, but motifs must remain original and support quick character recognition.
Review composite: Test in character-select, dialogue, and ending layouts with UI text.

## protagonist_mika_gameplay_sprite

Target: `res://assets/characters/protagonists/miko_sprite_sheet.png`
Gameplay role: Mika player gameplay sprite sheet.
Positive prompt: Global positive language, Mika gameplay sprite sheet, small-scale boundary shrine protagonist, clean red-white silhouette, charm accents simplified, clear facing, animation-ready neutral and movement frames, transparent background.
Negative prompt: Global negative language, no protected shrine-maiden likeness, no bullet-shaped ornaments, no noisy halo, no red glow that hides red enemy bullets.
Readability constraints: Strong outline at small size, clear facing, no decorations that mimic enemy bullets or collectibles.
Review composite: Test over all six stage backgrounds with enemy bullets, player shots, and item drops.

## protagonist_mika_shot_and_bomb

Target: `res://assets/effects/player/miko_shots.png`, `res://assets/effects/bombs/great_boundary_bloom.png`
Gameplay role: Mika player shots and bomb effect.
Positive prompt: Global positive language, Mika `Ofuda Trace`, `Yin-Yang Focus`, and `Great Boundary Bloom` player effects, boundary charms and rings, player-owned color language distinct from enemy talisman bullets.
Negative prompt: Global negative language, no enemy-bullet silhouettes, no talisman-bullet confusion, no full-screen opaque flash, no protected spell names.
Readability constraints: Player effects must not be confused with enemy bullets; bomb bloom must clear visually without hiding remaining danger.
Review composite: Test during active enemy talisman patterns and post-bomb clear timing.

## protagonist_ren_assets

Target: `res://assets/characters/protagonists/magician_portrait.png`, `res://assets/characters/protagonists/magician_sprite_sheet.png`, `res://assets/effects/player/magician_shots.png`, `res://assets/effects/bombs/lantern_comet_cascade.png`, `res://assets/endings/magician_ending.png`
Gameplay role: Ren portrait, gameplay sprite, player shots, bomb, and ending art.
Positive prompt: Global positive language, Ren original festival spellcaster, dark cloth with gold and violet accents, star-dust tools, controlled lantern magic, `Stardust Spread`, `Magic Laser`, and `Lantern Comet Cascade`.
Negative prompt: Global negative language, no protected magician likeness, no exact costume, no protected spell names, no enemy star-bullet confusion, no opaque laser bloom.
Readability constraints: Star effects must remain visibly player-owned and distinct from enemy star bullets; laser has clean lane edges and readable warning.
Review composite: Test Ren over all stage backgrounds with enemy star bullets, lasers, and bomb activation.

## protagonist_shiori_assets

Target: `res://assets/characters/protagonists/swordswoman_portrait.png`, `res://assets/characters/protagonists/swordswoman_sprite_sheet.png`, `res://assets/effects/player/swordswoman_shots.png`, `res://assets/effects/bombs/instant_slash_boundary.png`, `res://assets/endings/swordswoman_ending.png`
Gameplay role: Shiori portrait, gameplay sprite, player shots, bomb, and ending art.
Positive prompt: Global positive language, Shiori original half-yokai spirit-blade swordswoman, lean readable silhouette, blade wave motifs, green-cyan spirit edge light, `Sword Wave Fan`, `Returning Spirit Blades`, and `Instant Slash Boundary`.
Negative prompt: Global negative language, no protected swordswoman likeness, no exact costume, no collectible-like spirit gems, no needle-bullet confusion.
Readability constraints: Spirit blades must not resemble collectibles or needle bullets; slash bomb keeps enemy bullets visible after the clear pulse.
Review composite: Test during dense item collection, needle patterns, and bomb clear timing.

## boss_01a_aoi_assets

Target: `res://assets/characters/bosses/lantern_tsukumogami_portrait.png`, `res://assets/characters/bosses/lantern_tsukumogami_sprite.png`, `res://assets/ui/spell_backgrounds/lantern_tsukumogami.png`
Gameplay role: Aoi Stage 1 midboss portrait, sprite, and spell background.
Positive prompt: Global positive language, Aoi original lantern tsukumogami midboss for shrine approach, friendly but mischievous lantern spirit, warm small-lantern theme.
Negative prompt: Global negative language, no protected character likeness, no bullet-like lantern beads, no tiny spark clusters, no exact copied symbols.
Readability constraints: Lantern glow stays broad, not bullet-like; sprite silhouette remains readable over Stage 1.
Review composite: Test against Stage 1 background layers and early circle/rice bullet patterns.

## boss_01b_madara_assets

Target: `res://assets/characters/bosses/festival_guide_fox_portrait.png`, `res://assets/characters/bosses/festival_guide_fox_sprite.png`, `res://assets/ui/spell_backgrounds/festival_guide_fox.png`
Gameplay role: Madara Stage 1 boss portrait, sprite, and spell background.
Positive prompt: Global positive language, Madara original festival guide fox boss, shrine approach guide, paper butterfly and lantern motifs, confident fox silhouette.
Negative prompt: Global negative language, no protected fox-character likeness, no copied costume, no enemy-bullet-like paper butterflies, no bead strings.
Readability constraints: Paper butterflies in spell art must not blend with enemy butterfly bullets.
Review composite: Test with butterfly bullet patterns and spell announcement UI.

## boss_02a_kirika_assets

Target: `res://assets/characters/bosses/abacus_tsukumogami_portrait.png`, `res://assets/characters/bosses/abacus_tsukumogami_sprite.png`, `res://assets/ui/spell_backgrounds/abacus_tsukumogami.png`
Gameplay role: Kirika Stage 2 midboss portrait, sprite, and spell background.
Positive prompt: Global positive language, Kirika original abacus tsukumogami midboss, market beads and counting-frame motifs, antique tool spirit.
Negative prompt: Global negative language, no bullet-row beads, no item-like coin sparkle, no protected likeness, no copied symbols.
Readability constraints: Abacus beads must not look like bullet rows; spell background uses large muted bead shapes only.
Review composite: Test over Stage 2 market layers with rowed bullet patterns and score items.

## boss_02b_yukari_assets

Target: `res://assets/characters/bosses/oni_market_leader_portrait.png`, `res://assets/characters/bosses/oni_market_leader_sprite.png`, `res://assets/ui/spell_backgrounds/oni_market_leader.png`
Gameplay role: Yukari Stage 2 boss portrait, sprite, and spell background.
Positive prompt: Global positive language, Yukari original oni market leader boss, trade banners, lacquer and coin motifs, assertive marketplace silhouette.
Negative prompt: Global negative language, no protected oni likeness, no item-like coin clusters, no orb-like highlights, no exact copied costume.
Readability constraints: Coin highlights are broad decorative shapes, not point items or bullets.
Review composite: Test with point items, large_orb bullets, and Stage 2 market backgrounds.

## boss_03a_sena_assets

Target: `res://assets/characters/bosses/lost_rabbit_yokai_portrait.png`, `res://assets/characters/bosses/lost_rabbit_yokai_sprite.png`, `res://assets/ui/spell_backgrounds/lost_rabbit_yokai.png`
Gameplay role: Sena Stage 3 midboss portrait, sprite, and spell background.
Positive prompt: Global positive language, Sena original lost rabbit yokai midboss, bamboo fog, memory-path motif, soft moonlit palette.
Negative prompt: Global negative language, no protected rabbit-character likeness, no small moon motes, no fog that erases bullet edges, no copied costume.
Readability constraints: Pale fog must not erase bullet silhouettes.
Review composite: Test with cyan rice bullets, moonlit fog layers, and player sprite overlap.

## boss_03b_oboro_assets

Target: `res://assets/characters/bosses/bamboo_illusionist_portrait.png`, `res://assets/characters/bosses/bamboo_illusionist_sprite.png`, `res://assets/ui/spell_backgrounds/bamboo_illusionist.png`
Gameplay role: Oboro Stage 3 boss portrait, sprite, and spell background.
Positive prompt: Global positive language, Oboro original bamboo illusionist boss, moonlit bamboo blades, mirrored fog, elegant illusion magic.
Negative prompt: Global negative language, no needle-bullet-like bamboo shards, no protected likeness, no copied costume, no dense spark veil.
Readability constraints: Bamboo blade motifs stay visually separate from needle bullets.
Review composite: Test with needle bullets, lasers, and Stage 3 fog-heavy composites.

## boss_04a_hina_assets

Target: `res://assets/characters/bosses/rookie_crow_tengu_portrait.png`, `res://assets/characters/bosses/rookie_crow_tengu_sprite.png`, `res://assets/ui/spell_backgrounds/rookie_crow_tengu.png`
Gameplay role: Hina Stage 4 midboss portrait, sprite, and spell background.
Positive prompt: Global positive language, Hina original rookie crow tengu midboss, paper reports, small wing silhouette, nervous speed and wind.
Negative prompt: Global negative language, no protected crow-tengu likeness, no talisman-like paper sheets in active zones, no copied symbols.
Readability constraints: Paper sheets cannot look like talisman bullets in active zones.
Review composite: Test with red talisman bullets and Stage 4 wind overlays.

## boss_04b_kasumi_assets

Target: `res://assets/characters/bosses/mountain_wind_tengu_portrait.png`, `res://assets/characters/bosses/mountain_wind_tengu_sprite.png`, `res://assets/ui/spell_backgrounds/mountain_wind_tengu.png`
Gameplay role: Kasumi Stage 4 boss portrait, sprite, and spell background.
Positive prompt: Global positive language, Kasumi original mountain wind tengu boss, commanding wind, blue-gray mountain light, feather and newspaper motifs.
Negative prompt: Global negative language, no protected tengu likeness, no needle-like wind streak clutter, no talisman-like newspaper strips, no copied costume.
Readability constraints: Wind streaks stay behind bullet paths and never mask needle-speed threats.
Review composite: Test with fast needle patterns, lasers, and Stage 4 paper-white accents.

## boss_05a_rei_assets

Target: `res://assets/characters/bosses/little_oni_drummer_portrait.png`, `res://assets/characters/bosses/little_oni_drummer_sprite.png`, `res://assets/ui/spell_backgrounds/little_oni_drummer.png`
Gameplay role: Rei Stage 5 midboss portrait, sprite, and spell background.
Positive prompt: Global positive language, Rei original little oni drummer midboss, festival drum, rhythmic pose, warm red hall light.
Negative prompt: Global negative language, no protected oni likeness, no orb-like drum sparks, no red talisman clutter, no copied costume.
Readability constraints: Drum sparks are broad and dim; do not mimic large_orb or red talisman bullets.
Review composite: Test with Stage 5 red palette, large_orb bullets, and talisman patterns.

## boss_05b_tsukiko_assets

Target: `res://assets/characters/bosses/banquet_oni_princess_portrait.png`, `res://assets/characters/bosses/banquet_oni_princess_sprite.png`, `res://assets/ui/spell_backgrounds/banquet_oni_princess.png`
Gameplay role: Tsukiko Stage 5 boss portrait, sprite, and spell background.
Positive prompt: Global positive language, Tsukiko original banquet oni princess boss, lacquer cup, oni fire, confident banquet ruler, deep red and gold palette.
Negative prompt: Global negative language, no protected oni-princess likeness, no orb-like fire beads, no item-like lacquer shine, no copied costume.
Readability constraints: Red fire and lacquer shine must not hide enemy bullet rims.
Review composite: Test with red talisman bullets, point items, and Stage 5 banquet backgrounds.

## boss_06a_noa_assets

Target: `res://assets/characters/bosses/festival_fox_miko_portrait.png`, `res://assets/characters/bosses/festival_fox_miko_sprite.png`, `res://assets/ui/spell_backgrounds/festival_fox_miko.png`
Gameplay role: Noa Stage 6 midboss portrait, sprite, and spell background.
Positive prompt: Global positive language, Noa original festival fox miko midboss, divine eve of the night festival, fox fire, paper charms, sacred lantern glow.
Negative prompt: Global negative language, no protected fox or shrine character likeness, no exact costume, no bullet-cluster fox fire, no copied symbols.
Readability constraints: Fox fire stays broad and readable as aura, not bullet clusters.
Review composite: Test with Stage 6 divine backgrounds, talisman bullets, and spell announcement UI.

## boss_06b_astralis_assets

Target: `res://assets/characters/bosses/hyakki_night_festival_god_portrait.png`, `res://assets/characters/bosses/hyakki_night_festival_god_sprite.png`, `res://assets/ui/spell_backgrounds/hyakki_night_festival_god.png`
Gameplay role: Astralis final boss portrait, sprite, and spell background.
Positive prompt: Global positive language, Astralis original Hyakki Night Festival god final boss, the festival elevated into divine existence through excitement, belief, memory, and yokai power, blue-black divine sky, endless lantern river, sacred final silhouette.
Negative prompt: Global negative language, no protected deity likeness, no small divine bead fields, no star fields, no copied symbols or costumes.
Readability constraints: Divine particles must be broad, low contrast, and never bullet-like; final boss sprite remains readable against Stage 6.
Review composite: Test with final boss mixed bullet families, player shots, and Stage 6 backgrounds.

## boss_06b_spell_aura

Target: Final boss spell aura and spell-card background treatment for `hyakki_night_festival_god`.
Gameplay role: Astralis final spell aura and spell-card visual support.
Positive prompt: Global positive language, Astralis final spell aura, sacred lantern halo, blue-black and gold divine ring, broad spirit-fire arcs, centered boss aura with clear silhouette gap, production spell-card visual.
Negative prompt: Global negative language, no bullet-like background dots, no small bead rings, no dense foreground sparkles, no protected spell names, no copied symbols.
Readability constraints: Aura stays behind the boss and below enemy bullets in visual priority; no small dots or rings that read as bullets.
Review composite: Test with Astralis sprite, Stage 6 background, final boss bullet density, and spell-card UI.

## bullet_family_atlases

Target: Enemy bullet family atlases for `circle`, `rice`, `butterfly`, `needle`, `talisman`, `star`, `laser`, and `large_orb`.
Gameplay role: Core enemy projectile visuals.
Positive prompt: Global positive language, clean enemy bullet sprites, family-specific silhouettes and colors, clear centers, crisp rims, readable collision expectation, transparent background.
Negative prompt: Global negative language, no item-like sparkle, no muddy rims, no unclear collision size, no background texture, no protected symbols.
Readability constraints: Each family must be distinct at small size and over every stage background.
Review composite: Test all bullet families over all stage background sets with player sprite and item icons visible.

## item_icons

Target: Item icons for `power`, `point`, `bomb_fragment`, `life_fragment`, `night_festival_seal`, and `full_power`.
Gameplay role: Collectible reward and resource icons.
Positive prompt: Global positive language, collectible item icons with unique silhouettes, polished festival-token rendering, transparent background, readable at small gameplay size.
Negative prompt: Global negative language, no dangerous bullet silhouettes, no round bullet-like fragments or seals, no enemy projectile glow, no protected symbols.
Readability constraints: Items must look collectible, not dangerous, and must remain distinct from all bullet families.
Review composite: Test item icons over dense bullet scenes across all stage palettes.

## ui_key_art

Target: Title, menu, selection, pause, and spell announcement UI art.
Gameplay role: Non-gameplay and transition UI visual system.
Positive prompt: Global positive language, restrained night-festival UI panels and key art, paper texture, lantern edge light, clean text-safe areas, original game identity.
Negative prompt: Global negative language, no unreadable text areas, no clutter behind active UI text, no protected logos, no copied symbols, no active-play obstruction.
Readability constraints: UI overlays must not cover hitbox or danger zones during active play; spell announcement art only enters during intended transition timing.
Review composite: Test title, character select, pause, and spell announcement states over representative stage backgrounds.
