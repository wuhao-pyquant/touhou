[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$GodotPath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ProjectPath,

    # Repeat this parameter for each engine argument.  This avoids PowerShell
    # interpreting Godot flags such as --script as runner parameters.
    [Alias('GodotArguments')]
    [string[]]$GodotArgument,

    # JSON form is convenient for callers that use powershell.exe -File,
    # whose Windows PowerShell 5.1 argument binder cannot pass string arrays.
    [string]$GodotArgumentJson,

    [ValidateRange(1, 86400)]
    [int]$TimeoutSeconds = 120,

    [string]$LogFile,

    [switch]$CleanupExisting,

    # Test-only deterministic process inventory fixture. Production callers do
    # not use this parameter; it exists so the fake-process suite does not
    # need elevated WMI access.
    [string]$ProcessInventoryFixture,

    [ValidateRange(25, 5000)]
    [int]$PollMilliseconds = 100
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ExitCodes = @{
    Success = 0
    ProcessFailure = 1
    Timeout = 2
    FatalOutput = 3
    LockContention = 4
    PreexistingHeadlessProcess = 5
    InvalidInput = 6
    CleanupFailure = 7
    LaunchFailure = 8
}

function Get-RunnerHash([string]$Value) {
    $bytes = [Text.Encoding]::UTF8.GetBytes($Value.ToLowerInvariant())
    $hash = [Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
    return ([BitConverter]::ToString($hash)).Replace('-', '').Substring(0, 32)
}

function ConvertTo-WindowsCommandLineArgument([string]$Value) {
    if ($Value.Length -eq 0) { return '""' }
    if ($Value -notmatch '[\s"]') { return $Value }

    $builder = New-Object Text.StringBuilder
    [void]$builder.Append('"')
    $slashes = 0
    foreach ($character in $Value.ToCharArray()) {
        if ($character -eq '\') {
            $slashes++
            continue
        }
        if ($character -eq '"') {
            [void]$builder.Append(('\' * (($slashes * 2) + 1)))
            [void]$builder.Append('"')
            $slashes = 0
            continue
        }
        if ($slashes -gt 0) {
            [void]$builder.Append(('\' * $slashes))
            $slashes = 0
        }
        [void]$builder.Append($character)
    }
    if ($slashes -gt 0) {
        [void]$builder.Append(('\' * ($slashes * 2)))
    }
    [void]$builder.Append('"')
    return $builder.ToString()
}

function Get-RunnerProcessSnapshot([string]$CommandLineImageName) {
    $fixtureRecords = @()
    if (-not [string]::IsNullOrWhiteSpace($ProcessInventoryFixture)) {
        if (-not (Test-Path -LiteralPath $ProcessInventoryFixture -PathType Leaf)) {
            throw "Process inventory fixture does not exist: $ProcessInventoryFixture"
        }
        $fixtureRecords = @(Get-Content -LiteralPath $ProcessInventoryFixture | ForEach-Object {
            if (-not [string]::IsNullOrWhiteSpace($_)) {
                $record = $_ | ConvertFrom-Json
                if (Get-Process -Id ([int]$record.ProcessId) -ErrorAction SilentlyContinue) { $record }
            }
        } | ForEach-Object {
            [pscustomobject]@{
                ProcessId = [long]$_.ProcessId
                ParentProcessId = [long]$_.ParentProcessId
                ExecutablePath = [string]$_.ExecutablePath
                CommandLine = [string]$_.CommandLine
            }
        })
    }
    try {
        return @($fixtureRecords + @(Get-CimInstance -ClassName Win32_Process -ErrorAction Stop | ForEach-Object {
            [pscustomobject]@{
                ProcessId = [long]$_.ProcessId
                ParentProcessId = [long]$_.ParentProcessId
                ExecutablePath = [string]$_.ExecutablePath
                CommandLine = [string]$_.CommandLine
            }
        }))
    } catch {
        # Some restricted Windows hosts deny WMI/CIM process reads.  Use the
        # native snapshot fallback rather than silently dropping the guard.
        if (-not ('GodotTestRunner.NativeProcessSnapshot' -as [type])) {
            Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
namespace GodotTestRunner {
  public sealed class ProcessRecord { public int ProcessId; public int ParentProcessId; public string ExecutablePath; public string CommandLine; }
  public static class NativeProcessSnapshot {
    const uint TH32CS_SNAPPROCESS = 2, PROCESS_QUERY_LIMITED_INFORMATION = 0x1000;
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] struct PROCESSENTRY32 { public uint dwSize,cntUsage,th32ProcessID,th32DefaultHeapID,th32ModuleID,cntThreads,th32ParentProcessID,pcPriClassBase,dwFlags; [MarshalAs(UnmanagedType.ByValTStr, SizeConst=260)] public string szExeFile; }
    [StructLayout(LayoutKind.Sequential)] struct UNICODE_STRING { public ushort Length, MaximumLength; public IntPtr Buffer; }
    [DllImport("kernel32.dll", SetLastError=true)] static extern IntPtr CreateToolhelp32Snapshot(uint flags, uint processId);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool Process32First(IntPtr snapshot, ref PROCESSENTRY32 entry);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool Process32Next(IntPtr snapshot, ref PROCESSENTRY32 entry);
    [DllImport("kernel32.dll", SetLastError=true)] static extern IntPtr OpenProcess(uint access, bool inherit, int processId);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
    [DllImport("ntdll.dll")] static extern int NtQueryInformationProcess(IntPtr process, int infoClass, IntPtr buffer, int length, out int returnLength);
    static string CommandLineFor(int pid) { IntPtr h=OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION,false,pid); if(h==IntPtr.Zero) return null; try { int n; NtQueryInformationProcess(h,60,IntPtr.Zero,0,out n); if(n<=0) return null; IntPtr b=Marshal.AllocHGlobal(n); try { if(NtQueryInformationProcess(h,60,b,n,out n)!=0) return null; var u=(UNICODE_STRING)Marshal.PtrToStructure(b,typeof(UNICODE_STRING)); return u.Buffer==IntPtr.Zero ? null : Marshal.PtrToStringUni(u.Buffer,u.Length/2); } finally { Marshal.FreeHGlobal(b); } } finally { CloseHandle(h); } }
    public static ProcessRecord[] Get(string expectedImageName) { var result=new List<ProcessRecord>(); IntPtr s=CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS,0); if(s==new IntPtr(-1)) return result.ToArray(); try { var e=new PROCESSENTRY32(); e.dwSize=(uint)Marshal.SizeOf(typeof(PROCESSENTRY32)); if(!Process32First(s,ref e)) return result.ToArray(); do { string cmd=String.IsNullOrEmpty(expectedImageName) || !String.Equals(e.szExeFile,expectedImageName,StringComparison.OrdinalIgnoreCase) ? null : CommandLineFor((int)e.th32ProcessID); result.Add(new ProcessRecord { ProcessId=(int)e.th32ProcessID, ParentProcessId=(int)e.th32ParentProcessID, ExecutablePath=null, CommandLine=cmd }); e.dwSize=(uint)Marshal.SizeOf(typeof(PROCESSENTRY32)); } while(Process32Next(s,ref e)); return result.ToArray(); } finally { CloseHandle(s); } }
  }
}
'@
        }
        return @($fixtureRecords + @([GodotTestRunner.NativeProcessSnapshot]::Get($CommandLineImageName) | ForEach-Object {
            [pscustomobject]@{
                ProcessId = [long]$_.ProcessId
                ParentProcessId = [long]$_.ParentProcessId
                ExecutablePath = [string]$_.ExecutablePath
                CommandLine = [string]$_.CommandLine
            }
        }))
    }
}

function Get-SameProjectHeadlessProcesses([string]$ExecutablePath, [string]$ResolvedProjectPath) {
    $projectPattern = [Regex]::Escape($ResolvedProjectPath)
    $pathPattern = '(?i)(?:^|[\s"'']){0}(?=$|[\s"''])' -f $projectPattern
    $headlessPattern = '(?i)(?:^|\s)--headless(?=$|\s)'
    $normalizedExecutable = $ExecutablePath.ToLowerInvariant()

    $matches = @(
        Get-RunnerProcessSnapshot ([IO.Path]::GetFileName($ExecutablePath)) | Where-Object {
            $commandLine = [string]$_.CommandLine
            if ([string]::IsNullOrWhiteSpace($commandLine)) { return $false }
            if ($commandLine -notmatch $headlessPattern) { return $false }
            if ($commandLine -notmatch $pathPattern) { return $false }
            # ExecutablePath can be unavailable for protected processes.  The
            # command line remains the required scope signal in that case.
            if (-not [string]::IsNullOrWhiteSpace([string]$_.ExecutablePath)) {
                return ([string]$_.ExecutablePath).ToLowerInvariant() -eq $normalizedExecutable
            }
            return $true
        }
    )
    # Test fixtures and a live provider can describe the same process. More
    # generally, process inventory must never turn duplicate observations into
    # duplicate kill attempts.
    return @($matches | Sort-Object -Property ProcessId -Unique)
}

function Get-DescendantProcessIds([long]$RootPid) {
    $all = @(Get-RunnerProcessSnapshot)
    $childrenByParent = @{}
    foreach ($process in $all) {
        $parent = [long]$process.ParentProcessId
        if (-not $childrenByParent.ContainsKey($parent)) {
            $childrenByParent[$parent] = New-Object 'System.Collections.Generic.List[long]'
        }
        $childrenByParent[$parent].Add([long]$process.ProcessId)
    }

    $result = New-Object 'System.Collections.Generic.List[long]'
    $pending = New-Object 'System.Collections.Generic.Queue[long]'
    $pending.Enqueue($RootPid)
    while ($pending.Count -gt 0) {
        $parent = $pending.Dequeue()
        if (-not $childrenByParent.ContainsKey($parent)) { continue }
        foreach ($child in $childrenByParent[$parent]) {
            if (-not $result.Contains($child)) {
                $result.Add($child)
                $pending.Enqueue($child)
            }
        }
    }
    return @($result)
}

function Stop-TrackedInvocation([long]$RootPid, [System.Collections.Generic.HashSet[long]]$TrackedPids) {
    foreach ($descendantPid in (Get-DescendantProcessIds $RootPid)) { [void]$TrackedPids.Add($descendantPid) }
    [void]$TrackedPids.Add($RootPid)
    $alive = @()
    foreach ($trackedPid in $TrackedPids) {
        if (Get-Process -Id $trackedPid -ErrorAction SilentlyContinue) { $alive += $trackedPid }
    }
    foreach ($trackedPid in $alive | Sort-Object -Descending) {
        Stop-Process -Id $trackedPid -Force -ErrorAction SilentlyContinue
    }

    $deadline = [DateTime]::UtcNow.AddSeconds(5)
    do {
        Start-Sleep -Milliseconds 50
        $remaining = @($TrackedPids | Where-Object { Get-Process -Id $_ -ErrorAction SilentlyContinue })
    } while ($remaining.Count -gt 0 -and [DateTime]::UtcNow -lt $deadline)
    return @($remaining)
}

function Write-RunnerSummary([string]$Status, [string]$Category, [Nullable[int]]$ProcessExitCode,
    [double]$ElapsedSeconds, [string]$ResolvedProjectPath, [string]$ResolvedLogPath,
    [long[]]$CleanedPids) {
    [ordered]@{
        status = $Status
        category = $Category
        processExitCode = $ProcessExitCode
        elapsedSeconds = [Math]::Round($ElapsedSeconds, 3)
        project = $ResolvedProjectPath
        logPath = $ResolvedLogPath
        cleanedPids = @($CleanedPids | Sort-Object -Unique)
    } | ConvertTo-Json -Compress
}

$mutex = $null
$process = $null
$trackedPids = New-Object 'System.Collections.Generic.HashSet[long]'
$cleanedPids = New-Object 'System.Collections.Generic.List[long]'
$stdoutFile = $null
$stderrFile = $null
$stdoutTask = $null
$stderrTask = $null
$resolvedProject = ''
$resolvedLog = ''
$processExitCode = $null
$category = 'InvalidInput'
$status = 'failed'
$scriptExitCode = $script:ExitCodes.InvalidInput
$stopwatch = [Diagnostics.Stopwatch]::StartNew()

try {
    if (-not [string]::IsNullOrWhiteSpace($GodotArgumentJson)) {
        $parsedArguments = ConvertFrom-Json -InputObject $GodotArgumentJson
        $GodotArgument = @(
            foreach ($parsedArgument in $parsedArguments) { [string]$parsedArgument }
        )
    }
    if ($null -eq $GodotArgument -or $GodotArgument.Count -eq 0) {
        throw 'Pass at least one -GodotArgument or a JSON -GodotArgumentJson array.'
    }
    $resolvedGodot = (Resolve-Path -LiteralPath $GodotPath -ErrorAction Stop).Path
    $resolvedProject = (Resolve-Path -LiteralPath $ProjectPath -ErrorAction Stop).Path
    if (-not (Test-Path -LiteralPath (Join-Path $resolvedProject 'project.godot') -PathType Leaf)) {
        throw "Project path does not contain project.godot: $resolvedProject"
    }
    if (-not [IO.Path]::IsPathRooted($resolvedGodot)) {
        throw "Godot path must resolve to an absolute path: $GodotPath"
    }
    foreach ($reserved in '--headless', '--path', '--log-file') {
        if ($GodotArgument -contains $reserved -or $GodotArgument | Where-Object { $_ -like "$reserved=*" }) {
            throw "Do not pass $reserved through -GodotArgument; the runner owns it."
        }
    }

    if ([string]::IsNullOrWhiteSpace($LogFile)) {
        $resolvedLog = Join-Path ([IO.Path]::GetTempPath()) ("godot-test-{0}-{1}.log" -f (Get-RunnerHash $resolvedProject), [Guid]::NewGuid().ToString('N'))
    } else {
        $parent = Split-Path -Parent $LogFile
        if (-not [string]::IsNullOrWhiteSpace($parent)) { [void](New-Item -ItemType Directory -Force -Path $parent) }
        $resolvedLog = [IO.Path]::GetFullPath($LogFile)
    }
    $stdoutFile = "$resolvedLog.stdout"
    $stderrFile = "$resolvedLog.stderr"

    $mutexName = "Global\GodotTestRunner_$(Get-RunnerHash $resolvedProject)"
    $createdNew = $false
    try {
        $mutex = New-Object Threading.Mutex($false, $mutexName, [ref]$createdNew)
    } catch [UnauthorizedAccessException] {
        # Restricted Windows sandboxes can deny Global namespace creation.  The
        # Local fallback still protects all runner instances in this session.
        $mutexName = "Local\GodotTestRunner_$(Get-RunnerHash $resolvedProject)"
        $mutex = New-Object Threading.Mutex($false, $mutexName, [ref]$createdNew)
    }
    if (-not $mutex.WaitOne(0)) {
        $category = 'LockContention'; $scriptExitCode = $script:ExitCodes.LockContention
        throw 'RUNNER_LOCK_CONTENTION'
    }

    $existing = @(Get-SameProjectHeadlessProcesses $resolvedGodot $resolvedProject)
    if ($existing.Count -gt 0 -and -not $CleanupExisting) {
        $category = 'PreexistingHeadlessProcess'; $scriptExitCode = $script:ExitCodes.PreexistingHeadlessProcess
        throw ("Pre-existing same-project headless processes: " + (($existing | ForEach-Object ProcessId) -join ','))
    }
    if ($CleanupExisting) {
        foreach ($existingProcess in $existing) {
            $existingPid = [long]$existingProcess.ProcessId
            Stop-Process -Id $existingPid -Force -ErrorAction Stop
            $cleanedPids.Add($existingPid)
        }
        Start-Sleep -Milliseconds 100
        $remainingExisting = @(Get-SameProjectHeadlessProcesses $resolvedGodot $resolvedProject)
        if ($remainingExisting.Count -gt 0) {
            $category = 'CleanupFailure'; $scriptExitCode = $script:ExitCodes.CleanupFailure
            throw ("Could not remove same-project headless processes: " + (($remainingExisting | ForEach-Object ProcessId) -join ','))
        }
    }

    $engineArguments = New-Object 'System.Collections.Generic.List[string]'
    foreach ($argument in $GodotArgument) { $engineArguments.Add($argument) }
    $engineArguments.Add('--headless')
    $engineArguments.Add('--path')
    $engineArguments.Add($resolvedProject)
    $engineArguments.Add('--log-file')
    $engineArguments.Add($resolvedLog)
    $quotedArguments = foreach ($argument in $engineArguments) {
        ConvertTo-WindowsCommandLineArgument $argument
    }
    $argumentLine = ($quotedArguments -join ' ')

    $startInfo = New-Object Diagnostics.ProcessStartInfo
    $startInfo.FileName = $resolvedGodot
    $startInfo.Arguments = $argumentLine
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $startInfo
    if (-not $process.Start()) { throw 'Could not start the Godot command.' }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    [void]$trackedPids.Add([long]$process.Id)

    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while (-not $process.HasExited) {
        foreach ($descendantPid in (Get-DescendantProcessIds $process.Id)) { [void]$trackedPids.Add($descendantPid) }
        if ([DateTime]::UtcNow -ge $deadline) {
            $category = 'Timeout'; $scriptExitCode = $script:ExitCodes.Timeout
            throw 'RUNNER_TIMEOUT'
        }
        Start-Sleep -Milliseconds $PollMilliseconds
        $process.Refresh()
    }
    $processExitCode = $process.ExitCode
    [IO.File]::WriteAllText($stdoutFile, $stdoutTask.GetAwaiter().GetResult())
    [IO.File]::WriteAllText($stderrFile, $stderrTask.GetAwaiter().GetResult())

    $fatalPattern = '(?im)CrashHandlerException|Program crashed|signal\s+11|C\+\+ backtrace|SCRIPT ERROR|Parser Error|Parse Error|Unhandled exception|Invalid call|^ERROR:'
    $captured = ''
    foreach ($capturePath in @($stdoutFile, $stderrFile, $resolvedLog)) {
        if (Test-Path -LiteralPath $capturePath -PathType Leaf) {
            $captured += [Environment]::NewLine + (Get-Content -LiteralPath $capturePath -Raw -ErrorAction SilentlyContinue)
        }
    }
    if ($captured -match $fatalPattern) {
        $category = 'FatalOutput'; $scriptExitCode = $script:ExitCodes.FatalOutput
        throw 'RUNNER_FATAL_OUTPUT'
    }
    if ($processExitCode -ne 0) {
        $category = 'ProcessFailure'; $scriptExitCode = $script:ExitCodes.ProcessFailure
        throw "RUNNER_PROCESS_EXIT_$processExitCode"
    }
    $category = 'Success'; $status = 'passed'; $scriptExitCode = $script:ExitCodes.Success
}
catch {
    if ($category -eq 'InvalidInput' -and $_.Exception.Message -notlike 'RUNNER_*') {
        $scriptExitCode = $script:ExitCodes.InvalidInput
    }
}
finally {
    if ($process -and -not $process.HasExited) {
        $remaining = @(Stop-TrackedInvocation $process.Id $trackedPids)
        foreach ($trackedPid in $trackedPids) { $cleanedPids.Add($trackedPid) }
        if ($remaining.Count -gt 0) {
            $category = 'CleanupFailure'; $status = 'failed'; $scriptExitCode = $script:ExitCodes.CleanupFailure
        }
    } elseif ($process) {
        # The parent has exited, but its children can still be alive on Windows.
        $descendants = @(Get-DescendantProcessIds $process.Id)
        foreach ($descendantPid in $descendants) { [void]$trackedPids.Add($descendantPid) }
        if ($descendants.Count -gt 0) {
            $remaining = @(Stop-TrackedInvocation $process.Id $trackedPids)
            foreach ($trackedPid in $trackedPids) { $cleanedPids.Add($trackedPid) }
            if ($remaining.Count -gt 0) {
                $category = 'CleanupFailure'; $status = 'failed'; $scriptExitCode = $script:ExitCodes.CleanupFailure
            }
        }
    }
    if ($stdoutTask -and $stdoutFile) {
        try { [IO.File]::WriteAllText($stdoutFile, $stdoutTask.GetAwaiter().GetResult()) } catch {}
    }
    if ($stderrTask -and $stderrFile) {
        try { [IO.File]::WriteAllText($stderrFile, $stderrTask.GetAwaiter().GetResult()) } catch {}
    }
    if ($mutex) {
        try { $mutex.ReleaseMutex() } catch [System.ApplicationException] {}
        $mutex.Dispose()
    }
    $stopwatch.Stop()
    Write-Output (Write-RunnerSummary $status $category $processExitCode $stopwatch.Elapsed.TotalSeconds `
        $resolvedProject $resolvedLog @($cleanedPids))
}

switch ($category) {
    'Success' { exit 0 }
    'ProcessFailure' { exit 1 }
    'Timeout' { exit 2 }
    'FatalOutput' { exit 3 }
    'LockContention' { exit 4 }
    'PreexistingHeadlessProcess' { exit 5 }
    'InvalidInput' { exit 6 }
    'CleanupFailure' { exit 7 }
    'LaunchFailure' { exit 8 }
    default { exit 6 }
}
