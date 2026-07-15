[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Agent,

    [Parameter(Mandatory = $true, ParameterSetName = 'Fresh')]
    [string]$Ticket,

    [Parameter(Mandatory = $true, ParameterSetName = 'Resume')]
    [string]$ResumeRun,

    [Parameter(ParameterSetName = 'Resume')]
    [ValidateRange(1, 2)]
    [int]$EscalationLevel,

    [Parameter(ParameterSetName = 'Resume')]
    [switch]$TransportRetry,

    [Parameter(ParameterSetName = 'Resume')]
    [string]$RepairInstruction,

    [Parameter(ParameterSetName = 'Resume')]
    [string]$ReviewFailureRun,

    [Parameter(ParameterSetName = 'Resume')]
    [switch]$ValidationRetry,

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
    '--agent', $Agent
)

if ($PSCmdlet.ParameterSetName -eq 'Resume') {
    $pythonArgs += @('--resume-run', $ResumeRun)
    if ($TransportRetry) {
        $pythonArgs += '--transport-retry'
    }
    elseif ($PSBoundParameters.ContainsKey('EscalationLevel')) {
        $pythonArgs += @('--escalation-level', $EscalationLevel)
    }
    if ($RepairInstruction) {
        $pythonArgs += @('--repair-instruction', $RepairInstruction)
    }
    if ($ReviewFailureRun) {
        $pythonArgs += @('--review-failure-run', $ReviewFailureRun)
    }
    if ($ValidationRetry) {
        $pythonArgs += '--validation-retry'
    }
}
else {
    $pythonArgs += @('--ticket', $Ticket)
}

if ($DryRun) {
    $pythonArgs += '--dry-run'
}
if ($KeepWorktree) {
    $pythonArgs += '--keep-worktree'
}

& python @pythonArgs
exit $LASTEXITCODE
