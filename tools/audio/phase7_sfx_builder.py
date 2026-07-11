from __future__ import annotations

import hashlib
import html
import json
import math
import wave
from dataclasses import dataclass
from pathlib import Path

import numpy as np


SR = 44_100
ROOT = Path(__file__).resolve().parents[2]
STAGING_ROOT = Path(r"Z:\temp\godot_touhou_phase7")
SFX_DIR = STAGING_ROOT / "sfx_candidates"
MANIFEST_PATH = STAGING_ROOT / "reports" / "sfx_candidate_manifest.json"
REVIEW_PATH = Path(r"Z:\temp\godot_touhou_phase7\reports\sfx_review.html")
PEAK = 10.0 ** (-1.5 / 20.0)


@dataclass(frozen=True)
class Cue:
    key: str
    label: str
    category: str
    priority: str
    min_interval_ms: int
    duration: float
    recipe: str
    params: tuple[float, ...]
    loop: bool = False
    runtime_gain_db: float = 0.0


CUES = [
    Cue("shot_miko_ofuda", "巫女A·御札射击", "六种射击", "ambient", 45, 0.16, "shot", (1320, 780, 0.20, 0.04), runtime_gain_db=-8),
    Cue("shot_miko_orb", "巫女B·阴阳玉射击", "六种射击", "ambient", 55, 0.20, "shot", (860, 360, 0.32, 0.08), runtime_gain_db=-7),
    Cue("shot_magician_stardust", "魔法使A·星屑散射", "六种射击", "ambient", 45, 0.18, "chime", (1260, 1720, 0.16), runtime_gain_db=-9),
    Cue("shot_magician_laser", "魔法使B·魔导激光", "六种射击", "ambient", 70, 0.24, "shot", (620, 1480, 0.34, 0.03), runtime_gain_db=-7),
    Cue("shot_swordswoman_wave", "半妖剑士A·剑气扇", "六种射击", "ambient", 50, 0.19, "slash", (920, 0.20, 0.24), runtime_gain_db=-8),
    Cue("shot_swordswoman_blade", "半妖剑士B·回旋灵刃", "六种射击", "ambient", 60, 0.22, "slash", (1180, 0.14, 0.18), runtime_gain_db=-8),
    Cue("enemy_hit", "敌人命中", "战斗反馈", "ambient", 35, 0.10, "impact", (420, 0.18, 0.30), runtime_gain_db=-9),
    Cue("boss_hit", "Boss命中", "战斗反馈", "gameplay", 55, 0.14, "impact", (260, 0.30, 0.22), runtime_gain_db=-7),
    Cue("enemy_defeat", "敌人击破", "战斗反馈", "ambient", 65, 0.28, "burst", (620, 220, 0.28), runtime_gain_db=-6),
    Cue("boss_phase_clear", "Boss阶段击破", "战斗反馈", "gameplay", 120, 0.72, "burst", (360, 86, 0.46), runtime_gain_db=-3),
    Cue("graze", "擦弹", "战斗反馈", "gameplay", 45, 0.11, "chime", (1840, 2320, 0.10), runtime_gain_db=-8),
    Cue("item_collect", "道具收集", "资源反馈", "gameplay", 55, 0.16, "chime", (980, 1480, 0.14), runtime_gain_db=-6),
    Cue("life_gain", "残机增加", "资源反馈", "critical", 250, 0.85, "reward", (740, 988, 1318), runtime_gain_db=-2),
    Cue("bomb_gain", "炸弹增加", "资源反馈", "critical", 250, 0.64, "reward", (620, 830, 1108), runtime_gain_db=-3),
    Cue("bomb_miko_start", "巫女炸弹·展开", "三角色炸弹", "critical", 120, 0.48, "bomb", (520, 920, 0), runtime_gain_db=-2),
    Cue("bomb_miko_loop", "巫女炸弹·持续", "三角色炸弹", "critical", 0, 1.20, "loop", (220, 330, 0.16), loop=True, runtime_gain_db=-5),
    Cue("bomb_miko_finish", "巫女炸弹·收束", "三角色炸弹", "critical", 120, 0.52, "bomb", (960, 420, 1), runtime_gain_db=-2),
    Cue("bomb_magician_start", "魔法使炸弹·展开", "三角色炸弹", "critical", 120, 0.42, "bomb", (440, 1480, 0), runtime_gain_db=-1),
    Cue("bomb_magician_loop", "魔法使炸弹·持续", "三角色炸弹", "critical", 0, 1.20, "loop", (310, 620, 0.22), loop=True, runtime_gain_db=-4),
    Cue("bomb_magician_finish", "魔法使炸弹·收束", "三角色炸弹", "critical", 120, 0.64, "bomb", (1320, 180, 1), runtime_gain_db=-1),
    Cue("bomb_swordswoman_start", "半妖剑士炸弹·展开", "三角色炸弹", "critical", 120, 0.32, "slash", (1480, 0.30, 0.34), runtime_gain_db=-1),
    Cue("bomb_swordswoman_loop", "半妖剑士炸弹·持续", "三角色炸弹", "critical", 0, 1.00, "loop", (280, 560, 0.14), loop=True, runtime_gain_db=-5),
    Cue("bomb_swordswoman_finish", "半妖剑士炸弹·收束", "三角色炸弹", "critical", 120, 0.46, "slash", (760, 0.42, 0.42), runtime_gain_db=-1),
    Cue("menu_move", "菜单移动", "菜单", "gameplay", 70, 0.08, "ui", (760, 860), runtime_gain_db=-8),
    Cue("menu_confirm", "菜单确认", "菜单", "gameplay", 120, 0.15, "ui", (920, 1380), runtime_gain_db=-5),
    Cue("menu_back", "菜单返回", "菜单", "gameplay", 120, 0.14, "ui", (820, 520), runtime_gain_db=-6),
    Cue("pause", "暂停", "菜单", "critical", 180, 0.24, "ui", (480, 240), runtime_gain_db=-4),
    Cue("spell_announce", "符卡宣言", "警告与宣言", "critical", 250, 0.90, "announce", (196, 784, 1175), runtime_gain_db=-2),
    Cue("laser_warning", "激光警告", "警告与宣言", "critical", 350, 0.72, "warning", (880, 1320, 3), runtime_gain_db=-1),
    Cue("laser_activate", "激光启动", "警告与宣言", "gameplay", 180, 0.38, "shot", (220, 1280, 0.48, 0.12), runtime_gain_db=-3),
    Cue("player_hit", "玩家被弹", "危险反馈", "critical", 350, 0.52, "danger", (180, 72, 0.48), runtime_gain_db=0),
    Cue("deathbomb_window", "决死结界窗口", "危险反馈", "critical", 350, 0.32, "warning", (1480, 1960, 2), runtime_gain_db=-1),
]


def _time(duration: float) -> np.ndarray:
    return np.arange(int(round(duration * SR)), dtype=np.float64) / SR


def _fade(signal: np.ndarray, attack: float = 0.003, release: float = 0.05) -> np.ndarray:
    count = signal.shape[0]
    attack_count = min(count, max(1, int(round(attack * SR))))
    release_count = min(count, max(1, int(round(release * SR))))
    envelope = np.ones(count, dtype=np.float64)
    envelope[:attack_count] *= np.sin(np.linspace(0, math.pi / 2, attack_count)) ** 2
    envelope[-release_count:] *= np.cos(np.linspace(0, math.pi / 2, release_count)) ** 2
    return signal * envelope


def _sweep(t: np.ndarray, start: float, end: float) -> np.ndarray:
    frequency = start + (end - start) * np.clip(t / max(t[-1], 1.0 / SR), 0, 1)
    phase = 2 * math.pi * np.cumsum(frequency) / SR
    return np.sin(phase)


def _noise(rng: np.random.Generator, count: int) -> np.ndarray:
    raw = rng.normal(0, 1, count)
    return np.convolve(raw, np.ones(5) / 5.0, mode="same")


def _render(cue: Cue) -> np.ndarray:
    rng = np.random.default_rng(int(hashlib.sha256(cue.key.encode()).hexdigest()[:8], 16))
    t = _time(cue.duration)
    p = cue.params
    if cue.recipe == "shot":
        body = _sweep(t, p[0], p[1]) * np.exp(-t / p[2])
        body += _noise(rng, len(t)) * np.exp(-t / max(p[3], 0.01)) * 0.22
    elif cue.recipe == "chime":
        body = (np.sin(2 * math.pi * p[0] * t) + 0.55 * np.sin(2 * math.pi * p[1] * t)) * np.exp(-t / p[2])
    elif cue.recipe == "slash":
        body = _noise(rng, len(t)) * np.exp(-t / p[1])
        body += _sweep(t, p[0] * 1.6, p[0] * 0.45) * np.exp(-t / p[2]) * 0.42
    elif cue.recipe == "impact":
        body = _sweep(t, p[0] * 1.8, p[0]) * np.exp(-t / p[1])
        body += _noise(rng, len(t)) * np.exp(-t / p[2]) * 0.55
    elif cue.recipe == "burst":
        body = _sweep(t, p[0], p[1]) * np.exp(-t / p[2])
        body += _noise(rng, len(t)) * np.exp(-t / (p[2] * 0.65)) * 0.62
        body += np.sin(2 * math.pi * p[1] * t) * np.exp(-t / (p[2] * 1.4)) * 0.38
    elif cue.recipe == "reward":
        body = np.zeros_like(t)
        for index, frequency in enumerate(p):
            start = int(index * 0.16 * SR)
            local = t[: len(t) - start]
            body[start:] += np.sin(2 * math.pi * frequency * local) * np.exp(-local / 0.24)
    elif cue.recipe == "bomb":
        direction = 1 if p[2] < 0.5 else -1
        start, end = (p[0], p[1]) if direction > 0 else (p[0], p[1])
        body = _sweep(t, start, end) * np.exp(-t / (cue.duration * 0.72))
        body += _noise(rng, len(t)) * np.exp(-t / (cue.duration * 0.38)) * 0.5
        body += np.sin(2 * math.pi * 73 * t) * np.exp(-t / cue.duration) * 0.34
    elif cue.recipe == "loop":
        phase = 2 * math.pi * p[0] * t + 0.4 * np.sin(2 * math.pi * 2 * t)
        body = np.sin(phase) * 0.45 + np.sin(2 * math.pi * p[1] * t) * 0.22
        body += np.sin(2 * math.pi * (p[0] * 0.5) * t) * p[2]
    elif cue.recipe == "ui":
        body = _sweep(t, p[0], p[1]) * np.exp(-t / max(0.04, cue.duration * 0.42))
    elif cue.recipe == "announce":
        body = np.zeros_like(t)
        for index, frequency in enumerate(p):
            local = np.maximum(0, t - index * 0.14)
            active = t >= index * 0.14
            body += active * np.sin(2 * math.pi * frequency * local) * np.exp(-local / 0.34)
        body += _noise(rng, len(t)) * np.exp(-t / 0.16) * 0.28
    elif cue.recipe == "warning":
        pulse_rate = p[2] / cue.duration
        pulse = (np.sin(2 * math.pi * pulse_rate * t) > 0).astype(np.float64)
        body = (np.sin(2 * math.pi * p[0] * t) + 0.45 * np.sin(2 * math.pi * p[1] * t)) * pulse
        body *= 0.55 + 0.45 * (t / cue.duration)
    elif cue.recipe == "danger":
        body = _sweep(t, p[0], p[1]) * np.exp(-t / p[2])
        body += _noise(rng, len(t)) * np.exp(-t / 0.12) * 0.7
    else:
        raise ValueError(f"unknown recipe: {cue.recipe}")

    if not cue.loop:
        body = _fade(body, release=min(0.12, cue.duration * 0.35))
    delayed = np.zeros_like(body)
    delay = min(len(body) - 1, int(0.009 * SR))
    if cue.loop:
        delayed = np.roll(body, delay)
    else:
        delayed[delay:] = body[:-delay]
    stereo = np.column_stack((body + delayed * 0.16, body - delayed * 0.12))
    stereo -= np.mean(stereo, axis=0, keepdims=True)
    peak = float(np.max(np.abs(stereo)))
    return stereo * (PEAK / max(peak, 1e-9))


def _write_wave(path: Path, samples: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = np.round(np.clip(samples, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(2)
        handle.setsampwidth(2)
        handle.setframerate(SR)
        handle.writeframes(pcm.tobytes())


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build() -> dict:
    records = []
    for cue in CUES:
        path = SFX_DIR / f"sfx_{cue.key}.wav"
        samples = _render(cue)
        _write_wave(path, samples)
        loop_join_jump = float(np.max(np.abs(samples[-1] - samples[0]))) if cue.loop else None
        loop_local_p99 = float(np.percentile(np.max(np.abs(np.diff(samples, axis=0)), axis=1), 99)) if cue.loop else None
        loop_join_limit = max(0.02, 4.0 * loop_local_p99) if loop_local_p99 is not None else None
        records.append({
            "key": cue.key,
            "label": cue.label,
            "category": cue.category,
            "priority": cue.priority,
            "min_interval_ms": cue.min_interval_ms,
            "runtime_gain_db": cue.runtime_gain_db,
            "loop": cue.loop,
            "candidate_path_windows": str(path),
            "runtime_path": f"res://audio/sfx/{path.name}",
            "sample_rate": SR,
            "channels": 2,
            "bits_per_sample": 16,
            "frame_count": samples.shape[0],
            "duration_seconds": round(samples.shape[0] / SR, 6),
            "peak_dbfs": round(20 * math.log10(max(float(np.max(np.abs(samples))), 1e-12)), 6),
            "dc_offset": [round(float(value), 8) for value in np.mean(samples, axis=0)],
            "loop_join_jump": round(loop_join_jump, 8) if loop_join_jump is not None else None,
            "loop_local_p99_jump": round(loop_local_p99, 8) if loop_local_p99 is not None else None,
            "loop_join_limit": round(loop_join_limit, 8) if loop_join_limit is not None else None,
            "loop_pass": loop_join_jump <= loop_join_limit if cue.loop else None,
            "sha256": _sha(path),
        })
    _validate_records(records)
    manifest = {
        "schema_version": 1,
        "cue_count": len(records),
        "pool_sizes": {"critical": 4, "gameplay": 8, "ambient": 12},
        "cues": records,
    }
    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST_PATH.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    _write_review(manifest)
    return manifest


def _validate_records(records: list[dict]) -> None:
    keys = [record["key"] for record in records]
    if len(records) != 32 or len(set(keys)) != 32:
        raise ValueError("SFX catalog must contain exactly 32 unique cues")
    for record in records:
        if record["sample_rate"] != SR or record["channels"] != 2 or record["bits_per_sample"] != 16:
            raise ValueError(f"invalid WAV format: {record['key']}")
        if record["duration_seconds"] <= 0.05 or record["duration_seconds"] > 1.25:
            raise ValueError(f"invalid SFX duration: {record['key']}")
        if record["peak_dbfs"] > -1.0 or record["peak_dbfs"] < -3.0:
            raise ValueError(f"invalid peak level: {record['key']}")
        if max(abs(value) for value in record["dc_offset"]) > 0.01:
            raise ValueError(f"excessive DC offset: {record['key']}")
        if record["loop"] and not record["loop_pass"]:
            raise ValueError(f"loop edge failed: {record['key']}")


def _write_review(manifest: dict) -> None:
    sections = []
    categories = []
    for cue in manifest["cues"]:
        if cue["category"] not in categories:
            categories.append(cue["category"])
    for category in categories:
        cards = []
        for cue in (item for item in manifest["cues"] if item["category"] == category):
            source = "../sfx_candidates/" + Path(cue["candidate_path_windows"]).name
            cards.append(
                f'<article><h3>{html.escape(cue["label"])}</h3><code>{cue["key"]}</code>'
                f'<p>{cue["priority"]} · {cue["duration_seconds"]:.2f}s · peak {cue["peak_dbfs"]:.1f} dBFS</p>'
                f'<audio controls preload="none" src="{html.escape(source)}"></audio></article>'
            )
        sections.append(f'<section><h2>{html.escape(category)}</h2><div>{"".join(cards)}</div></section>')
    document = f'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>Phase 7 SFX 试听</title>
<style>body{{font:16px system-ui;background:#101217;color:#eef2f8;margin:0}}main{{max-width:1080px;margin:auto;padding:32px}}h1{{font-size:32px}}section{{margin:30px 0}}section>div{{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:10px}}article{{background:#1a1e27;border:1px solid #39404e;padding:14px;border-radius:6px}}h3{{margin:0 0 6px}}code{{color:#8fd3ff}}p{{color:#aab3c2}}audio{{width:100%}}</style>
<main><h1>Phase 7 SFX 完整候选库</h1><p>逐项确认清晰度、风格统一性，以及是否会遮蔽弹幕警告。接受后才接入运行时。</p>{''.join(sections)}</main></html>'''
    REVIEW_PATH.parent.mkdir(parents=True, exist_ok=True)
    REVIEW_PATH.write_text(document, encoding="utf-8")


if __name__ == "__main__":
    result = build()
    print(json.dumps({"cue_count": result["cue_count"], "review": str(REVIEW_PATH)}, ensure_ascii=False))
