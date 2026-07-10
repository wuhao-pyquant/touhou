# Phase 7B BGM Long-Form Production Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Execute one task at a time, require an independent review after every task, and stop at the final human long-form acceptance gate.

**Goal:** Turn the twelve user-selected `B` candidates into evolving 188-second Stable Audio sources, deterministic exact 180-second seamless-loop review masters, and a local long-form listening page without copying generated audio into the Godot repository.

**Architecture:** Track only catalogs, deterministic DSP, runners, QA, tests, and operator documentation in Git. Keep selected candidates, guides, long-form sources, review masters, manifests, and HTML on the NAS. A six-section guide builder expands each selected 30-second motif into a click-free 188-second structural guide. Stable Audio 3 Medium performs audio-to-audio development at the approved `init-noise-level=0.55`. A deterministic circular renderer creates a 180-second loop, and FFmpeg applies constant-gain loudness normalization so the loop boundary is not changed by dynamic processing.

**Tech Stack:** Python 3.9-compatible standard library, Stable Audio 3 Medium MLX on `mac-mini-m4`, FFmpeg/FFprobe on Windows, SMB/NAS staging, 44.1 kHz stereo 16-bit PCM WAV, HTML5 audio review.

## Global Constraints

- All twelve human selections are variant `B`; the external record is `Z:\temp\godot_touhou_phase7\reports\bgm_candidate_selection.json`.
- Every tracked selected SHA256 must match the corresponding external candidate before guide construction or generation.
- Selected 30-second candidates are melodic and timbral guides only. Review masters must not be simple six-times repetition.
- Build a six-section 188-second guide: theme, variation, breathing section, rebuild, climax, theme return/loop preparation.
- Use one-second equal-power overlap-add between guide sections so the init audio has no hard joins.
- Stable Audio defaults are Medium/SAME-L, 188 seconds, 8 steps, CFG 2.0, `init-noise-level=0.55`, `--free-models`, and the recorded selected seed.
- Stages 1-4 remain instrumental. Stages 5-6 follow the previously approved restrained wordless-voice policy.
- Long-form prompts retain exact BPM, story progression, Japanese festival/electronic-rock identity, and spectral room for gameplay SFX.
- Render the loop exactly as approved: crossfade source seconds 180-188 into seconds 0-8, then append source seconds 8-180, producing exactly 180 seconds.
- Use a constant gain for mastering. Do not use a time-varying compressor or limiter unless a later human-approved repair requires it.
- Review-master targets: integrated loudness from -17 to -15 LUFS, true peak at or below -1 dBTP, 44.1 kHz stereo 16-bit PCM, exact 180 seconds.
- Verify ten consecutive loop transitions and publish a short transition preview for every track.
- Generated audio remains outside the repository. Runtime OGG conversion and Godot integration belong to a later Phase 7 plan after human long-form acceptance.
- Stop after publishing the long-form review page. Do not treat automatic QA as musical approval.

## External Layout

Under `Z:\temp\godot_touhou_phase7` / `/Volumes/personal_folder/temp/godot_touhou_phase7`:

```text
reports/bgm_candidate_selection.json
bgm_guides/<track_key>/bgm_<track_key>_B_guide188.wav
bgm_longform/<track_key>/bgm_<track_key>_B_source188.wav
bgm_longform/<track_key>/bgm_<track_key>_loop180_review.wav
bgm_longform/<track_key>/bgm_<track_key>_loop_transition.wav
reports/longform_generation_manifest.json
reports/longform_qa.json
reports/bgm_longform_review.html
control/phase7_bgm_longform_jobs.json
control/phase7_longform_*.py
```

`accepted_masters/` remains empty during Phase 7B. After the later human acceptance gate, an accepted review master may be copied there without changing its audio bytes.

---

## Task 1: Freeze The B Selections And Long-Form Catalog

**Files:**

- Create: `audio/production/phase7_bgm_longform_jobs.json`
- Create: `tools/audio/phase7_longform_catalog.py`
- Create: `tests/test_phase7_longform_catalog.py`

**Interfaces:**

- `load_longform_catalog(path: Path) -> dict`
- `validate_longform_catalog(data: dict) -> None`
- `validate_external_selection(catalog: dict, selection_path: Path, staging_root: Path) -> dict`

**Catalog contract:**

- Exactly the Phase 7A twelve-track order.
- Every `selected_variant` is `B`.
- Store selected seed and selected candidate SHA256 from the recorded selection.
- Defaults: `source_seconds=188.0`, `master_seconds=180.0`, `crossfade_seconds=8.0`, `guide_crossfade_seconds=1.0`, `steps=8`, `cfg=2.0`, `init_noise_level=0.55`, `dit=medium`, `decoder=same-l`, `free_models=true`, target `-16.0 LUFS`, maximum `-1.0 dBTP`.
- Store the six macro-section identities and effective durations `[30, 30, 30, 30, 38, 30]`.
- Reuse each authoritative Phase 7A prompt and append track-specific long-form development language; do not change the approved voice policy or gameplay-readability language.

- [ ] Write failing tests for order, all-B selection, exact SHA/seed mapping, defaults, macro sections, prompt/voice policy, malformed input, and external path/SHA mismatch.
- [ ] Implement the strict loader and external selection validator with field-specific `ValueError`s.
- [ ] Run `python tests/test_phase7_longform_catalog.py` and the Phase 7A suites.
- [ ] Commit: `feat: freeze phase 7 BGM long-form selections`.

## Task 2: Deterministic Guide Builder And Circular Loop DSP

**Files:**

- Create: `tools/audio/phase7_longform_audio.py`
- Create: `tests/test_phase7_longform_audio.py`

**Interfaces:**

- `read_pcm16_wave(path: Path) -> WaveData`
- `write_pcm16_wave(path: Path, data: WaveData) -> None`
- `build_macro_guide(candidate_path: Path, output_path: Path, source_seconds: float, guide_crossfade_seconds: float) -> dict`
- `render_circular_loop(source_path: Path, output_path: Path, source_seconds: float, master_seconds: float, crossfade_seconds: float) -> dict`
- `build_transition_preview(master_path: Path, output_path: Path, window_seconds: float = 15.0) -> dict`
- `analyze_loop_edges(master_path: Path, repeat_count: int = 10) -> dict`

**Guide algorithm:**

- Require 44.1 kHz stereo 16-bit PCM and a 30-second selected candidate.
- Build six nominal segments of `[31, 31, 31, 31, 39, 30]` seconds; five one-second overlaps yield exactly 188 seconds.
- Require `guide_crossfade_seconds == 1.0`; do not reuse the separate eight-second loop-crossfade setting.
- Derive segments from candidate rotations `[0, 5, 10, 15, 20, 0]` seconds.
- Apply section gain shapes: theme `1.0`, variation `0.95`, breathing `0.72`, rebuild `0.82 -> 1.0`, climax `1.0`, return `0.95 -> 1.0`.
- Apply a restrained one-pole low-pass only to the breathing guide section. The guide is not a final master.
- Join sections with an equal-power overlap-add (`cos` fade-out, `sin` fade-in) and saturate safely to int16.

**Loop algorithm:**

- Require an exact 188-second source.
- Let `N = 8 * 44100`, `tail = source[180s:188s]`, and `head = source[0s:8s]`.
- Set `master[0:N]` to an inclusive equal-power blend from full-gain `tail`/zero-gain `head` to zero-gain `tail`/full-gain `head`.
- Set `master[N:] = source[8s:180s]`; output must contain exactly `180 * 44100` frames.
- Verify the actual playback seam `master[-1] -> master[0]` and the internal join `master[N-1] -> master[N]`.
- For each channel, measure absolute normalized sample jumps. At each join, require `join_jump <= max(0.02, 4 * local_p99_adjacent_jump)`, where the local distribution uses the one-second windows on both sides of that join.
- Require the RMS level difference between the one-second windows on either side of each join to be at most `3.0 dB`.
- Simulate ten consecutive master copies and verify all nine internal wrap transitions against the same thresholds.
- Build a 30-second preview containing the final 15 seconds followed by the initial 15 seconds.

**Numeric WAV/QA thresholds:**

- Guide/source frames: exactly `188 * 44100 = 8,290,800`.
- Master frames: exactly `180 * 44100 = 7,938,000`.
- Transition-preview frames: exactly `30 * 44100 = 1,323,000`.
- Stereo, 44.1 kHz, 16-bit PCM for every WAV.
- Silence ratio below `0.98` at `-60 dBFS`; maximum contiguous silence at or below `2.0 seconds`.
- Absolute per-channel DC offset at or below `0.01` full scale.
- Peak at or below `0 dBFS` before mastering; final true peak at or below `-1 dBTP`.
- Join jump and one-second RMS-delta thresholds are the values defined above.

- [ ] Write failing synthetic-wave tests for exact guide length, six-section overlap, no hard section clicks, exact loop length, circular crossfade orientation, internal join, repeated-boundary metrics, transition preview, invalid metadata, and deterministic output.
- [ ] Implement with `array('h')`, chunked reads/writes, and bounded memory.
- [ ] Run focused tests and `py_compile` under Python 3.9 grammar.
- [ ] Commit: `feat: add phase 7 long-form guide and loop DSP`.

## Task 3: Resumable Mac Long-Form Runner

**Files:**

- Create: `tools/audio/phase7_longform_runner.py`
- Create: `tests/test_phase7_longform_runner.py`

**Interfaces:**

- `guide_filename(track_key: str) -> str`
- `source_filename(track_key: str) -> str`
- `build_longform_command(generator: list[str], defaults: dict, job: dict, guide_path: Path, partial_path: Path, negative_prompt: str) -> list[str]`
- `run_longform_catalog(catalog_path: Path, selection_path: Path, staging_root: Path, generator: list[str], force: bool) -> int`

**Command contract:**

```text
stable-audio-3-medium.sh
  --prompt <long-form prompt>
  --negative-prompt <approved negative prompt>
  --init-audio <guide188.wav>
  --init-noise-level 0.55
  --dit medium --decoder same-l
  --seconds 188.0 --steps 8 --cfg 2.0
  --seed <selected B seed>
  --out <source188.partial.wav>
  --free-models
```

**Runner contract:**

- Validate external selection and candidate SHA before every job.
- Build or validate the deterministic guide before generation.
- Skip an existing valid 188-second source unless `--force` is supplied, but only when its last successful manifest fingerprint exactly matches current inputs.
- Use partial WAVs and atomic publish.
- Persist `reports/longform_generation_manifest.json` atomically after every status transition.
- Catch generator launch failures, non-zero exits, malformed/empty/truncated WAVs, and interruption-safe stale partial cleanup.
- Record `planned`, `guide_ready`, `generating`, `generated`, `skipped_valid`, `generation_failed`, or `validation_failed`, plus command parameters, SHA256, timing, and WAV metadata.

**Resume fingerprint:**

- Hash and compare `selected_sha256`, generated guide SHA256, prompt SHA256, negative-prompt SHA256, seed, init-noise level, steps, CFG, source seconds, model/decoder, generator absolute path and generator-script SHA256.
- Hash and compare every published control file used by the job: long-form catalog, Phase 7A catalog, catalog loaders, guide/DSP module, and runner.
- Any mismatch makes the prior source stale. Without `--force`, record `existing_stale` and fail safely instead of silently reusing or overwriting it.

- [ ] Write failing tests for exact command arguments, guide build, valid skip, stale partial cleanup, generator failure/OSError, corrupt output, atomic publish, manifest durability, and 12-command dry construction.
- [ ] Implement the runner and CLI.
- [ ] Run focused tests and a 12-job dry check against the real catalogs.
- [ ] Commit: `feat: add resumable phase 7 long-form runner`.

## Task 4: Constant-Gain Mastering, Loop QA, And Review Page

**Files:**

- Create: `tools/audio/phase7_longform_qa.py`
- Create: `tests/test_phase7_longform_qa.py`

**Interfaces:**

- `measure_loudness(ffmpeg: Path, source: Path) -> dict`
- `calculate_constant_gain(measurement: dict, target_lufs: float, max_true_peak: float) -> float`
- `apply_constant_gain(ffmpeg: Path, source: Path, output: Path, gain_db: float) -> None`
- `master_and_analyze(catalog: dict, staging_root: Path, ffmpeg: Path) -> dict`
- `build_longform_review_html(catalog: dict, report: dict, output_path: Path) -> None`

**Mastering contract:**

- First render the raw exact 180-second circular loop with Task 2 DSP.
- Measure integrated loudness and true peak using FFmpeg `loudnorm` JSON output.
- Calculate one constant gain toward -16 LUFS, capped so predicted true peak does not exceed -1 dBTP.
- Apply only that constant gain with FFmpeg `-af volume=<gain>dB -c:a pcm_s16le`. The apply command must not contain `loudnorm`, a limiter, compressor, fade, tempo change, or resampling, and must preserve exactly `180 * 44100` frames.
- Remeasure and require -17 to -15 LUFS and true peak at or below -1 dBTP. A source that cannot satisfy both with constant gain fails QA and requires regeneration or explicit repair.
- Recheck exact frames, metadata, non-silence, DC offset, edge/internal join metrics, and ten repeated transitions after mastering.
- Compute 100 Hz RMS-envelope Pearson correlation across the six 30-second master windows beginning at seconds `0, 30, 60, 90, 120, 150`. Emit `possible_six_repeat_structure` when any pair has correlation at or above `0.985` and normalized mean envelope difference at or below `0.02`. This is a human-review warning, not an automatic rejection.
- Atomically publish only passing review masters and transition previews.
- Write UTF-8 `reports/longform_qa.json` and `reports/bgm_longform_review.html` with 12 full-track players, 12 transition-preview players, technical metrics, titles, stage/Boss labels, and no acceptance claim.

- [ ] Write failing tests with synthetic fixtures and a fake FFmpeg adapter for JSON parsing, gain capping, forbidden-filter rejection, exact frame preservation, every numeric pass/fail threshold, section-correlation warnings, deterministic HTML order/escaping, and report counts.
- [ ] Add one integration test using the installed Windows FFmpeg on a short fixture when available.
- [ ] Implement QA/mastering and CLI.
- [ ] Run focused tests and all earlier Phase 7 tests.
- [ ] Commit: `feat: add phase 7 long-form mastering and QA`.

## Task 5: Operator Workflow, Remote Generation, And Human Gate

**Files:**

- Create: `docs/audio/phase7_longform_workflow.md`
- External: control copies, 12 guides under `bgm_guides`, and 12 sources/review masters/transition previews under `bgm_longform`, plus generation/QA reports and review HTML under the NAS root.

**Execution:**

- [ ] Document Windows/macOS paths, control-file SHA checks, normal resume without `--force`, Mac generation, Windows mastering/QA, UTF-8 PowerShell report parsing, and failure recovery.
- [ ] Commit: `docs: add phase 7 long-form operator workflow`.
- [ ] Run every Phase 7A/7B unit test; all commands must exit 0 and report `OK` without a hardcoded total.
- [ ] Copy the approved catalog and runner/DSP tools to NAS `control/` and verify byte-for-byte SHA256.
- [ ] On `mac-mini-m4`, run the long-form runner with the existing Stable Audio wrapper. Use direct SSH if the remote Codex task is blocked by approval, but verify no concurrent runner first.
- [ ] From Windows, verify 12 valid manifest jobs, 0 failures, 12 exact 188-second sources, and no partial files.
- [ ] Run long-form mastering/QA with the installed FFmpeg and require 12 passes, 0 failures.
- [ ] Verify 12 exact 180-second review masters and 12 transition previews, all referenced by the review page.
- [ ] Verify no generated WAV/OGG entered repository `audio/bgm` or `audio/sfx`.
- [ ] Publish `Z:\temp\godot_touhou_phase7\reports\bgm_longform_review.html`.
- [ ] Stop and ask the user to mark each track `accept` or `regenerate`. The listening instructions must explicitly reject an audible six-times 30-second repeat structure even when automatic QA only emitted a warning. Do not copy into `accepted_masters`, create runtime OGG files, or integrate BGM before all twelve long-form masters are accepted.

## Completion Criteria

- The all-B human selection is recorded and matches twelve candidate SHA256 values.
- Long-form catalog, guide/DSP, runner, and QA tests pass and receive independent review.
- Twelve Stable Audio sources are exactly 188 seconds and manifest records zero failures.
- Twelve review masters are exactly 180 seconds, pass loop-transition checks, meet -17 to -15 LUFS and <= -1 dBTP, and have transition previews.
- Review HTML exposes all twelve tracks and loop transitions.
- No generated audio exists in the Godot repository.
- Phase 7B stops at the explicit long-form human acceptance gate.
