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

## Verify Generation Manifest On Windows

```powershell
$root = 'Z:\temp\godot_touhou_phase7'
$manifest = Get-Content "$root\reports\generation_manifest.json" -Raw -Encoding UTF8 | ConvertFrom-Json
if ($manifest.failure_count -ne 0) { throw "Generation failures: $($manifest.failure_count)" }
$valid = @($manifest.jobs | Where-Object { $_.status -in @('generated','skipped_valid') })
if ($valid.Count -ne 24) { throw "Expected 24 generated jobs, got $($valid.Count)" }
```

Success requires `Z:\temp\godot_touhou_phase7\reports\generation_manifest.json` to report `failure_count: 0` and `24` jobs in `generated` or `skipped_valid` status.

## Validate And Build Review Page On Windows

```powershell
python tools\audio\phase7_candidate_qa.py `
  --catalog audio\production\phase7_bgm_jobs.json `
  --staging-root Z:\temp\godot_touhou_phase7
```

Then verify the QA report:

```powershell
$root = 'Z:\temp\godot_touhou_phase7'
$qa = Get-Content "$root\reports\candidate_qa.json" -Raw -Encoding UTF8 | ConvertFrom-Json
if ($qa.pass_count -ne 24) { throw "Expected 24 QA passes, got $($qa.pass_count)" }
if ($qa.fail_count -ne 0) { throw "Expected 0 QA failures, got $($qa.fail_count)" }
```

Success requires `24` passes and `0` failures in:

`Z:\temp\godot_touhou_phase7\reports\candidate_qa.json`

Open:

`Z:\temp\godot_touhou_phase7\reports\bgm_candidate_review.html`

Listen to A and B for every track and record one of `A`, `B`, or `regenerate`. Phase 7B does not start until all twelve tracks have a human selection.
