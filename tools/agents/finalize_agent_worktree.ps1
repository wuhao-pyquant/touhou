[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Worktree,

    [string]$TargetBranch = 'master',
    [string]$SupersededBy,
    [string]$SupersededReason,
    [string]$Report,
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'
$repoRoot = (& git rev-parse --show-toplevel).Trim()
if (-not $repoRoot) {
    throw 'finalize_agent_worktree.ps1 must be run inside a Git repository.'
}

$pythonArgs = @(
    (Join-Path $repoRoot 'tools\agents\finalize_agent_worktree.py'),
    '--repo-root', $repoRoot,
    '--worktree', $Worktree,
    '--target-branch', $TargetBranch
)
if ($SupersededBy) {
    $pythonArgs += @('--superseded-by', $SupersededBy)
}
if ($SupersededReason) {
    $pythonArgs += @('--superseded-reason', $SupersededReason)
}
if ($Report) {
    $pythonArgs += @('--report', $Report)
}
if ($Apply) {
    $pythonArgs += '--apply'
}

& python @pythonArgs
exit $LASTEXITCODE
