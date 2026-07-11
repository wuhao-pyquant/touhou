# Phase 7 长版 BGM Operator Workflow

本文档是 Phase 7B Task 5 的执行手册。目标是在不向仓库写入生成音频的前提下，把已人工选定的 12 个 `B` 候选扩展为 12 个 188 秒长版源，完成 180 秒 review master 与 transition preview，并停在人工听辨验收门。

## 1. 边界与前提

- 工作树：`H:\claude code\godot_touhou\.worktrees\phase7-audio`
- Windows staging：`Z:\temp\godot_touhou_phase7`
- macOS staging：`/Volumes/personal_folder/temp/godot_touhou_phase7`
- Mac wrapper：`/Users/wuhao/Documents/music/stable-audio-3-medium.sh`
- 仓库内只允许修改：`docs/audio/phase7_longform_workflow.md`
- 生成的 WAV / OGG 不得写入仓库 `audio/bgm` 或 `audio/sfx`
- `accepted_masters` 在本阶段必须保持为空
- 正常恢复必须使用 resume 语义，不加 `--force`

所有 PowerShell JSON 解析都显式使用 UTF-8：

```powershell
Get-Content <path> -Raw -Encoding UTF8 | ConvertFrom-Json
```

## 2. 先决检查

在 Windows 工作树根目录执行：

```powershell
git rev-parse --short HEAD
git status --short
```

预期：

- `HEAD` 为 `f1d1724`
- 不回退其他工作者改动

确认选择记录存在且保持人工 all-B 结果：

```powershell
$root = 'Z:\temp\godot_touhou_phase7'
$selection = Get-Content "$root\reports\bgm_candidate_selection.json" -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $selection.selection_complete) { throw 'selection_complete must be true' }
if (@($selection.tracks).Count -ne 12) { throw 'selection must contain 12 tracks' }
if (@($selection.tracks | Where-Object { $_.variant -ne 'B' }).Count -ne 0) { throw 'all selected variants must be B' }
```

不要改写 `bgm_candidate_selection.json`，也不要生成伪造 selection 数据。

## 3. 运行全部 Phase 7A / 7B 单元测试

在工作树根目录执行：

```powershell
python -m unittest `
  tests.test_phase7_bgm_catalog `
  tests.test_phase7_candidate_qa `
  tests.test_phase7_candidate_runner `
  tests.test_phase7_candidate_workflow `
  tests.test_phase7_longform_audio `
  tests.test_phase7_longform_catalog `
  tests.test_phase7_longform_qa `
  tests.test_phase7_longform_runner
```

要求：

- 命令退出码为 `0`
- 输出包含 `OK`
- 记录实际测试总数，不在文档或报告里写死预期值

如果失败：

1. 停止后续生成
2. 记录失败测试名、退出码、标准输出/标准错误摘要
3. 仅在修复获得批准后再重跑

## 4. 发布 control 文件并逐文件校验 SHA256

PowerShell：

```powershell
$repo = 'H:\claude code\godot_touhou\.worktrees\phase7-audio'
$root = 'Z:\temp\godot_touhou_phase7'
$control = Join-Path $root 'control'
New-Item -ItemType Directory -Force -Path $control | Out-Null

$files = @(
  @{ Source = "$repo\audio\production\phase7_bgm_jobs.json"; Target = "$control\phase7_bgm_jobs.json" },
  @{ Source = "$repo\audio\production\phase7_bgm_longform_jobs.json"; Target = "$control\phase7_bgm_longform_jobs.json" },
  @{ Source = "$repo\tools\audio\phase7_catalog.py"; Target = "$control\phase7_catalog.py" },
  @{ Source = "$repo\tools\audio\phase7_longform_catalog.py"; Target = "$control\phase7_longform_catalog.py" },
  @{ Source = "$repo\tools\audio\phase7_longform_audio.py"; Target = "$control\phase7_longform_audio.py" },
  @{ Source = "$repo\tools\audio\phase7_longform_runner.py"; Target = "$control\phase7_longform_runner.py" },
  @{ Source = "$repo\tools\audio\phase7_longform_qa.py"; Target = "$control\phase7_longform_qa.py" }
)

foreach ($file in $files) {
  Copy-Item $file.Source $file.Target -Force
  $srcHash = (Get-FileHash $file.Source -Algorithm SHA256).Hash.ToLowerInvariant()
  $dstHash = (Get-FileHash $file.Target -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($srcHash -ne $dstHash) {
    throw "SHA mismatch: $($file.Target)`nsource=$srcHash`ntarget=$dstHash"
  }
}
```

要求：

- 逐文件记录 source/target SHA256
- 只覆盖 `control/`，不覆盖 selection 记录

如果 SHA 不一致：

1. 立即停止
2. 删除不一致目标文件
3. 检查 NAS / SMB 写入是否完成后再单文件重试

## 5. Mac 并发检查与正常 resume 生成

先在 Windows 发起 SSH 并确认无并发 runner / wrapper：

```powershell
ssh mac-mini-m4 "ps -axo pid=,command= | grep -E 'phase7_longform_runner|stable-audio-3-medium\\.sh' | grep -v grep"
```

预期无输出。若有输出：

1. 不启动第二个 runner
2. 先确认现有进程是否仍在合法运行
3. 只有在现有进程结束或人工确认可接管后才继续

正常 resume 生成命令：

```powershell
ssh mac-mini-m4 @'
cd /Volumes/personal_folder/temp/godot_touhou_phase7/control &&
python3 phase7_longform_runner.py \
  --catalog phase7_bgm_longform_jobs.json \
  --selection /Volumes/personal_folder/temp/godot_touhou_phase7/reports/bgm_candidate_selection.json \
  --staging-root /Volumes/personal_folder/temp/godot_touhou_phase7 \
  --generator /Users/wuhao/Documents/music/stable-audio-3-medium.sh
'@
```

要求：

- 不加 `--force`
- 等待该 SSH 命令实际结束
- 不中途并发启动第二个 runner

恢复原则：

- 已有效生成的 188 秒源允许被 runner 以 `skipped_valid` 跳过
- 若 manifest 指纹不匹配而出现 `existing_stale`，停止并调查，不要手工覆盖
- 若残留 `.partial.wav`，让 runner 在下次启动前清理；若未清理，先记录再人工处理

## 6. Windows 验证长版源 manifest 与帧数

PowerShell：

```powershell
$root = 'Z:\temp\godot_touhou_phase7'
$manifest = Get-Content "$root\reports\longform_generation_manifest.json" -Raw -Encoding UTF8 | ConvertFrom-Json

if ($manifest.failure_count -ne 0) {
  throw "Generation failures: $($manifest.failure_count)"
}

$valid = @($manifest.jobs | Where-Object { $_.status -in @('generated', 'skipped_valid') })
if ($valid.Count -ne 12) {
  throw "Expected 12 valid jobs, got $($valid.Count)"
}

$partials = Get-ChildItem "$root\bgm_longform" -Recurse -Filter *.partial.wav -ErrorAction SilentlyContinue
if ($partials.Count -ne 0) {
  throw "Unexpected partial files: $($partials.Count)"
}

foreach ($job in $valid) {
  $probe = & ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate,channels,bits_per_sample,duration_ts -of json $job.output_path | ConvertFrom-Json
  $stream = $probe.streams[0]
  if ($stream.sample_rate -ne 44100) { throw "sample_rate mismatch: $($job.track_key)" }
  if ($stream.channels -ne 2) { throw "channel mismatch: $($job.track_key)" }
  if ($stream.bits_per_sample -ne 16) { throw "bit depth mismatch: $($job.track_key)" }
  if ($stream.duration_ts -ne 8290800) { throw "frame mismatch: $($job.track_key) -> $($stream.duration_ts)" }
}
```

成功条件：

- `failure_count == 0`
- `generated` 或 `skipped_valid` 共 12 条
- 无 `*.partial.wav`
- 每个源精确 `188 * 44100 = 8,290,800` 帧

## 7. Windows mastering / QA / review HTML

执行：

```powershell
python tools\audio\phase7_longform_qa.py `
  --catalog audio\production\phase7_bgm_longform_jobs.json `
  --staging-root Z:\temp\godot_touhou_phase7 `
  --ffmpeg ffmpeg
```

验证：

```powershell
$root = 'Z:\temp\godot_touhou_phase7'
$qa = Get-Content "$root\reports\longform_qa.json" -Raw -Encoding UTF8 | ConvertFrom-Json

if ($qa.pass_count -ne 12) { throw "Expected 12 passes, got $($qa.pass_count)" }
if ($qa.fail_count -ne 0) { throw "Expected 0 failures, got $($qa.fail_count)" }

$reviewHtml = Join-Path $root 'reports\bgm_longform_review.html'
if (-not (Test-Path $reviewHtml)) { throw 'review HTML missing' }

foreach ($track in $qa.tracks) {
  $master = Join-Path "$root\reports" $track.relative_master_path
  $preview = Join-Path "$root\reports" $track.relative_preview_path

  foreach ($path in @($master, $preview)) {
    if (-not (Test-Path $path)) { throw "missing artifact: $path" }
  }

  $masterProbe = & ffprobe -v error -select_streams a:0 -show_entries stream=duration_ts -of json $master | ConvertFrom-Json
  if ($masterProbe.streams[0].duration_ts -ne 7938000) {
    throw "master frame mismatch: $($track.track_key)"
  }

  $previewProbe = & ffprobe -v error -select_streams a:0 -show_entries stream=duration_ts -of json $preview | ConvertFrom-Json
  if ($previewProbe.streams[0].duration_ts -ne 1323000) {
    throw "preview frame mismatch: $($track.track_key)"
  }

  $html = Get-Content $reviewHtml -Raw -Encoding UTF8
  if ($html -notmatch [regex]::Escape($track.relative_master_path)) { throw "HTML missing master reference: $($track.track_key)" }
  if ($html -notmatch [regex]::Escape($track.relative_preview_path)) { throw "HTML missing preview reference: $($track.track_key)" }
}
```

成功条件：

- `pass_count == 12`
- `fail_count == 0`
- 12 个 review masters 均精确 `180 * 44100 = 7,938,000` 帧
- 12 个 previews 均精确 `30 * 44100 = 1,323,000` 帧
- review HTML 引用了全部 master 和 preview

## 8. 仓库清洁检查

确保仓库目录没有新增生成音频：

```powershell
Get-ChildItem 'audio\bgm' -File | Select-Object Name,Length
Get-ChildItem 'audio\sfx' -File | Select-Object Name,Length
git status --short
```

要求：

- `audio/bgm` 与 `audio/sfx` 没有新增生成 WAV / OGG
- 不创建 runtime OGG
- 不做 Godot 集成

## 9. 人工验收门

review 页面路径：

```text
Z:\temp\godot_touhou_phase7\reports\bgm_longform_review.html
```

到此必须停止并交给人工听辨。人工对每条轨道只允许给出：

- `accept`
- `regenerate`

必须明确提醒：

- 自动 QA 通过不代表音乐结构已可接受
- 即使自动 QA 只给出 warning，只要听到明显六次 30 秒重复结构，也必须选择 `regenerate`
- 在 12 条全部人工 `accept` 前，不得复制到 `accepted_masters`，不得生成 runtime OGG，不得集成进游戏

## 10. 常见失败恢复

### control 文件 SHA 不一致

- 停止执行
- 删除目标文件
- 重新复制单文件并再次校验 SHA

### Mac 上发现已有 runner / wrapper

- 不并发启动第二个实例
- 先确认旧任务状态
- 需要恢复时复用正常 resume 命令，不加 `--force`

### generation manifest 存在失败或 `existing_stale`

- 不手工覆盖现有 source
- 记录失败 job、fingerprint 与错误文本
- 修正 control / 输入后再次正常 resume

### 存在 `.partial.wav`

- 先记录路径
- 确认没有活动进程后再清理或交给 runner 下次清理

### QA 未达 12 pass / 0 fail

- 不发布为可验收结果
- 记录失败轨道、LUFS / true peak / loop 指标
- 返回 regenerate / repair 决策所需证据
