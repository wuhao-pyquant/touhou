# Phase 7 Audio Production Design

## Goal

Produce the complete audio identity for the original Hyakki Night Festival danmaku game. Phase 7 replaces every placeholder BGM, supplies one stage and one boss theme for all six stages, expands the SFX library, and integrates accepted runtime audio without weakening gameplay readability or frame stability.

Music generation runs on the SSH-connected `mac-mini-m4` through its existing Stable Audio 3 Medium MLX setup. Generated files are staged on the shared NAS and are not copied into the Godot repository until they pass both technical QA and human listening review.

## Approved Direction

- Twelve BGM tracks: one stage theme and one boss theme for each of six stages.
- Each final BGM is exactly 180 seconds and loops seamlessly.
- Every track has an independent melody. Cohesion comes from instrumentation, mix language, rhythmic signatures, and harmonic color rather than melody reuse.
- Shared style: Japanese festival instrumentation plus electronic rock.
- Tracks are primarily instrumental.
- Stages 1 through 4 contain no voices. Stages 5 and 6 may use restrained wordless shouts or choir behind gameplay cues.
- SFX use arcade clarity first, layered with Japanese festival texture.
- Existing stage 1 through 3 placeholder music is replaced. Stage 4 through 6 music is added.
- No existing Touhou Project music, melody, character, protected name, or recognizable arrangement may be referenced or imitated.

## Non-Negotiable Gameplay Audio Standard

Audio must serve playability. No generated asset is acceptable if it masks a survival cue, produces fatigue during dense patterns, or makes repeated actions collapse into a noise wall.

- Player hit, deathbomb, and laser warning cues have the highest priority.
- Spell announcements and boss phase cues must remain audible during boss-theme climaxes.
- Graze and key-resource cues must remain identifiable without becoming shrill.
- Repetitive player-shot and enemy-hit sounds must be rate-limited and voice-limited.
- Stage BGM must leave spectral room for warnings and high-frequency projectile cues.
- Boss BGM may be denser than stage BGM but must still leave short cue windows.
- Wordless vocal layers must stay behind gameplay cues and must never resemble dialogue.
- Every accepted mix must be reviewed in a representative gameplay recording, not only in isolation.

## Scope

In scope:

- Twelve generated BGM tracks and their prompt, seed, and QA records.
- Two 30-second candidates for each BGM before long-form production.
- One accepted 188-second long-form source per track, processed into an exact 180-second seamless loop.
- Runtime OGG conversion and Godot BGM integration.
- A full gameplay and UI SFX library.
- Priority-aware SFX playback and repetitive-cue throttling.
- Automated format, loudness, clipping, silence, loop, path, and loading tests.
- Human listening gates before repository integration.

Out of scope:

- Voice acting, dialogue audio, or sung lyrics.
- Copying or imitating existing Touhou Project music.
- Keeping rejected candidates in the repository.
- Adding uncompressed BGM masters to Git history.
- Final whole-game balance and practice-mode QA, which remain Phase 8.

## Soundtrack Matrix

| Key | Chinese title | BPM | Narrative and arrangement role |
|---|---|---:|---|
| `stage1_mid` | `灯火初参道` | 150 | Warm, bright exploration with flute, koto-like accents, light taiko, and restrained electronic drums. |
| `stage1_boss` | `引路狐的第一夜` | 172 | Agile and mischievous; shamisen-like plucks trade phrases with electronic guitar. |
| `stage2_mid` | `百物市的交易铃` | 156 | Busy market motion that gradually destabilizes; wood blocks, abacus-like percussion, and jumping bass. |
| `stage2_boss` | `鬼市掌柜的算盘火` | 176 | Forceful negotiation and oni pressure; taiko, heavy bass, and sharper synth lead. |
| `stage3_mid` | `雾竹回廊` | 148 | Dreamlike disorientation and wrong paths; breathy flute, delayed figures, and controlled percussion. |
| `stage3_boss` | `月影幻术师` | 174 | Reversed-feeling phrases and unstable harmony; fast arpeggios without an overfilled drum mix. |
| `stage4_mid` | `风上新闻飞行` | 166 | Fast ascent and pursuit; running flute lines, snare propulsion, and wind-like synth motion. |
| `stage4_boss` | `改写天幕的山风` | 184 | A direct aerial duel; electronic rock core with tremolo plucks and forceful taiko. |
| `stage5_mid` | `鬼宴未散` | 170 | Dangerous celebration and rhythm bullets; layered taiko and low, restrained wordless shouts. |
| `stage5_boss` | `朱鼓醉姬` | 188 | Heavy, intoxicated pressure; large drums, aggressive rock, and background festival calls. |
| `stage6_mid` | `万灯渡神域` | 176 | Sacred scale turning overwhelming; wide synths, lantern-like accents, and low-mixed wordless choir. |
| `stage6_boss` | `百鬼夜祭神` | 194 | Final divine confrontation; multi-section synthesis of taiko, electronic rock, festival instruments, and choir. |

The stage and boss themes within one stage may share a mode, cadence shape, or rhythmic signature. They must not share the same lead melody.

## Cross-Machine Production Architecture

The production path is:

```text
Windows Codex controller
  -> SSH remote task on mac-mini-m4
  -> Stable Audio 3 Medium MLX generation
  -> NAS staging directory
  -> Windows technical QA and human listening gate
  -> accepted runtime conversion
  -> Godot repository integration
```

The same NAS share is visible at:

```text
Windows: Z:\temp\godot_touhou_phase7\
macOS:   /Volumes/personal_folder/temp/godot_touhou_phase7/
```

Required staging directories:

```text
bgm_candidates/<track_key>/
bgm_guides/<track_key>/
bgm_longform/<track_key>/
accepted_masters/
sfx_candidates/<sfx_key>/
reports/
```

Generated WAV files stay in staging until accepted. The Godot repository receives only approved runtime BGM files, approved short SFX assets, manifests, scripts, tests, and documentation.

## BGM Candidate Production

Each of the twelve tracks first receives two 30-second candidates, `A` and `B`, for a total of 24 candidate files.

Candidate defaults:

- Model: Stable Audio 3 Medium with SAME-L through the existing MLX script.
- Duration: 30 seconds.
- Sampling steps: 8.
- CFG: start at 2.0, with a permitted range of 1.0 to 3.0 when a prompt is under- or over-constrained.
- Seed: deterministic and recorded; candidates A and B use different seeds.
- Output: 44.1 kHz, 16-bit PCM, stereo WAV.
- Prompt language: original Japanese night-festival fantasy, exact BPM, loopable phrase, no intro, no outro, steady pulse, instrumental restrictions, and track-specific instrumentation.
- Negative language: no existing franchise melody, no lyrics, no spoken words, no cinematic fade-out, no ambient-only drift, no uncontrolled tempo change, no harsh noise, and no excessive reverb.

Naming convention:

```text
bgm_stage01_mid_A_seed-<seed>.wav
bgm_stage01_mid_B_seed-<seed>.wav
```

Every candidate is accompanied by a manifest record containing its track key, title, prompt, negative prompt, model, duration, steps, CFG, seed, output path, SHA-256, generation status, and QA status.

After automatic QA, the user selects A, B, or requests regeneration for that track. Candidate selection is a human gate and cannot be replaced by waveform metrics.

## Long-Form Development And Looping

The selected 30-second candidate becomes the melodic and timbral guide for an evolving 188-second arrangement. It is not simply repeated six times in the final master.

The guide has six macro sections:

1. Theme establishment.
2. First variation.
3. Reduced-intensity breathing section.
4. Rebuild and instrumentation expansion.
5. Stage-appropriate climax.
6. Return to the theme and loop preparation.

The guide is expanded to 188 seconds and passed through Stable Audio audio-to-audio generation. The default `init-noise-level` is 0.55:

- Lower to 0.45 when the melody or rhythmic identity drifts too far.
- Raise to 0.65 when the result is too repetitive.
- Keep 8 sampling steps as the production default.
- Keep a fixed production seed for reproducibility; use a new recorded seed only for an intentional variant.

Stable Audio has no native seamless-loop guarantee. Final looping is deterministic:

- Generate a 188-second long-form source.
- Use the final 8 seconds and initial 8 seconds for a circular equal-power crossfade.
- Join that blended opening to source seconds 8 through 180.
- Produce an exact 180-second master.
- Render ten consecutive loops and verify there is no click, beat discontinuity, abrupt spectral change, or level jump.

## Mastering And Runtime Format

Accepted BGM WAV masters remain under the NAS `accepted_masters` directory. They are the lossless review and recovery source.

Runtime BGM files are converted to OGG Vorbis:

- 44.1 kHz stereo.
- Approximately 192 to 224 kbps, using a consistent quality setting across all tracks.
- Integrated loudness target around -16 LUFS, permitted range -17 to -15 LUFS.
- True peak no higher than -1 dBTP.
- No clipping, NaN samples, long unintended silence, or DC offset.

Runtime files are named:

```text
audio/bgm/bgm_stage1_mid.ogg
audio/bgm/bgm_stage1_boss.ogg
...
audio/bgm/bgm_stage6_boss.ogg
```

The repository does not track the large lossless BGM masters. This keeps the runtime download and Git history proportionate while preserving lossless masters on the shared storage.

## SFX Library

SFX use arcade clarity as the primary layer and Japanese festival texture as a secondary layer. Source layers may be generated with the local Stable Audio SFX-capable model and then edited deterministically.

Required families:

- Six protagonist shot variants.
- Enemy hit and boss hit.
- Enemy defeat and boss phase clear.
- Graze.
- Item collection, life gain, and bomb gain.
- Bomb start, loop, and finish for each of three protagonists.
- Menu move, confirm, back, and pause.
- Spell-card announcement.
- Laser warning and laser activation.
- Player hit and deathbomb window.

Short transient SFX remain WAV when that avoids decode latency. Longer bomb loops or sustained laser layers may use OGG when appropriate.

SFX source peaks are normalized consistently without baking gameplay mix offsets into the files. Runtime category gain and priority determine the final mix.

## Runtime Integration

`AudioManager` remains the central audio owner.

BGM integration:

- Expand the BGM catalog to all twelve stable keys.
- Use two players for transition crossfades.
- Enable looping on every accepted BGM stream.
- Cache compressed OGG resources and avoid uncompressed 180-second WAV preloads.
- Preserve pause ducking and settings volume behavior.

SFX integration:

- Replace the single undifferentiated eight-player pool with priority-aware pools.
- Reserve four critical voices for player hit, deathbomb, and laser warning cues.
- Provide eight gameplay voices for graze, items, boss hits, and phase cues.
- Provide twelve ambient-action voices for shots, ordinary hits, and defeats.
- Rate-limit repetitive shots and hits by cue key and minimum interval.
- When a pool is full, steal the oldest sound only within the same or lower priority group.

`AssetRegistry` remains the authoritative stable-key surface. Stage routing continues to request `stageN_mid` and `stageN_boss` keys through the existing stage director and main scene flow.

## QA And Acceptance Gates

### Candidate gate

- File exists in NAS staging.
- Correct WAV format, duration, sample rate, and channel count.
- No clipping, invalid samples, long silence, or corrupt output.
- Prompt, seed, and SHA-256 are recorded.
- Human selection accepts A or B, or requests regeneration.

### Master gate

- Exactly 180 seconds after loop processing.
- Ten-loop render has no audible seam.
- Loudness and true peak meet the mastering range.
- Track matches its narrative role and BPM intent.
- Track is melodically distinct from the other eleven tracks.
- Shared palette remains cohesive across all six stages.
- Gameplay cues remain readable in a representative gameplay mix.

### Integration gate

- All twelve BGM keys resolve to loadable OGG files.
- Every BGM stream loops and crossfades without an unknown-key warning.
- SFX keys resolve to loadable files.
- Critical SFX cannot be starved by repetitive shot or hit sounds.
- Settings, pause ducking, and scene transitions still work.
- Headless tests and a game smoke run pass.

## Error Handling And Resume Safety

- Generation writes to a temporary filename and renames only after WAV validation succeeds.
- Existing accepted files are never overwritten without an explicit version suffix.
- Missing NAS mount or insufficient free space stops generation before model loading.
- Every job records `planned`, `generating`, `generated`, `qa_failed`, `selected`, `mastered`, `accepted`, `integrated`, or `rejected` status.
- Failed jobs retain their prompt and seed so they can be reproduced.
- Windows integration verifies SHA-256 after copying an accepted runtime asset into the project.
- Re-running the pipeline skips accepted outputs unless an explicit force flag is supplied.

## Testing Strategy

Automated tests will cover:

- Twelve BGM catalog entries and stable paths.
- Audio file existence and loadability.
- BGM loop flags and 180-second duration tolerance.
- Runtime OGG format expectations.
- SFX key completeness.
- Priority-pool starvation protection.
- Repetitive-cue throttling.
- Existing pause ducking, settings, and crossfade behavior.
- Manifest schema, unique ids, status values, paths, and SHA-256 fields.
- A headless project smoke run after audio import.

Deterministic tooling will cover:

- Candidate manifest generation.
- `ffprobe` format inspection.
- `ffmpeg` loudness, clipping, silence, and spectrum reports.
- 188-to-180-second circular loop rendering.
- Ten-loop seam test rendering.
- OGG conversion and checksum verification.

Human review remains mandatory for melody quality, emotional fit, style cohesion, fatigue, and cue readability.

## Success Criteria

Phase 7 is complete when:

- The user has selected and accepted all twelve BGM tracks.
- Twelve exact 180-second seamless-loop runtime OGG files are integrated.
- Stage 1 through 3 placeholders are gone and stages 4 through 6 have complete music.
- The required SFX library is integrated with priority-aware playback.
- Automated audio, manifest, and Godot tests pass.
- Representative gameplay confirms that music and effects do not obscure survival cues.
- Lossless accepted masters remain available in NAS storage and are traceable by manifest checksum.
- No protected existing Touhou Project music or recognizable arrangement is used.

## User Approval State

The user approved:

- Twelve independent but cohesive tracks aligned to the six-stage story progression.
- Exact 180-second seamless loops.
- Japanese festival instrumentation plus electronic rock.
- Primarily instrumental music with limited wordless voices only in stages 5 and 6 and selected bosses.
- Arcade-clear SFX with Japanese festival texture.
- Two 30-second candidates per track followed by selected-theme long-form development.
- Generation on `mac-mini-m4` through Stable Audio 3 Medium.
- NAS staging at `Z:\temp`, with project transfer only after acceptance.
- Runtime OGG integration while retaining lossless accepted masters on the NAS.
