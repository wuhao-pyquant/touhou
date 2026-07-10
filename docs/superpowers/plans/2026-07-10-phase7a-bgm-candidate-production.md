# Phase 7A BGM Candidate Production Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a deterministic cross-machine production pipeline, generate two technically valid 30-second Stable Audio 3 Medium candidates for each of twelve BGM tracks, and publish a local review page for human A/B selection.

**Architecture:** Keep creative source control in the Godot repository and generated audio outside it. A tracked JSON catalog defines the twelve tracks, prompts, parameters, and fixed seeds. A standard-library Python runner executes the existing Mac Stable Audio wrapper and atomically writes WAV candidates to the NAS, while a separate Windows-compatible QA tool validates those files and builds the listening page.

**Tech Stack:** Python 3 standard library, Stable Audio 3 Medium MLX on `mac-mini-m4`, SSH/Codex remote task control, SMB/NAS staging, 44.1 kHz stereo WAV, HTML5 audio review, Godot repository documentation.

## Global Constraints

- Generate exactly twelve BGM identities: `stage1_mid`, `stage1_boss`, through `stage6_mid`, `stage6_boss`.
- Generate exactly two 30-second candidates, `A` and `B`, for every track before long-form work.
- Use Stable Audio 3 Medium with SAME-L, 8 sampling steps, CFG 2.0 by default, and fixed recorded seeds.
- Stages 1 through 4 contain no voices. Stages 5 and 6 may use only restrained wordless shouts or choir behind gameplay cues.
- Use original Japanese festival instrumentation plus electronic rock; do not reference or imitate existing Touhou Project music or any recognizable existing game melody.
- Preserve gameplay readability: prompts must leave spectral room for warning, graze, hit, and player-damage cues.
- macOS staging root is `/Volumes/personal_folder/temp/godot_touhou_phase7`.
- Windows staging root is `Z:\temp\godot_touhou_phase7`.
- Generated WAV files must not be copied into the Godot project during Phase 7A.
- A generated candidate becomes visible only after header validation succeeds and a `.partial.wav` file is atomically renamed.
- Existing valid candidate files are skipped unless `--force` is supplied.
- This plan stops at the human A/B selection gate. Long-form generation, 188-to-180-second loop processing, runtime OGG conversion, SFX, and Godot integration belong to later Phase 7 plans.

---

## File Structure

Create these tracked files:

- `audio/production/phase7_bgm_jobs.json`: authoritative track, prompt, generation-parameter, and seed catalog.
- `tools/audio/phase7_catalog.py`: catalog loader and strict schema validator.
- `tools/audio/phase7_candidate_runner.py`: Mac-side candidate executor with atomic output and resumable generation manifest.
- `tools/audio/phase7_candidate_qa.py`: Windows/macOS WAV validator and static listening-page generator.
- `tests/test_phase7_bgm_catalog.py`: catalog contract tests.
- `tests/test_phase7_candidate_runner.py`: command construction, skip, failure, and atomic-publish tests.
- `tests/test_phase7_candidate_qa.py`: WAV acceptance/rejection and HTML review tests.
- `docs/audio/phase7_candidate_workflow.md`: operator commands, directory contract, and failure recovery.

External outputs under the NAS staging root:

- `bgm_candidates/<track_key>/bgm_<track_key>_<variant>_seed-<seed>.wav`
- `reports/generation_manifest.json`
- `reports/candidate_qa.json`
- `reports/bgm_candidate_review.html`
- `control/`: a copy of the tracked catalog and runner used by the Mac task.

## Task 1: Authoritative BGM Job Catalog

**Files:**

- Create: `audio/production/phase7_bgm_jobs.json`
- Create: `tools/audio/phase7_catalog.py`
- Create: `tests/test_phase7_bgm_catalog.py`

**Interfaces:**

- Produces: `load_catalog(path: Path) -> dict`.
- Produces: `validate_catalog(data: dict) -> None`, raising `ValueError` with a field-specific message.
- Produces JSON fields consumed by Tasks 2 and 3: `schema_version`, `defaults`, `negative_prompt`, and `tracks`.
- Each track produces: `key`, `stage`, `phase`, `title_zh`, `bpm`, `voice_policy`, `prompt`, and `candidates`.

- [ ] **Step 1: Write the failing catalog contract test**

Create `tests/test_phase7_bgm_catalog.py`:

```python
from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "audio"))

from phase7_catalog import load_catalog


class Phase7BgmCatalogTests(unittest.TestCase):
    def setUp(self) -> None:
        self.path = ROOT / "audio" / "production" / "phase7_bgm_jobs.json"
        self.data = load_catalog(self.path)

    def test_catalog_has_exact_track_order(self) -> None:
        expected = [
            "stage1_mid", "stage1_boss",
            "stage2_mid", "stage2_boss",
            "stage3_mid", "stage3_boss",
            "stage4_mid", "stage4_boss",
            "stage5_mid", "stage5_boss",
            "stage6_mid", "stage6_boss",
        ]
        self.assertEqual(expected, [track["key"] for track in self.data["tracks"]])

    def test_every_track_has_two_distinct_fixed_candidates(self) -> None:
        for track in self.data["tracks"]:
            self.assertEqual(["A", "B"], [item["variant"] for item in track["candidates"]])
            seeds = [item["seed"] for item in track["candidates"]]
            self.assertEqual(2, len(set(seeds)))
            self.assertTrue(all(isinstance(seed, int) and 0 < seed < 2_147_483_647 for seed in seeds))

    def test_voice_policy_matches_stage_rules(self) -> None:
        for track in self.data["tracks"]:
            if track["stage"] <= 4:
                self.assertEqual("instrumental_only", track["voice_policy"])
                self.assertIn("strictly instrumental", track["prompt"].lower())
            else:
                self.assertEqual("restrained_wordless_only", track["voice_policy"])
                self.assertIn("wordless", track["prompt"].lower())

    def test_defaults_match_approved_generation_contract(self) -> None:
        self.assertEqual(30.0, self.data["defaults"]["seconds"])
        self.assertEqual(8, self.data["defaults"]["steps"])
        self.assertEqual(2.0, self.data["defaults"]["cfg"])
        self.assertEqual("medium", self.data["defaults"]["dit"])
        self.assertEqual("same-l", self.data["defaults"]["decoder"])

    def test_prompts_are_original_and_gameplay_aware(self) -> None:
        forbidden = ("touhou", "zun", "東方", "博麗", "幻想郷")
        for track in self.data["tracks"]:
            combined = (track["prompt"] + " " + self.data["negative_prompt"]).lower()
            for token in forbidden:
                self.assertNotIn(token.lower(), combined)
            self.assertIn("warning sfx", track["prompt"].lower())
            self.assertIn(f"exact {track['bpm']} bpm", track["prompt"].lower())


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the catalog test and verify it fails**

Run:

```powershell
python tests/test_phase7_bgm_catalog.py
```

Expected: FAIL with `ModuleNotFoundError: No module named 'phase7_catalog'`.

- [ ] **Step 3: Implement the strict catalog loader**

Create `tools/audio/phase7_catalog.py`:

```python
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

TRACK_KEYS = [
    "stage1_mid", "stage1_boss",
    "stage2_mid", "stage2_boss",
    "stage3_mid", "stage3_boss",
    "stage4_mid", "stage4_boss",
    "stage5_mid", "stage5_boss",
    "stage6_mid", "stage6_boss",
]
VOICE_POLICIES = {"instrumental_only", "restrained_wordless_only"}


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def validate_catalog(data: dict[str, Any]) -> None:
    _require(data.get("schema_version") == 1, "schema_version must be 1")
    defaults = data.get("defaults")
    _require(isinstance(defaults, dict), "defaults must be an object")
    _require(defaults.get("seconds") == 30.0, "defaults.seconds must be 30.0")
    _require(defaults.get("steps") == 8, "defaults.steps must be 8")
    _require(defaults.get("cfg") == 2.0, "defaults.cfg must be 2.0")
    _require(defaults.get("dit") == "medium", "defaults.dit must be medium")
    _require(defaults.get("decoder") == "same-l", "defaults.decoder must be same-l")
    _require(isinstance(data.get("negative_prompt"), str) and data["negative_prompt"].strip(),
             "negative_prompt must be a non-empty string")

    tracks = data.get("tracks")
    _require(isinstance(tracks, list), "tracks must be an array")
    _require([track.get("key") for track in tracks] == TRACK_KEYS,
             "tracks must contain the twelve approved keys in stage order")

    all_seeds: set[int] = set()
    for track in tracks:
        key = track["key"]
        stage = track.get("stage")
        phase = track.get("phase")
        _require(isinstance(stage, int) and 1 <= stage <= 6, f"{key}.stage must be 1..6")
        _require(phase in {"mid", "boss"}, f"{key}.phase must be mid or boss")
        _require(key == f"stage{stage}_{phase}", f"{key} does not match stage/phase")
        _require(isinstance(track.get("title_zh"), str) and track["title_zh"].strip(),
                 f"{key}.title_zh must be non-empty")
        _require(isinstance(track.get("bpm"), int) and 120 <= track["bpm"] <= 220,
                 f"{key}.bpm must be 120..220")
        _require(track.get("voice_policy") in VOICE_POLICIES,
                 f"{key}.voice_policy is invalid")
        expected_voice = "instrumental_only" if stage <= 4 else "restrained_wordless_only"
        _require(track["voice_policy"] == expected_voice,
                 f"{key}.voice_policy must be {expected_voice}")
        _require(isinstance(track.get("prompt"), str) and len(track["prompt"]) >= 120,
                 f"{key}.prompt is too short")
        candidates = track.get("candidates")
        _require(isinstance(candidates, list) and len(candidates) == 2,
                 f"{key}.candidates must contain A and B")
        _require([item.get("variant") for item in candidates] == ["A", "B"],
                 f"{key}.candidates must be ordered A, B")
        for item in candidates:
            seed = item.get("seed")
            _require(isinstance(seed, int) and 0 < seed < 2_147_483_647,
                     f"{key}.{item.get('variant')}.seed is invalid")
            _require(seed not in all_seeds, f"duplicate seed {seed}")
            all_seeds.add(seed)


def load_catalog(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)
    _require(isinstance(data, dict), "catalog root must be an object")
    validate_catalog(data)
    return data
```

- [ ] **Step 4: Create the complete twelve-track JSON catalog**

Create `audio/production/phase7_bgm_jobs.json` with this exact structure and values:

```json
{
  "schema_version": 1,
  "defaults": {
    "seconds": 30.0,
    "steps": 8,
    "cfg": 2.0,
    "dit": "medium",
    "decoder": "same-l",
    "free_models": true
  },
  "negative_prompt": "lyrics, spoken words, dialogue, lead vocals, copyrighted melody, recognizable existing game music, franchise theme, cinematic intro, cinematic outro, fade-out ending, ambient-only drift, uncontrolled tempo change, muddy bass, harsh noise, excessive reverb, crushed dynamics, warning-like beeps",
  "tracks": [
    {
      "key": "stage1_mid",
      "stage": 1,
      "phase": "mid",
      "title_zh": "灯火初参道",
      "bpm": 150,
      "voice_policy": "instrumental_only",
      "prompt": "Original instrumental Japanese night-festival fantasy danmaku stage music, exact 150 BPM, steady 4/4, seamless loopable 30-second motif, no intro, no outro, warm and bright shrine approach, welcoming lantern procession, memorable independent melody, festival flute, koto-like accents, light taiko, restrained electronic rock drums, melodic bass and clear synth support, strictly instrumental, no choir, no vocal, clean game mix leaving spectral room for arcade warning SFX and graze cues",
      "candidates": [{"variant": "A", "seed": 2026071101}, {"variant": "B", "seed": 2026071102}]
    },
    {
      "key": "stage1_boss",
      "stage": 1,
      "phase": "boss",
      "title_zh": "引路狐的第一夜",
      "bpm": 172,
      "voice_policy": "instrumental_only",
      "prompt": "Original instrumental Japanese night-festival fantasy danmaku boss music, exact 172 BPM, steady 4/4, seamless loopable 30-second motif, no intro, no outro, agile mischievous festival guide fox duel, memorable independent melody, shamisen-like plucks trading phrases with electronic guitar and festival flute, taiko plus punchy electronic rock drums, fast but readable arrangement, strictly instrumental, no choir, no vocal, preserve short spectral openings for spell and warning SFX",
      "candidates": [{"variant": "A", "seed": 2026071111}, {"variant": "B", "seed": 2026071112}]
    },
    {
      "key": "stage2_mid",
      "stage": 2,
      "phase": "mid",
      "title_zh": "百物市的交易铃",
      "bpm": 156,
      "voice_policy": "instrumental_only",
      "prompt": "Original instrumental Japanese night-festival fantasy danmaku stage music, exact 156 BPM, steady 4/4, seamless loopable 30-second motif, no intro, no outro, lively yokai market gradually becoming unstable, memorable independent melody, wood blocks and abacus-like percussion, koto-like plucks, jumping bass, light taiko and electronic rock groove, colorful stalls and awakened tools, strictly instrumental, no choir, no vocal, uncluttered game mix leaving room for warning SFX",
      "candidates": [{"variant": "A", "seed": 2026071201}, {"variant": "B", "seed": 2026071202}]
    },
    {
      "key": "stage2_boss",
      "stage": 2,
      "phase": "boss",
      "title_zh": "鬼市掌柜的算盘火",
      "bpm": 176,
      "voice_policy": "instrumental_only",
      "prompt": "Original instrumental Japanese night-festival fantasy danmaku boss music, exact 176 BPM, steady 4/4, seamless loopable 30-second motif, no intro, no outro, forceful oni market merchant leader and supernatural bargain duel, memorable independent melody, heavy bass, sharp synth lead, taiko, metallic abacus percussion and electronic rock guitar, aggressive harmonic motion without chaos, strictly instrumental, no choir, no vocal, preserve cue space for boss hit and laser warning SFX",
      "candidates": [{"variant": "A", "seed": 2026071211}, {"variant": "B", "seed": 2026071212}]
    },
    {
      "key": "stage3_mid",
      "stage": 3,
      "phase": "mid",
      "title_zh": "雾竹回廊",
      "bpm": 148,
      "voice_policy": "instrumental_only",
      "prompt": "Original instrumental Japanese night-festival fantasy danmaku stage music, exact 148 BPM, steady 4/4, seamless loopable 30-second motif, no intro, no outro, dreamlike mist bamboo corridor, wrong paths and time displacement, memorable independent melody, breathy festival flute, bamboo percussion, delayed koto-like figures, subdued taiko, controlled electronic pulse and warm bass, strictly instrumental, no choir, no vocal, transparent mix leaving warning SFX clearly audible",
      "candidates": [{"variant": "A", "seed": 2026071301}, {"variant": "B", "seed": 2026071302}]
    },
    {
      "key": "stage3_boss",
      "stage": 3,
      "phase": "boss",
      "title_zh": "月影幻术师",
      "bpm": 174,
      "voice_policy": "instrumental_only",
      "prompt": "Original instrumental Japanese night-festival fantasy danmaku boss music, exact 174 BPM, steady 4/4, seamless loopable 30-second motif, no intro, no outro, moonlit bamboo illusionist duel, reversed-feeling phrases and unstable harmony, memorable independent melody, fast koto-like arpeggios, flute fragments, electronic bass and focused rock drums, tense but not overfilled, strictly instrumental, no choir, no vocal, maintain room for spell and warning SFX",
      "candidates": [{"variant": "A", "seed": 2026071311}, {"variant": "B", "seed": 2026071312}]
    },
    {
      "key": "stage4_mid",
      "stage": 4,
      "phase": "mid",
      "title_zh": "风上新闻飞行",
      "bpm": 166,
      "voice_policy": "instrumental_only",
      "prompt": "Original instrumental Japanese night-festival fantasy danmaku stage music, exact 166 BPM, steady 4/4, seamless loopable 30-second motif, no intro, no outro, high-speed tengu mountain ascent and aerial pursuit, memorable independent melody, running festival flute, snare propulsion, paper and feather percussion, wind-like synth motion, taiko accents and electronic rock bass, strictly instrumental, no choir, no vocal, clear game mix leaving warning SFX unmasked",
      "candidates": [{"variant": "A", "seed": 2026071401}, {"variant": "B", "seed": 2026071402}]
    },
    {
      "key": "stage4_boss",
      "stage": 4,
      "phase": "boss",
      "title_zh": "改写天幕的山风",
      "bpm": 184,
      "voice_policy": "instrumental_only",
      "prompt": "Original instrumental Japanese night-festival fantasy danmaku boss music, exact 184 BPM, steady 4/4, seamless loopable 30-second motif, no intro, no outro, direct mountain wind tengu aerial duel, memorable independent melody, tremolo shamisen-like plucks, forceful taiko, fast electronic rock guitar, driving bass and sharp but controlled synth lead, strictly instrumental, no choir, no vocal, preserve transient space for laser warning and player hit SFX",
      "candidates": [{"variant": "A", "seed": 2026071411}, {"variant": "B", "seed": 2026071412}]
    },
    {
      "key": "stage5_mid",
      "stage": 5,
      "phase": "mid",
      "title_zh": "鬼宴未散",
      "bpm": 170,
      "voice_policy": "restrained_wordless_only",
      "prompt": "Original Japanese night-festival fantasy danmaku stage music, exact 170 BPM, steady 4/4, seamless loopable 30-second motif, no intro, no outro, dangerous oni banquet and rhythm bullets, memorable independent melody, layered taiko polyrhythm, deep bass, shamisen-like accents, electronic rock drums and restrained low-mixed wordless festival shouts only, no lyrics, no speech, keep voices behind the instruments, leave clear space for warning SFX and resource cues",
      "candidates": [{"variant": "A", "seed": 2026071501}, {"variant": "B", "seed": 2026071502}]
    },
    {
      "key": "stage5_boss",
      "stage": 5,
      "phase": "boss",
      "title_zh": "朱鼓醉姬",
      "bpm": 188,
      "voice_policy": "restrained_wordless_only",
      "prompt": "Original Japanese night-festival fantasy danmaku boss music, exact 188 BPM, steady 4/4, seamless loopable 30-second motif, no intro, no outro, heavy intoxicated oni princess duel, memorable independent melody, massive taiko, aggressive electronic rock guitar, strong bass and background wordless festival calls only, no lyrics, no speech, calls remain low in the mix, protect cue windows for spell announcements, player hit and laser warning SFX",
      "candidates": [{"variant": "A", "seed": 2026071511}, {"variant": "B", "seed": 2026071512}]
    },
    {
      "key": "stage6_mid",
      "stage": 6,
      "phase": "mid",
      "title_zh": "万灯渡神域",
      "bpm": 176,
      "voice_policy": "restrained_wordless_only",
      "prompt": "Original Japanese night-festival fantasy danmaku final-stage music, exact 176 BPM, steady 4/4, seamless loopable 30-second motif, no intro, no outro, sacred river of ten thousand lanterns becoming overwhelming, memorable independent melody, wide synth layers, festival flute, koto-like lantern accents, taiko, electronic rock rhythm and low-mixed wordless choir only, no lyrics, no speech, preserve clarity for dense final-stage warning SFX",
      "candidates": [{"variant": "A", "seed": 2026071601}, {"variant": "B", "seed": 2026071602}]
    },
    {
      "key": "stage6_boss",
      "stage": 6,
      "phase": "boss",
      "title_zh": "百鬼夜祭神",
      "bpm": 194,
      "voice_policy": "restrained_wordless_only",
      "prompt": "Original Japanese night-festival fantasy danmaku final-boss music, exact 194 BPM, steady 4/4, seamless loopable 30-second motif, no intro, no outro, divine god of the unending night festival, memorable independent final melody, forceful taiko, electronic rock guitar and bass, festival flute, shamisen-like plucks, brilliant synth lead and restrained wordless choir only, no lyrics, no speech, dramatic but clean mix with explicit transient space for spell, laser warning, deathbomb and player hit SFX",
      "candidates": [{"variant": "A", "seed": 2026071611}, {"variant": "B", "seed": 2026071612}]
    }
  ]
}
```

- [ ] **Step 5: Run the catalog test and verify it passes**

Run:

```powershell
python tests/test_phase7_bgm_catalog.py
```

Expected: `Ran 5 tests` and `OK`.

- [ ] **Step 6: Commit Task 1**

```powershell
git add audio/production/phase7_bgm_jobs.json tools/audio/phase7_catalog.py tests/test_phase7_bgm_catalog.py
git commit -m "feat: define phase 7 BGM candidate catalog"
```

## Task 2: Resumable Mac Candidate Runner

**Files:**

- Create: `tools/audio/phase7_candidate_runner.py`
- Create: `tests/test_phase7_candidate_runner.py`

**Interfaces:**

- Consumes: `load_catalog(path: Path) -> dict` from Task 1.
- Produces: `candidate_filename(track_key: str, variant: str, seed: int) -> str`.
- Produces: `build_command(generator: list[str], defaults: dict, track: dict, candidate: dict, out_path: Path, negative_prompt: str) -> list[str]`.
- Produces: `validate_wave(path: Path, expected_seconds: float) -> dict`.
- Produces: `run_catalog(catalog_path: Path, staging_root: Path, generator: list[str], force: bool) -> int`.
- Produces external `reports/generation_manifest.json` with atomic status updates.

- [ ] **Step 1: Write the failing runner tests**

Create `tests/test_phase7_candidate_runner.py`:

```python
from __future__ import annotations

import json
import sys
import tempfile
import unittest
import wave
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "audio"))

import phase7_candidate_runner as runner
from phase7_catalog import load_catalog
from phase7_candidate_runner import build_command, candidate_filename, validate_wave


def write_silence(path: Path, seconds: float = 30.0) -> None:
    frames = int(44_100 * seconds)
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(2)
        handle.setsampwidth(2)
        handle.setframerate(44_100)
        handle.writeframes(b"\x00\x00\x00\x00" * frames)


def mini_catalog() -> dict:
    return {
        "schema_version": 1,
        "defaults": {
            "seconds": 30.0,
            "steps": 8,
            "cfg": 2.0,
            "dit": "medium",
            "decoder": "same-l",
            "free_models": True,
        },
        "negative_prompt": "no lyrics",
        "tracks": [{
            "key": "stage1_mid",
            "title_zh": "灯火初参道",
            "prompt": "original test prompt",
            "candidates": [{"variant": "A", "seed": 2026071101}],
        }],
    }


class Phase7CandidateRunnerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.catalog = load_catalog(ROOT / "audio" / "production" / "phase7_bgm_jobs.json")
        self.track = self.catalog["tracks"][0]
        self.candidate = self.track["candidates"][0]

    def test_candidate_filename_is_stable(self) -> None:
        self.assertEqual(
            "bgm_stage1_mid_A_seed-2026071101.wav",
            candidate_filename("stage1_mid", "A", 2026071101),
        )

    def test_command_contains_approved_arguments(self) -> None:
        command = build_command(
            ["/tmp/stable-audio-3-medium.sh"],
            self.catalog["defaults"],
            self.track,
            self.candidate,
            Path("/tmp/out.partial.wav"),
            self.catalog["negative_prompt"],
        )
        self.assertEqual("/tmp/stable-audio-3-medium.sh", command[0])
        self.assertEqual("medium", command[command.index("--dit") + 1])
        self.assertEqual("same-l", command[command.index("--decoder") + 1])
        self.assertEqual("30.0", command[command.index("--seconds") + 1])
        self.assertEqual("8", command[command.index("--steps") + 1])
        self.assertEqual("2.0", command[command.index("--cfg") + 1])
        self.assertEqual("2026071101", command[command.index("--seed") + 1])
        self.assertEqual(self.track["prompt"], command[command.index("--prompt") + 1])

    def test_wave_validation_accepts_exact_contract(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "candidate.wav"
            write_silence(path)
            report = validate_wave(path, 30.0)
            self.assertEqual(44_100, report["sample_rate"])
            self.assertEqual(2, report["channels"])
            self.assertEqual(16, report["bits_per_sample"])
            self.assertAlmostEqual(30.0, report["duration_seconds"], places=3)

    def test_wave_validation_rejects_wrong_channel_count(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "mono.wav"
            with wave.open(str(path), "wb") as handle:
                handle.setnchannels(1)
                handle.setsampwidth(2)
                handle.setframerate(44_100)
                handle.writeframes(b"\x00\x00" * 44_100)
            with self.assertRaisesRegex(ValueError, "stereo"):
                validate_wave(path, 1.0)

    def test_run_catalog_skips_existing_valid_candidate(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            staging = Path(temp_dir)
            track_dir = staging / "bgm_candidates" / "stage1_mid"
            track_dir.mkdir(parents=True)
            final_path = track_dir / candidate_filename("stage1_mid", "A", 2026071101)
            write_silence(final_path)
            with mock.patch.object(runner, "load_catalog", return_value=mini_catalog()):
                exit_code = runner.run_catalog(
                    Path("unused.json"), staging,
                    [sys.executable, "-c", "raise SystemExit(99)"], False,
                )
            self.assertEqual(0, exit_code)
            manifest = json.loads((staging / "reports" / "generation_manifest.json").read_text(encoding="utf-8"))
            self.assertEqual("skipped_valid", manifest["jobs"][0]["status"])

    def test_failed_generation_does_not_publish_final_file(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            staging = Path(temp_dir)
            with mock.patch.object(runner, "load_catalog", return_value=mini_catalog()):
                exit_code = runner.run_catalog(
                    Path("unused.json"), staging,
                    [sys.executable, "-c", "raise SystemExit(7)"], False,
                )
            final_path = staging / "bgm_candidates" / "stage1_mid" / candidate_filename(
                "stage1_mid", "A", 2026071101
            )
            self.assertEqual(1, exit_code)
            self.assertFalse(final_path.exists())
            manifest = json.loads((staging / "reports" / "generation_manifest.json").read_text(encoding="utf-8"))
            self.assertEqual("generation_failed", manifest["jobs"][0]["status"])

    def test_successful_generation_atomically_publishes_final_file(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            staging = Path(temp_dir)
            fake_generator = staging / "fake_generator.py"
            fake_generator.write_text(
                "import sys,wave\n"
                "out=sys.argv[sys.argv.index('--out')+1]\n"
                "w=wave.open(out,'wb'); w.setnchannels(2); w.setsampwidth(2); "
                "w.setframerate(44100); w.writeframes(b'\\0\\0\\0\\0'*44100*30); w.close()\n",
                encoding="utf-8",
            )
            with mock.patch.object(runner, "load_catalog", return_value=mini_catalog()):
                exit_code = runner.run_catalog(
                    Path("unused.json"), staging,
                    [sys.executable, str(fake_generator)], False,
                )
            final_path = staging / "bgm_candidates" / "stage1_mid" / candidate_filename(
                "stage1_mid", "A", 2026071101
            )
            partial_path = final_path.with_name(final_path.stem + ".partial.wav")
            self.assertEqual(0, exit_code)
            self.assertTrue(final_path.is_file())
            self.assertFalse(partial_path.exists())
            manifest = json.loads((staging / "reports" / "generation_manifest.json").read_text(encoding="utf-8"))
            self.assertEqual("generated", manifest["jobs"][0]["status"])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the runner tests and verify they fail**

Run:

```powershell
python tests/test_phase7_candidate_runner.py
```

Expected: FAIL with `ModuleNotFoundError: No module named 'phase7_candidate_runner'`.

- [ ] **Step 3: Implement command construction and WAV validation**

Create `tools/audio/phase7_candidate_runner.py` with these complete public functions and CLI behavior:

```python
from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
import time
import wave
from pathlib import Path
from typing import Any

from phase7_catalog import load_catalog


def candidate_filename(track_key: str, variant: str, seed: int) -> str:
    return f"bgm_{track_key}_{variant}_seed-{seed}.wav"


def build_command(
    generator: list[str],
    defaults: dict[str, Any],
    track: dict[str, Any],
    candidate: dict[str, Any],
    out_path: Path,
    negative_prompt: str,
) -> list[str]:
    command = list(generator)
    command.extend([
        "--prompt", track["prompt"],
        "--negative-prompt", negative_prompt,
        "--dit", defaults["dit"],
        "--decoder", defaults["decoder"],
        "--seconds", str(defaults["seconds"]),
        "--steps", str(defaults["steps"]),
        "--cfg", str(defaults["cfg"]),
        "--seed", str(candidate["seed"]),
        "--out", str(out_path),
    ])
    if defaults.get("free_models", True):
        command.append("--free-models")
    return command


def validate_wave(path: Path, expected_seconds: float) -> dict[str, Any]:
    if not path.is_file():
        raise ValueError(f"missing WAV output: {path}")
    with wave.open(str(path), "rb") as handle:
        channels = handle.getnchannels()
        sample_width = handle.getsampwidth()
        sample_rate = handle.getframerate()
        frames = handle.getnframes()
    duration = frames / sample_rate if sample_rate else 0.0
    if channels != 2:
        raise ValueError(f"WAV must be stereo, got {channels} channels")
    if sample_width != 2:
        raise ValueError(f"WAV must be 16-bit PCM, got {sample_width * 8} bits")
    if sample_rate != 44_100:
        raise ValueError(f"WAV must be 44100 Hz, got {sample_rate}")
    if abs(duration - expected_seconds) > 0.05:
        raise ValueError(f"WAV duration must be {expected_seconds}s, got {duration:.6f}s")
    return {
        "sample_rate": sample_rate,
        "channels": channels,
        "bits_per_sample": sample_width * 8,
        "frames": frames,
        "duration_seconds": round(duration, 6),
        "size_bytes": path.stat().st_size,
    }


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def write_json_atomic(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp_path = path.with_suffix(path.suffix + ".tmp")
    with temp_path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(data, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    os.replace(temp_path, path)


def run_catalog(
    catalog_path: Path,
    staging_root: Path,
    generator: list[str],
    force: bool,
) -> int:
    catalog = load_catalog(catalog_path)
    reports_dir = staging_root / "reports"
    manifest_path = reports_dir / "generation_manifest.json"
    manifest: dict[str, Any] = {
        "schema_version": 1,
        "catalog": str(catalog_path),
        "staging_root": str(staging_root),
        "jobs": [],
    }
    failures = 0
    for track in catalog["tracks"]:
        track_dir = staging_root / "bgm_candidates" / track["key"]
        track_dir.mkdir(parents=True, exist_ok=True)
        for candidate in track["candidates"]:
            filename = candidate_filename(track["key"], candidate["variant"], candidate["seed"])
            final_path = track_dir / filename
            partial_path = final_path.with_name(final_path.stem + ".partial.wav")
            job: dict[str, Any] = {
                "track_key": track["key"],
                "title_zh": track["title_zh"],
                "variant": candidate["variant"],
                "seed": candidate["seed"],
                "prompt": track["prompt"],
                "negative_prompt": catalog["negative_prompt"],
                "output": str(final_path),
                "status": "planned",
            }
            manifest["jobs"].append(job)
            if final_path.exists() and not force:
                try:
                    job["wave"] = validate_wave(final_path, catalog["defaults"]["seconds"])
                    job["sha256"] = sha256_file(final_path)
                    job["status"] = "skipped_valid"
                    write_json_atomic(manifest_path, manifest)
                    continue
                except ValueError:
                    job["status"] = "existing_invalid"
                    failures += 1
                    write_json_atomic(manifest_path, manifest)
                    continue
            if partial_path.exists():
                partial_path.unlink()
            job["status"] = "generating"
            job["started_at_unix"] = int(time.time())
            write_json_atomic(manifest_path, manifest)
            command = build_command(
                generator,
                catalog["defaults"],
                track,
                candidate,
                partial_path,
                catalog["negative_prompt"],
            )
            completed = subprocess.run(command, check=False)
            job["exit_code"] = completed.returncode
            job["finished_at_unix"] = int(time.time())
            if completed.returncode != 0:
                job["status"] = "generation_failed"
                failures += 1
                write_json_atomic(manifest_path, manifest)
                continue
            try:
                job["wave"] = validate_wave(partial_path, catalog["defaults"]["seconds"])
                os.replace(partial_path, final_path)
                job["sha256"] = sha256_file(final_path)
                job["status"] = "generated"
            except ValueError as exc:
                job["status"] = "validation_failed"
                job["error"] = str(exc)
                failures += 1
            write_json_atomic(manifest_path, manifest)
    manifest["completed_at_unix"] = int(time.time())
    manifest["failure_count"] = failures
    write_json_atomic(manifest_path, manifest)
    return 0 if failures == 0 else 1


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate Phase 7 BGM candidates")
    parser.add_argument("--catalog", required=True, type=Path)
    parser.add_argument("--staging-root", required=True, type=Path)
    parser.add_argument("--generator", required=True, nargs="+")
    parser.add_argument("--force", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    return run_catalog(args.catalog, args.staging_root, args.generator, args.force)


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 4: Run the runner tests and verify they pass**

Run:

```powershell
python tests/test_phase7_candidate_runner.py
```

Expected: `Ran 7 tests` and `OK`.

- [ ] **Step 5: Run a catalog-wide command-construction dry check**

Run:

```powershell
python -c "import json,sys; from pathlib import Path; sys.path.insert(0,'tools/audio'); from phase7_catalog import load_catalog; from phase7_candidate_runner import build_command; d=load_catalog(Path('audio/production/phase7_bgm_jobs.json')); commands=[build_command(['/Users/wuhao/Documents/music/stable-audio-3-medium.sh'],d['defaults'],t,c,Path('/tmp/x.wav'),d['negative_prompt']) for t in d['tracks'] for c in t['candidates']]; assert len(commands)==24; assert all('--out' in x and '--seed' in x for x in commands); print('24 candidate commands valid')"
```

Expected: `24 candidate commands valid`.

- [ ] **Step 6: Commit Task 2**

```powershell
git add tools/audio/phase7_candidate_runner.py tests/test_phase7_candidate_runner.py
git commit -m "feat: add resumable phase 7 candidate runner"
```

## Task 3: Candidate QA And Listening Page

**Files:**

- Create: `tools/audio/phase7_candidate_qa.py`
- Create: `tests/test_phase7_candidate_qa.py`

**Interfaces:**

- Consumes candidate paths and catalog metadata from Tasks 1 and 2.
- Produces: `analyze_wave(path: Path, expected_seconds: float) -> dict`.
- Produces: `build_review_html(catalog: dict, qa_report: dict, output_path: Path) -> None`.
- Produces external `reports/candidate_qa.json` and `reports/bgm_candidate_review.html`.
- Acceptance thresholds: stereo, 44.1 kHz, 16-bit PCM, `30.0 +/- 0.05` seconds, non-zero peak, peak at or below `0 dBFS`, and silence ratio below `0.98` at `-60 dBFS`.

- [ ] **Step 1: Write the failing QA tests**

Create `tests/test_phase7_candidate_qa.py`:

```python
from __future__ import annotations

import math
import struct
import sys
import tempfile
import unittest
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "audio"))

from phase7_candidate_qa import analyze_wave, build_review_html


def write_tone(path: Path, seconds: float = 30.0, amplitude: float = 0.25) -> None:
    frames = int(44_100 * seconds)
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(2)
        handle.setsampwidth(2)
        handle.setframerate(44_100)
        chunks = bytearray()
        for index in range(frames):
            value = int(32_767 * amplitude * math.sin(2.0 * math.pi * 440.0 * index / 44_100))
            chunks.extend(struct.pack("<hh", value, value))
        handle.writeframes(bytes(chunks))


class Phase7CandidateQaTests(unittest.TestCase):
    def test_tone_passes_candidate_qa(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "tone.wav"
            write_tone(path)
            report = analyze_wave(path, 30.0)
            self.assertEqual("pass", report["status"])
            self.assertLess(report["peak_dbfs"], 0.0)
            self.assertLess(report["silence_ratio"], 0.98)

    def test_silence_fails_candidate_qa(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "silence.wav"
            write_tone(path, amplitude=0.0)
            report = analyze_wave(path, 30.0)
            self.assertEqual("fail", report["status"])
            self.assertIn("silent", " ".join(report["errors"]))

    def test_review_page_contains_audio_controls_and_titles(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            output = Path(temp_dir) / "review.html"
            catalog = {"tracks": [{"key": "stage1_mid", "title_zh": "灯火初参道", "bpm": 150}]}
            report = {"candidates": [{
                "track_key": "stage1_mid", "variant": "A", "status": "pass",
                "relative_audio_path": "../bgm_candidates/stage1_mid/test.wav",
                "peak_dbfs": -12.0, "silence_ratio": 0.01,
            }]}
            build_review_html(catalog, report, output)
            html = output.read_text(encoding="utf-8")
            self.assertIn("灯火初参道", html)
            self.assertIn("<audio controls", html)
            self.assertIn("test.wav", html)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the QA tests and verify they fail**

Run:

```powershell
python tests/test_phase7_candidate_qa.py
```

Expected: FAIL with `ModuleNotFoundError: No module named 'phase7_candidate_qa'`.

- [ ] **Step 3: Implement WAV QA and the static review page**

Create `tools/audio/phase7_candidate_qa.py`:

```python
from __future__ import annotations

import argparse
import hashlib
import html
import json
import math
import struct
import wave
from pathlib import Path
from typing import Any

from phase7_catalog import load_catalog
from phase7_candidate_runner import candidate_filename


def analyze_wave(path: Path, expected_seconds: float) -> dict[str, Any]:
    errors: list[str] = []
    try:
        with wave.open(str(path), "rb") as handle:
            channels = handle.getnchannels()
            sample_width = handle.getsampwidth()
            sample_rate = handle.getframerate()
            frame_count = handle.getnframes()
            raw = handle.readframes(frame_count)
    except (FileNotFoundError, wave.Error) as exc:
        return {"status": "fail", "errors": [f"unreadable WAV: {exc}"], "path": str(path)}

    duration = frame_count / sample_rate if sample_rate else 0.0
    if channels != 2:
        errors.append(f"expected stereo, got {channels} channels")
    if sample_width != 2:
        errors.append(f"expected 16-bit PCM, got {sample_width * 8} bits")
    if sample_rate != 44_100:
        errors.append(f"expected 44100 Hz, got {sample_rate}")
    if abs(duration - expected_seconds) > 0.05:
        errors.append(f"expected {expected_seconds}s, got {duration:.6f}s")

    sample_count = len(raw) // 2
    samples = struct.unpack(f"<{sample_count}h", raw) if sample_count else ()
    peak = max((abs(value) for value in samples), default=0)
    silence_threshold = max(1, int(32_767 * (10.0 ** (-60.0 / 20.0))))
    silent = sum(1 for value in samples if abs(value) <= silence_threshold)
    silence_ratio = silent / sample_count if sample_count else 1.0
    if peak == 0:
        errors.append("candidate is silent")
        peak_dbfs = float("-inf")
    else:
        peak_dbfs = 20.0 * math.log10(peak / 32_767.0)
        if peak > 32_767:
            errors.append("candidate clips")
    if silence_ratio >= 0.98:
        errors.append(f"candidate silence ratio is {silence_ratio:.6f}")

    digest = hashlib.sha256(raw).hexdigest()
    return {
        "path": str(path),
        "status": "pass" if not errors else "fail",
        "errors": errors,
        "sample_rate": sample_rate,
        "channels": channels,
        "bits_per_sample": sample_width * 8,
        "duration_seconds": round(duration, 6),
        "peak_dbfs": round(peak_dbfs, 3) if math.isfinite(peak_dbfs) else "-inf",
        "silence_ratio": round(silence_ratio, 6),
        "pcm_sha256": digest,
        "size_bytes": path.stat().st_size,
    }


def build_review_html(catalog: dict[str, Any], qa_report: dict[str, Any], output_path: Path) -> None:
    by_key: dict[str, list[dict[str, Any]]] = {}
    for candidate in qa_report["candidates"]:
        by_key.setdefault(candidate["track_key"], []).append(candidate)
    sections: list[str] = []
    for track in catalog["tracks"]:
        cards: list[str] = []
        for candidate in sorted(by_key.get(track["key"], []), key=lambda item: item["variant"]):
            audio_path = html.escape(candidate["relative_audio_path"], quote=True)
            status = html.escape(candidate["status"])
            cards.append(
                f'<article class="candidate"><h3>候选 {candidate["variant"]}</h3>'
                f'<audio controls preload="metadata" src="{audio_path}"></audio>'
                f'<p>状态: {status} | Peak: {candidate.get("peak_dbfs")} dBFS | '
                f'Silence: {candidate.get("silence_ratio")}</p></article>'
            )
        sections.append(
            f'<section><h2>{track["stage"]}关 {"Boss" if track["phase"] == "boss" else "道中"} '
            f'{html.escape(track["title_zh"])} <small>{track["bpm"]} BPM</small></h2>'
            f'<div class="grid">{"".join(cards)}</div></section>'
        )
    document = f"""<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Phase 7 BGM 候选试听</title><style>
body{{font-family:system-ui,sans-serif;margin:24px;background:#111;color:#eee;letter-spacing:0}}
main{{max-width:1100px;margin:auto}}section{{border-top:1px solid #444;padding:18px 0}}
.grid{{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:12px}}
.candidate{{background:#202020;border:1px solid #444;border-radius:6px;padding:14px}}
audio{{width:100%}}small,p{{color:#bbb}}
</style></head><body><main><h1>Phase 7 BGM 候选试听</h1>{"".join(sections)}</main></body></html>"""
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8", newline="\n") as handle:
        handle.write(document)


def run_qa(catalog_path: Path, staging_root: Path) -> int:
    catalog = load_catalog(catalog_path)
    candidates: list[dict[str, Any]] = []
    for track in catalog["tracks"]:
        for item in track["candidates"]:
            filename = candidate_filename(track["key"], item["variant"], item["seed"])
            path = staging_root / "bgm_candidates" / track["key"] / filename
            report = analyze_wave(path, catalog["defaults"]["seconds"])
            report.update({
                "track_key": track["key"],
                "title_zh": track["title_zh"],
                "variant": item["variant"],
                "seed": item["seed"],
                "relative_audio_path": f"../bgm_candidates/{track['key']}/{filename}",
            })
            candidates.append(report)
    qa_report = {
        "schema_version": 1,
        "expected_candidate_count": 24,
        "candidates": candidates,
        "pass_count": sum(1 for item in candidates if item["status"] == "pass"),
        "fail_count": sum(1 for item in candidates if item["status"] == "fail"),
    }
    reports_dir = staging_root / "reports"
    reports_dir.mkdir(parents=True, exist_ok=True)
    with (reports_dir / "candidate_qa.json").open("w", encoding="utf-8", newline="\n") as handle:
        handle.write(json.dumps(qa_report, ensure_ascii=False, indent=2) + "\n")
    build_review_html(catalog, qa_report, reports_dir / "bgm_candidate_review.html")
    return 0 if qa_report["pass_count"] == 24 and qa_report["fail_count"] == 0 else 1


def main() -> int:
    parser = argparse.ArgumentParser(description="QA Phase 7 BGM candidates")
    parser.add_argument("--catalog", required=True, type=Path)
    parser.add_argument("--staging-root", required=True, type=Path)
    args = parser.parse_args()
    return run_qa(args.catalog, args.staging_root)


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 4: Run the QA tests and verify they pass**

Run:

```powershell
python tests/test_phase7_candidate_qa.py
```

Expected: `Ran 3 tests` and `OK`.

- [ ] **Step 5: Commit Task 3**

```powershell
git add tools/audio/phase7_candidate_qa.py tests/test_phase7_candidate_qa.py
git commit -m "feat: add phase 7 candidate QA and review page"
```

## Task 4: Operator Workflow And Remote Candidate Generation

**Files:**

- Create: `docs/audio/phase7_candidate_workflow.md`
- External create: `Z:\temp\godot_touhou_phase7\control\phase7_bgm_jobs.json`
- External create: `Z:\temp\godot_touhou_phase7\control\phase7_catalog.py`
- External create: `Z:\temp\godot_touhou_phase7\control\phase7_candidate_runner.py`
- External create: 24 candidate WAV files under `Z:\temp\godot_touhou_phase7\bgm_candidates\`
- External create: QA JSON and review HTML under `Z:\temp\godot_touhou_phase7\reports\`

**Interfaces:**

- Consumes tracked catalog and tools from Tasks 1 through 3.
- Uses the existing Mac wrapper `/Users/wuhao/Documents/music/stable-audio-3-medium.sh`.
- Produces 24 candidate WAV files and a complete generation manifest.
- Produces the human review artifact that blocks Phase 7B until the user chooses A/B.

- [ ] **Step 1: Write the exact operator document**

Create `docs/audio/phase7_candidate_workflow.md` containing:

````markdown
# Phase 7 BGM Candidate Workflow

## Storage Contract

- Windows staging: `Z:\temp\godot_touhou_phase7`
- macOS staging: `/Volumes/personal_folder/temp/godot_touhou_phase7`
- Stable Audio wrapper: `/Users/wuhao/Documents/music/stable-audio-3-medium.sh`
- Generated WAV candidates never enter the Godot repository during Phase 7A.

## Publish Control Files From Windows

Run from the Phase 7 worktree root:

```powershell
$root = 'Z:\temp\godot_touhou_phase7'
New-Item -ItemType Directory -Force -Path "$root\control" | Out-Null
Copy-Item 'audio\production\phase7_bgm_jobs.json' "$root\control\phase7_bgm_jobs.json"
Copy-Item 'tools\audio\phase7_catalog.py' "$root\control\phase7_catalog.py"
Copy-Item 'tools\audio\phase7_candidate_runner.py' "$root\control\phase7_candidate_runner.py"
```

## Generate On mac-mini-m4

The Mac Codex task runs:

```bash
cd /Volumes/personal_folder/temp/godot_touhou_phase7/control
python3 phase7_candidate_runner.py \
  --catalog phase7_bgm_jobs.json \
  --staging-root /Volumes/personal_folder/temp/godot_touhou_phase7 \
  --generator /Users/wuhao/Documents/music/stable-audio-3-medium.sh
```

Do not add `--force` during normal resume. The runner skips already valid candidates.

## Validate And Build Review Page On Windows

```powershell
python tools\audio\phase7_candidate_qa.py `
  --catalog audio\production\phase7_bgm_jobs.json `
  --staging-root Z:\temp\godot_touhou_phase7
```

Success requires `24` passes and `0` failures in:

`Z:\temp\godot_touhou_phase7\reports\candidate_qa.json`

Open:

`Z:\temp\godot_touhou_phase7\reports\bgm_candidate_review.html`

Listen to A and B for every track and record one of `A`, `B`, or `regenerate`. Phase 7B does not start until all twelve tracks have a human selection.
````

- [ ] **Step 2: Commit the operator document**

```powershell
git add docs/audio/phase7_candidate_workflow.md
git commit -m "docs: add phase 7 candidate operator workflow"
```

- [ ] **Step 3: Run all Phase 7A unit tests before external generation**

Run:

```powershell
python tests/test_phase7_bgm_catalog.py
python tests/test_phase7_candidate_runner.py
python tests/test_phase7_candidate_qa.py
```

Expected: `15` tests total, all `OK`.

- [ ] **Step 4: Publish the three control files to the NAS**

Run the PowerShell commands from the operator document.

Expected:

```text
Z:\temp\godot_touhou_phase7\control\phase7_bgm_jobs.json
Z:\temp\godot_touhou_phase7\control\phase7_catalog.py
Z:\temp\godot_touhou_phase7\control\phase7_candidate_runner.py
```

- [ ] **Step 5: Dispatch the existing Mac Codex thread to generate all candidates**

Send this exact task to thread `019f49c4-d932-7e30-881f-722f97d1af59` on host `remote-ssh-discovered:mac-mini-m4`:

```text
执行 Godot 弹幕项目 Phase 7A 的 BGM 候选生成。先完整阅读 /Volumes/personal_folder/temp/godot_touhou_phase7/control/phase7_bgm_jobs.json、phase7_catalog.py 和 phase7_candidate_runner.py。使用现有 /Users/wuhao/Documents/music/stable-audio-3-medium.sh，严格按 catalog 的 prompt、negative prompt、seconds、steps、cfg、seed 生成全部 24 个候选。运行命令：cd /Volumes/personal_folder/temp/godot_touhou_phase7/control && python3 phase7_candidate_runner.py --catalog phase7_bgm_jobs.json --staging-root /Volumes/personal_folder/temp/godot_touhou_phase7 --generator /Users/wuhao/Documents/music/stable-audio-3-medium.sh。不要修改 Godot 项目，不要移动文件到项目目录，不要使用 --force。持续到命令完成；若失败，保留 generation_manifest.json 并报告失败的 track/variant 和错误，不要自行改变 prompt 或 seed。
```

Expected: the remote task reaches idle with `failure_count: 0` and 24 jobs in `generated` or `skipped_valid` status.

- [ ] **Step 6: Verify external generation from Windows**

Run:

```powershell
$root = 'Z:\temp\godot_touhou_phase7'
$manifest = Get-Content "$root\reports\generation_manifest.json" -Raw -Encoding UTF8 | ConvertFrom-Json
if ($manifest.failure_count -ne 0) { throw "Generation failures: $($manifest.failure_count)" }
$valid = @($manifest.jobs | Where-Object { $_.status -in @('generated','skipped_valid') })
if ($valid.Count -ne 24) { throw "Expected 24 generated jobs, got $($valid.Count)" }
Get-ChildItem "$root\bgm_candidates" -Recurse -Filter '*.wav' | Measure-Object
```

Expected: `Count : 24`.

- [ ] **Step 7: Run candidate QA and publish the review page**

Run:

```powershell
python tools\audio\phase7_candidate_qa.py `
  --catalog audio\production\phase7_bgm_jobs.json `
  --staging-root Z:\temp\godot_touhou_phase7
```

Expected: exit `0`, `pass_count: 24`, `fail_count: 0`, and a loadable `bgm_candidate_review.html`.

- [ ] **Step 8: Verify repository isolation**

Run:

```powershell
$audioChanges = @(git status --short -- audio/bgm audio/sfx)
if ($audioChanges.Count -ne 0) { throw "Generated audio entered the repository: $audioChanges" }
git status --short
```

Expected: no generated BGM or SFX files in the repository.

- [ ] **Step 9: Stop at the human listening gate**

Report the review-page path and the 24 QA results. Ask the user to choose `A`, `B`, or `regenerate` for each track. Do not start Phase 7B long-form generation before all twelve choices are recorded.

## Plan Completion Criteria

Phase 7A is complete when:

- The tracked catalog contains all twelve approved track identities and exact fixed seeds.
- Catalog, runner, and QA tests pass.
- The Mac Codex task generated 24 valid candidate WAV files with Stable Audio 3 Medium.
- `generation_manifest.json` records zero failures.
- `candidate_qa.json` records 24 passes and zero failures.
- `bgm_candidate_review.html` presents A/B audio controls for all twelve tracks.
- No generated candidate audio exists inside the Godot repository.
- Work stops at the explicit human A/B selection gate.
