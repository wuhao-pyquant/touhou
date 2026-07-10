#!/usr/bin/env python3
"""Build the deterministic Phase 6 asset manifest."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = ROOT / "assets" / "manifest" / "phase6_asset_manifest.json"
STATUS = "pending_generation"
VALID_STATUSES = {"pending_generation", "generated_needs_review", "accepted", "rejected"}

STAGES = {
    1: "shrine_approach",
    2: "yokai_market",
    3: "mist_bamboo_grove",
    4: "tengu_mountain_path",
    5: "oni_banquet_hall",
    6: "night_festival_divine_realm",
}

PROTAGONISTS = {
    "mika": "miko",
    "ren": "magician",
    "shiori": "swordswoman",
}

BOSSES = {
    "01a": "lantern_tsukumogami",
    "01b": "festival_guide_fox",
    "02a": "abacus_tsukumogami",
    "02b": "oni_market_leader",
    "03a": "lost_rabbit_yokai",
    "03b": "bamboo_illusionist",
    "04a": "rookie_crow_tengu",
    "04b": "mountain_wind_tengu",
    "05a": "little_oni_drummer",
    "05b": "banquet_oni_princess",
    "06a": "festival_fox_miko",
    "06b": "hyakki_night_festival_god",
}

BOSS_PROMPT_IDS = {
    "01a": "boss_01a_aoi_assets",
    "01b": "boss_01b_madara_assets",
    "02a": "boss_02a_kirika_assets",
    "02b": "boss_02b_yukari_assets",
    "03a": "boss_03a_sena_assets",
    "03b": "boss_03b_oboro_assets",
    "04a": "boss_04a_hina_assets",
    "04b": "boss_04b_kasumi_assets",
    "05a": "boss_05a_rei_assets",
    "05b": "boss_05b_tsukiko_assets",
    "06a": "boss_06a_noa_assets",
    "06b": "boss_06b_astralis_assets",
}

ENEMY_FAMILIES = [
    "enemy_low_yokai",
    "enemy_fast_attacker",
    "enemy_formation_shooter",
    "enemy_elite_yokai",
    "enemy_mechanism",
    "enemy_lantern_wisp",
    "enemy_market_tool",
    "enemy_festival_spirit",
]

ENEMY_BULLETS = [
    "enemy_bullet_lotus_core",
    "enemy_bullet_ember_needle",
    "enemy_bullet_mirror_drop",
    "enemy_bullet_clock_gear",
    "enemy_bullet_storm_arc",
    "enemy_bullet_moon_wisp",
    "enemy_bullet_astral_star",
    "enemy_bullet_warning_ring",
    "enemy_bullet_slow_orb",
    "enemy_bullet_fast_shard",
    "enemy_bullet_spiral_seed",
    "enemy_bullet_boss_sigil",
]

PLAYER_BULLETS = [
    "player_bullet_focus_lance",
    "player_bullet_spread_petal",
    "player_bullet_orbit_star",
    "player_bullet_homing_charm",
    "player_bullet_bomb_seed",
    "player_bullet_graze_spark",
]

ITEMS = [
    "item_power_small",
    "item_power_large",
    "item_score_small",
    "item_score_large",
    "item_life_fragment",
    "item_bomb_fragment",
    "item_full_power",
    "item_story_token",
]

UI_ASSETS = [
    ("ui_title_key_art", "title_key_art.png", 1280, 720),
    ("ui_main_menu_frame", "main_menu_frame.png", 720, 960),
    ("ui_character_select_frame", "character_select_frame.png", 720, 960),
    ("ui_pause_panel", "pause_panel.png", 720, 960),
    ("ui_spell_banner", "spell_banner.png", 720, 192),
    ("ui_boss_nameplate", "boss_nameplate.png", 512, 128),
    ("ui_dialogue_panel", "dialogue_panel.png", 720, 220),
    ("ui_result_frame", "result_frame.png", 720, 960),
]


def entry(
    asset_id: str,
    category: str,
    role: str,
    final_path: str,
    width: int,
    height: int,
    transparent: bool,
    readability_role: str,
    prompt_id: str,
    **extra: object,
) -> dict[str, object]:
    data: dict[str, object] = {
        "id": asset_id,
        "category": category,
        "role": role,
        "final_path": final_path,
        "source_path": source_path(category, asset_id),
        "width": width,
        "height": height,
        "transparent": transparent,
        "readability_role": readability_role,
        "status": STATUS,
        "prompt_id": prompt_id,
    }
    data.update(extra)
    return data


def source_path(category: str, asset_id: str) -> str:
    source_category = {
        "background": "backgrounds",
        "boss": "bosses",
        "bullet": "bullets",
        "enemy": "enemies",
        "item": "items",
        "protagonist": "protagonists",
        "style": "style",
        "ui": "ui",
    }.get(category, category)
    return "res://assets/source/phase6/%s/%s_source.png" % (source_category, asset_id)


def build_manifest() -> dict[str, object]:
    assets: list[dict[str, object]] = []

    assets.append(
        entry(
            "style_reference_night_festival",
            "style",
            "style_reference",
            "res://assets/source/phase6/style/night_festival_style_reference.png",
            1536,
            1024,
            False,
            "visual anchor for the original night-festival danmaku style and readability baseline",
            "style_reference_night_festival",
        )
    )

    for stage, stage_name in STAGES.items():
        for layer in ["far", "mid", "near", "spell"]:
            if stage == 1:
                prompt_id = {
                    "far": "stage_01_background_far",
                    "mid": "stage_01_background_mid",
                    "near": "stage_01_background_front",
                    "spell": "stage_01_background_atmosphere",
                }[layer]
            else:
                prompt_id = "stage_%02d_background_set" % stage
            assets.append(
                entry(
                    "stage_%02d_background_%s" % (stage, layer),
                    "background",
                    "%s_layer" % layer,
                    "res://assets/backgrounds/stage_%02d/%s.png" % (stage, layer),
                    720,
                    960,
                    False,
                    "low-contrast layer behind gameplay; no bullet-like dots or active-lane clutter",
                    prompt_id,
                    stage=stage,
                    stage_id=stage_name,
                )
            )

    for hero_name, runtime_id in PROTAGONISTS.items():
        assets.extend(
            [
                entry(
                    "protagonist_%s_gameplay_sprite" % hero_name,
                    "protagonist",
                    "gameplay_sprite",
                    protagonist_path(runtime_id, "sprite_sheet.png"),
                    384,
                    384,
                    True,
                    "small readable player silhouette that cannot mimic enemy bullets or item drops",
                    "protagonist_%s_gameplay_sprite" % hero_name if hero_name == "mika" else "protagonist_%s_assets" % hero_name,
                    protagonist_id=runtime_id,
                ),
                entry(
                    "protagonist_%s_portrait" % hero_name,
                    "protagonist",
                    "portrait",
                    protagonist_path(runtime_id, "portrait.png"),
                    512,
                    768,
                    True,
                    "character portrait with original motifs and clear UI/dialogue recognition",
                    "protagonist_%s_portrait" % hero_name if hero_name == "mika" else "protagonist_%s_assets" % hero_name,
                    protagonist_id=runtime_id,
                ),
                entry(
                    "protagonist_%s_focus_effects" % hero_name,
                    "protagonist",
                    "focus_effects",
                    "res://assets/effects/player/%s_focus_effects.png" % runtime_id,
                    512,
                    512,
                    True,
                    "player-owned option and focus effects distinct from hostile bullets and collectibles",
                    "protagonist_%s_shot_and_bomb" % hero_name if hero_name == "mika" else "protagonist_%s_assets" % hero_name,
                    protagonist_id=runtime_id,
                ),
            ]
        )

    for boss_code, runtime_id in BOSSES.items():
        assets.extend(
            [
                entry(
                    "boss_%s_gameplay_sprite" % boss_code,
                    "boss",
                    "gameplay_sprite",
                    "res://assets/characters/bosses/%s_sprite.png" % runtime_id,
                    512,
                    512,
                    True,
                    "boss sprite silhouette remains readable and never hides live bullet shapes",
                    BOSS_PROMPT_IDS[boss_code],
                    boss_id=runtime_id,
                ),
                entry(
                    "boss_%s_portrait" % boss_code,
                    "boss",
                    "portrait",
                    "res://assets/characters/bosses/%s_portrait.png" % runtime_id,
                    768,
                    1024,
                    True,
                    "boss portrait supports story and spell-card UI without protected likenesses",
                    BOSS_PROMPT_IDS[boss_code],
                    boss_id=runtime_id,
                ),
                entry(
                    "boss_%s_spell_aura" % boss_code,
                    "boss",
                    "spell_aura",
                    "res://assets/effects/boss/%s_spell_aura.png" % runtime_id,
                    720,
                    720,
                    True,
                    "spell aura stays behind boss and below enemy bullets in visual priority",
                    "boss_%s_spell_aura" % boss_code if boss_code == "06b" else BOSS_PROMPT_IDS[boss_code],
                    boss_id=runtime_id,
                ),
            ]
        )

    for family_id in ENEMY_FAMILIES:
        assets.append(
            entry(
                family_id,
                "enemy",
                "enemy_family_sprite",
                "res://assets/enemies/%s.png" % family_id,
                256,
                256,
                True,
                "enemy family silhouette is distinct from bullets, items, and player-owned effects",
                "enemy_family_sprites",
            )
        )

    for bullet_id in ENEMY_BULLETS + PLAYER_BULLETS:
        assets.append(
            entry(
                bullet_id,
                "bullet",
                "enemy_bullet_family" if bullet_id.startswith("enemy_") else "player_bullet_family",
                "res://assets/effects/bullets/%s.png" % bullet_id,
                128,
                128,
                True,
                "projectile family keeps clean center, crisp rim, and readable collision expectation",
                "bullet_family_atlases",
            )
        )

    for protagonist in PROTAGONISTS.values():
        for plate in ["start", "sustain", "finish"]:
            assets.append(
                entry(
                    "bomb_%s_%s_plate" % (protagonist, plate),
                    "bomb",
                    "bomb_%s_plate" % plate,
                    "res://assets/effects/bombs/%s_%s_plate.png" % (protagonist, plate),
                    720,
                    960,
                    True,
                    "bomb plate reads as player-owned and does not obscure post-clear danger visibility",
                    "protagonist_mika_shot_and_bomb" if protagonist == "miko" else "protagonist_%s_assets" % ("ren" if protagonist == "magician" else "shiori"),
                    protagonist_id=protagonist,
                )
            )

    for item_id in ITEMS:
        assets.append(
            entry(
                item_id,
                "item",
                "collectible_icon",
                "res://assets/items/%s.png" % item_id,
                128,
                128,
                True,
                "collectible icon silhouette remains distinct from every hostile bullet family",
                "item_icons",
            )
        )

    for asset_id, filename, width, height in UI_ASSETS:
        assets.append(
            entry(
                asset_id,
                "ui",
                "ui_key_art",
                "res://assets/ui/%s" % filename,
                width,
                height,
                True,
                "UI art preserves text-safe areas, hitbox visibility, and active danger clarity",
                "ui_key_art",
            )
        )

    manifest = {"version": 1, "assets": assets}
    preserve_existing_statuses(manifest, load_existing_statuses())
    return manifest


def load_existing_statuses() -> dict[str, str]:
    if not MANIFEST_PATH.exists():
        return {}
    try:
        with MANIFEST_PATH.open("r", encoding="utf-8") as manifest_file:
            existing = json.load(manifest_file)
    except (OSError, json.JSONDecodeError):
        return {}
    statuses: dict[str, str] = {}
    for asset in existing.get("assets", []):
        if not isinstance(asset, dict):
            continue
        asset_id = str(asset.get("id", ""))
        status = str(asset.get("status", ""))
        if asset_id and status in VALID_STATUSES:
            statuses[asset_id] = status
    return statuses


def preserve_existing_statuses(manifest: dict[str, object], statuses: dict[str, str]) -> None:
    if not statuses:
        return
    assets = manifest.get("assets", [])
    if not isinstance(assets, list):
        return
    for asset in assets:
        if isinstance(asset, dict) and str(asset.get("id", "")) in statuses:
            asset["status"] = statuses[str(asset["id"])]


def protagonist_path(runtime_id: str, filename: str) -> str:
    return "res://assets/characters/protagonists/%s_%s" % (runtime_id, filename)


def main() -> None:
    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
    manifest = build_manifest()
    with MANIFEST_PATH.open("w", encoding="utf-8") as manifest_file:
        json.dump(manifest, manifest_file, indent=2, ensure_ascii=False)
        manifest_file.write("\n")


if __name__ == "__main__":
    main()
