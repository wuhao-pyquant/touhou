[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Agent,

    [Parameter(Mandatory = $true)]
    [string]$Ticket,

    [switch]$DryRun,
    [switch]$KeepWorktree
)

$ErrorActionPreference = 'Stop'
$repoRoot = (& git rev-parse --show-toplevel).Trim()
if (-not $repoRoot) {
    throw 'invoke_agent.ps1 must be run inside a Git repository.'
}

$pythonArgs = @(
    (Join-Path $repoRoot 'tools\agents\invoke_agent.py'),
    '--repo-root', $repoRoot,
    '--agent', $Agent,
    '--ticket', $Ticket
)

if ($DryRun) {
    $pythonArgs += '--dry-run'
}
if ($KeepWorktree) {
    $pythonArgs += '--keep-worktree'
}

& python @pythonArgs
exit $LASTEXITCODE
