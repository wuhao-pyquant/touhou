[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$GodotPath,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$ProjectPath,
    [Alias('GodotArguments')][string[]]$GodotArgument,
    [string]$GodotArgumentJson,
    [ValidateRange(1, 86400)][int]$TimeoutSeconds = 120,
    [string]$LogFile,
    [switch]$CleanupExisting,
    # Test-only fixture; every record is revalidated against the live process.
    [string]$ProcessInventoryFixture,
    # Test-only: proves that the native snapshot is the authoritative fallback.
    [switch]$ForceNativeSnapshot,
    # Test-only: simulates a Global namespace access denial.
    [switch]$SimulateGlobalMutexFailure,
    # Test-only compatibility for the Python fixture, whose interpreter requires its script first.
    [switch]$TestPythonEngineCompatibility,
    [ValidateRange(25, 5000)][int]$PollMilliseconds = 100
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ExitCodes = @{ Success=0; ProcessFailure=1; Timeout=2; FatalOutput=3; LockContention=4; PreexistingHeadlessProcess=5; InvalidInput=6; CleanupFailure=7; LaunchFailure=8 }
$script:Deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds) # One deadline for the whole invocation, including cleanup.

function Test-Deadline([string]$Phase) {
    if ([DateTime]::UtcNow -ge $script:Deadline) { throw "RUNNER_TIMEOUT:$Phase" }
}
function Get-RemainingMilliseconds {
    $value = [int][Math]::Floor(($script:Deadline - [DateTime]::UtcNow).TotalMilliseconds)
    return [Math]::Max(0, $value)
}
function Get-RunnerHash([string]$Value) {
    $bytes = [Text.Encoding]::UTF8.GetBytes($Value.ToLowerInvariant())
    $hash = [Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
    ([BitConverter]::ToString($hash)).Replace('-', '').Substring(0, 32)
}
function ConvertTo-WindowsCommandLineArgument([string]$Value) {
    if ($Value.Length -eq 0) { return '""' }
    if ($Value -notmatch '[\s"]') { return $Value }
    $builder = New-Object Text.StringBuilder; [void]$builder.Append('"'); $slashes = 0
    foreach ($character in $Value.ToCharArray()) {
        if ($character -eq '\') { $slashes++; continue }
        if ($character -eq '"') { [void]$builder.Append(('\' * (($slashes * 2) + 1))); [void]$builder.Append('"'); $slashes = 0; continue }
        if ($slashes -gt 0) { [void]$builder.Append(('\' * $slashes)); $slashes = 0 }
        [void]$builder.Append($character)
    }
    if ($slashes -gt 0) { [void]$builder.Append(('\' * ($slashes * 2))) }
    [void]$builder.Append('"'); $builder.ToString()
}

function Initialize-NativeSupport {
    if ('GodotTestRunner.Native' -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;
namespace GodotTestRunner {
 public sealed class ProcessRecord { public int ProcessId; public int ParentProcessId; public string ExecutablePath; public string CommandLine; public long CreationTime; }
 public static class Native {
  const uint TH32CS_SNAPPROCESS=0x2, PROCESS_QUERY_LIMITED_INFORMATION=0x1000, PROCESS_TERMINATE=0x1, PROCESS_SET_QUOTA=0x100;
  static readonly IntPtr INVALID_HANDLE_VALUE=new IntPtr(-1);
  // ULONG_PTR must be IntPtr.  This is the x64/x86-correct PROCESSENTRY32W layout.
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] struct PROCESSENTRY32W { public uint dwSize,cntUsage,th32ProcessID; public IntPtr th32DefaultHeapID; public uint th32ModuleID,cntThreads,th32ParentProcessID; public int pcPriClassBase; public uint dwFlags; [MarshalAs(UnmanagedType.ByValTStr,SizeConst=260)] public string szExeFile; }
  [StructLayout(LayoutKind.Sequential)] struct UNICODE_STRING { public ushort Length,MaximumLength; public IntPtr Buffer; }
  [StructLayout(LayoutKind.Sequential)] struct JOBOBJECT_BASIC_LIMIT_INFORMATION { public long PerProcessUserTimeLimit,PerJobUserTimeLimit; public uint LimitFlags; public UIntPtr MinimumWorkingSetSize,MaximumWorkingSetSize,ActiveProcessLimit; public IntPtr Affinity; public uint PriorityClass,SchedulingClass; }
  [StructLayout(LayoutKind.Sequential)] struct IO_COUNTERS { public ulong ReadOperationCount,WriteOperationCount,OtherOperationCount,ReadTransferCount,WriteTransferCount,OtherTransferCount; }
  [StructLayout(LayoutKind.Sequential)] struct JOBOBJECT_EXTENDED_LIMIT_INFORMATION { public JOBOBJECT_BASIC_LIMIT_INFORMATION BasicLimitInformation; public IO_COUNTERS IoInfo; public UIntPtr ProcessMemoryLimit,JobMemoryLimit,PeakProcessMemoryUsed,PeakJobMemoryUsed; }
  [DllImport("kernel32.dll",SetLastError=true)] static extern IntPtr CreateToolhelp32Snapshot(uint flags,uint pid);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool Process32FirstW(IntPtr s,ref PROCESSENTRY32W e);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool Process32NextW(IntPtr s,ref PROCESSENTRY32W e);
  [DllImport("kernel32.dll",SetLastError=true)] static extern IntPtr OpenProcess(uint access,bool inherit,int pid);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool CloseHandle(IntPtr h);
  [DllImport("kernel32.dll",SetLastError=true,CharSet=CharSet.Unicode)] static extern bool QueryFullProcessImageNameW(IntPtr h,uint flags,System.Text.StringBuilder path,ref int size);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool GetProcessTimes(IntPtr h,out long create,out long exit,out long kernel,out long user);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool GetExitCodeProcess(IntPtr h,out uint code);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool TerminateProcess(IntPtr h,uint code);
  [DllImport("ntdll.dll")] static extern int NtQueryInformationProcess(IntPtr h,int cls,IntPtr buffer,int length,out int returnLength);
  [DllImport("shell32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern IntPtr CommandLineToArgvW(string cmd,out int argc);
  [DllImport("kernel32.dll")] static extern IntPtr LocalFree(IntPtr p);
  [DllImport("kernel32.dll",SetLastError=true,CharSet=CharSet.Unicode)] static extern IntPtr CreateJobObjectW(IntPtr a,string name);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool SetInformationJobObject(IntPtr j,int cls,IntPtr info,uint length);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool AssignProcessToJobObject(IntPtr j,IntPtr p);
  static string ImageFor(IntPtr h) { int n=32768; var b=new System.Text.StringBuilder(n); if(!QueryFullProcessImageNameW(h,0,b,ref n)) return null; return b.ToString(); }
  static long CreationFor(IntPtr h) { long c,e,k,u; return GetProcessTimes(h,out c,out e,out k,out u) ? c : 0; }
  static string CommandFor(IntPtr h) { int n; NtQueryInformationProcess(h,60,IntPtr.Zero,0,out n); if(n<=0) return null; IntPtr b=Marshal.AllocHGlobal(n); try { if(NtQueryInformationProcess(h,60,b,n,out n)!=0) return null; var u=(UNICODE_STRING)Marshal.PtrToStructure(b,typeof(UNICODE_STRING)); return u.Buffer==IntPtr.Zero?null:Marshal.PtrToStringUni(u.Buffer,u.Length/2); } finally { Marshal.FreeHGlobal(b); } }
  public static ProcessRecord Identity(int pid) { IntPtr h=OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION,false,pid); if(h==IntPtr.Zero) return null; try { var image=ImageFor(h); var creation=CreationFor(h); return String.IsNullOrEmpty(image)||creation==0?null:new ProcessRecord { ProcessId=pid,ExecutablePath=image,CommandLine=CommandFor(h),CreationTime=creation }; } finally { CloseHandle(h); } }
  public static ProcessRecord[] Snapshot(string expectedImagePath) { var all=new List<ProcessRecord>(); var s=CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS,0); if(s==INVALID_HANDLE_VALUE) throw new Win32Exception(Marshal.GetLastWin32Error(),"CreateToolhelp32Snapshot failed"); try { var e=new PROCESSENTRY32W(); e.dwSize=(uint)Marshal.SizeOf(typeof(PROCESSENTRY32W)); if(!Process32FirstW(s,ref e)) throw new Win32Exception(Marshal.GetLastWin32Error(),"Process32FirstW failed"); do { IntPtr h=OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION,false,(int)e.th32ProcessID); if(h!=IntPtr.Zero) try { var image=ImageFor(h); if(String.Equals(image,expectedImagePath,StringComparison.OrdinalIgnoreCase)) { var cmd=CommandFor(h); var creation=CreationFor(h); if(String.IsNullOrEmpty(image)||String.IsNullOrEmpty(cmd)||creation==0) throw new InvalidOperationException("Could not establish command-line/image/creation identity for matching process "+e.th32ProcessID); all.Add(new ProcessRecord { ProcessId=(int)e.th32ProcessID,ParentProcessId=(int)e.th32ParentProcessID,ExecutablePath=image,CommandLine=cmd,CreationTime=creation }); } } finally { CloseHandle(h); } e.dwSize=(uint)Marshal.SizeOf(typeof(PROCESSENTRY32W)); } while(Process32NextW(s,ref e)); return all.ToArray(); } finally { CloseHandle(s); } }
  public static string[] ParseCommandLine(string commandLine) { int n; IntPtr p=CommandLineToArgvW(commandLine,out n); if(p==IntPtr.Zero) return null; try { var result=new string[n]; for(int i=0;i<n;i++) result[i]=Marshal.PtrToStringUni(Marshal.ReadIntPtr(p,i*IntPtr.Size)); return result; } finally { LocalFree(p); } }
  public static bool IsSame(int pid,long creation) { IntPtr h=OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION,false,pid); if(h==IntPtr.Zero) return false; try { uint code; return CreationFor(h)==creation && GetExitCodeProcess(h,out code) && code==259; } finally { CloseHandle(h); } }
  public static bool TerminateIfSame(int pid,long creation) { IntPtr h=OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION|PROCESS_TERMINATE,false,pid); if(h==IntPtr.Zero) return false; try { uint code; if(CreationFor(h)!=creation) return false; if(!GetExitCodeProcess(h,out code) || code!=259) return true; return TerminateProcess(h,1); } finally { CloseHandle(h); } }
  public static IntPtr CreateKillOnCloseJob() { IntPtr j=CreateJobObjectW(IntPtr.Zero,null); if(j==IntPtr.Zero) return IntPtr.Zero; var x=new JOBOBJECT_EXTENDED_LIMIT_INFORMATION(); x.BasicLimitInformation.LimitFlags=0x2000; int size=Marshal.SizeOf(typeof(JOBOBJECT_EXTENDED_LIMIT_INFORMATION)); IntPtr b=Marshal.AllocHGlobal(size); try { Marshal.StructureToPtr(x,b,false); if(!SetInformationJobObject(j,9,b,(uint)size)) { CloseHandle(j); return IntPtr.Zero; } return j; } finally { Marshal.FreeHGlobal(b); } }
  public static bool AssignToJob(IntPtr job,int pid) { if(job==IntPtr.Zero) return false; IntPtr h=OpenProcess(PROCESS_SET_QUOTA|PROCESS_TERMINATE,false,pid); if(h==IntPtr.Zero) return false; try { return AssignProcessToJobObject(job,h); } finally { CloseHandle(h); } }
  public static void CloseJob(IntPtr job) { if(job!=IntPtr.Zero) CloseHandle(job); }
 }
}
'@
}

function Get-LiveInventory([string]$ExpectedImage) {
    Test-Deadline 'inventory-start'; Initialize-NativeSupport
    # Native enumeration is used deliberately: WMI may block indefinitely and must not weaken this guard.
    $records = @([GodotTestRunner.Native]::Snapshot($ExpectedImage))
    if (-not [string]::IsNullOrWhiteSpace($ProcessInventoryFixture)) {
        if (-not (Test-Path -LiteralPath $ProcessInventoryFixture -PathType Leaf)) { throw "Process inventory fixture does not exist: $ProcessInventoryFixture" }
        foreach ($line in Get-Content -LiteralPath $ProcessInventoryFixture) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $candidate = $line | ConvertFrom-Json
            # Fixtures cannot confer authority: attach their command line only to a live native identity.
            $live = [GodotTestRunner.Native]::Identity([int]$candidate.ProcessId)
            if ($null -ne $live -and $live.ExecutablePath -ieq $ExpectedImage) {
                $live.ParentProcessId = [int]$candidate.ParentProcessId
                if (-not [string]::IsNullOrWhiteSpace([string]$candidate.CommandLine)) { $live.CommandLine = [string]$candidate.CommandLine }
                $records += $live
            }
        }
    }
    Test-Deadline 'inventory-end'
    @($records | Group-Object ProcessId | ForEach-Object { $_.Group[0] })
}
function Test-SameProjectHeadless([object]$Record,[string]$ExpectedImage,[string]$Project) {
    if ([string]::IsNullOrWhiteSpace([string]$Record.ExecutablePath) -or ([string]$Record.ExecutablePath -ine $ExpectedImage)) { throw "Cannot establish exact executable identity for PID $($Record.ProcessId)" }
    if ([string]::IsNullOrWhiteSpace([string]$Record.CommandLine)) { throw "Cannot establish command-line identity for PID $($Record.ProcessId)" }
    $arguments = [GodotTestRunner.Native]::ParseCommandLine([string]$Record.CommandLine)
    if ($null -eq $arguments) { throw "Cannot parse command line for PID $($Record.ProcessId)" }
    $headless = $false; $pathMatches = $false
    for ($i=1; $i -lt $arguments.Length; $i++) {
        if ($arguments[$i] -ceq '--headless') { $headless = $true }
        if ($arguments[$i] -ceq '--path') {
            if (($i + 1) -ge $arguments.Length) { throw "Malformed --path for PID $($Record.ProcessId)" }
            $pathMatches = ($arguments[$i + 1] -ieq $Project); $i++
        }
    }
    $headless -and $pathMatches
}
function Get-SameProjectHeadlessProcesses([string]$ExecutablePath,[string]$ResolvedProjectPath) {
    @(Get-LiveInventory $ExecutablePath | Where-Object { Test-SameProjectHeadless $_ $ExecutablePath $ResolvedProjectPath })
}
function Add-TrackedIdentity([hashtable]$Tracked,[object]$Record) { if ($Record.CreationTime -eq 0) { throw "Missing creation identity for PID $($Record.ProcessId)" }; $Tracked[[int]$Record.ProcessId] = [long]$Record.CreationTime }
function Stop-TrackedInvocation([hashtable]$Tracked,[System.Collections.Generic.List[long]]$Cleaned) {
    $failed = @()
    foreach ($trackedProcessId in @($Tracked.Keys | Sort-Object -Descending)) {
        $creation = [long]$Tracked[$trackedProcessId]
        if ([GodotTestRunner.Native]::IsSame([int]$trackedProcessId,$creation)) {
            if (-not [GodotTestRunner.Native]::TerminateIfSame([int]$trackedProcessId,$creation)) { $failed += [long]$trackedProcessId } else { $Cleaned.Add([long]$trackedProcessId) }
        }
    }
    while ((Get-RemainingMilliseconds) -gt 0) {
        $remaining = @($Tracked.Keys | Where-Object { [GodotTestRunner.Native]::IsSame([int]$_,[long]$Tracked[$_]) })
        if (@($remaining).Count -eq 0) { return @($failed) }
        Start-Sleep -Milliseconds ([Math]::Min(50,(Get-RemainingMilliseconds)))
    }
    @($failed + @($Tracked.Keys | Where-Object { [GodotTestRunner.Native]::IsSame([int]$_,[long]$Tracked[$_]) }))
}
function Wait-StreamTasks([Threading.Tasks.Task]$Stdout,[Threading.Tasks.Task]$Stderr) {
    foreach ($task in @($Stdout,$Stderr)) {
        if ($null -eq $task) { continue }
        $remaining=Get-RemainingMilliseconds
        if ($remaining -le 0 -or -not $task.Wait($remaining)) { return $false }
    }
    $true
}
function Write-RunnerSummary([string]$Status,[string]$Category,[Nullable[int]]$ProcessExitCode,[double]$ElapsedSeconds,[string]$ResolvedProjectPath,[string]$ResolvedLogPath,[long[]]$CleanedPids) {
    [ordered]@{status=$Status;category=$Category;processExitCode=$ProcessExitCode;elapsedSeconds=[Math]::Round($ElapsedSeconds,3);project=$ResolvedProjectPath;logPath=$ResolvedLogPath;cleanedPids=@($CleanedPids|Sort-Object -Unique)}|ConvertTo-Json -Compress
}

$mutex=$null; $process=$null; $processStarted=$false; $job=[IntPtr]::Zero; $tracked=@{}; $cleaned=New-Object 'System.Collections.Generic.List[long]'; $stdoutTask=$null; $stderrTask=$null; $stdoutFile=$null; $stderrFile=$null
$resolvedProject=''; $resolvedLog=''; $processExitCode=$null; $category='InvalidInput'; $status='failed'; $scriptExitCode=$script:ExitCodes.InvalidInput; $stopwatch=[Diagnostics.Stopwatch]::StartNew()
try {
    Test-Deadline 'input'
    if (-not [string]::IsNullOrWhiteSpace($GodotArgumentJson)) { $GodotArgument=@((ConvertFrom-Json -InputObject $GodotArgumentJson)|ForEach-Object {[string]$_}) }
    if ($null -eq $GodotArgument -or @($GodotArgument).Count -eq 0) { throw 'Pass at least one -GodotArgument or a JSON -GodotArgumentJson array.' }
    $resolvedGodot=(Resolve-Path -LiteralPath $GodotPath -ErrorAction Stop).Path; $resolvedProject=(Resolve-Path -LiteralPath $ProjectPath -ErrorAction Stop).Path
    if (-not (Test-Path -LiteralPath (Join-Path $resolvedProject 'project.godot') -PathType Leaf)) { throw "Project path does not contain project.godot: $resolvedProject" }
    foreach ($reserved in '--headless','--path','--log-file') { if ($GodotArgument -contains $reserved -or $GodotArgument|Where-Object {$_ -like "$reserved=*"}) { throw "Do not pass $reserved through -GodotArgument; the runner owns it." } }
    if ([string]::IsNullOrWhiteSpace($LogFile)) { $resolvedLog=Join-Path ([IO.Path]::GetTempPath()) ("godot-test-{0}-{1}.log" -f (Get-RunnerHash $resolvedProject),[Guid]::NewGuid().ToString('N')) } else { $parent=Split-Path -Parent $LogFile; if($parent){[void](New-Item -ItemType Directory -Force -Path $parent)}; $resolvedLog=[IO.Path]::GetFullPath($LogFile) }
    $stdoutFile="$resolvedLog.stdout"; $stderrFile="$resolvedLog.stderr"

    Test-Deadline 'mutex'; $createdNew=$false; $mutexName="Global\GodotTestRunner_$(Get-RunnerHash $resolvedProject)"
    try { if ($SimulateGlobalMutexFailure) { throw [UnauthorizedAccessException]::new('simulated Global mutex failure') }; $mutex=New-Object Threading.Mutex($false,$mutexName,[ref]$createdNew) } catch { $category='LockContention';$scriptExitCode=$script:ExitCodes.LockContention; throw "RUNNER_GLOBAL_MUTEX_FAILURE:$($_.Exception.Message)" }
    Test-Deadline 'mutex-created'; if (-not $mutex.WaitOne(0)) { $category='LockContention';$scriptExitCode=$script:ExitCodes.LockContention;throw 'RUNNER_LOCK_CONTENTION' }

    $existing=@(Get-SameProjectHeadlessProcesses $resolvedGodot $resolvedProject)
    if (@($existing).Count -gt 0 -and -not $CleanupExisting) { $category='PreexistingHeadlessProcess';$scriptExitCode=$script:ExitCodes.PreexistingHeadlessProcess;throw 'RUNNER_PREEXISTING' }
    if ($CleanupExisting) { foreach($record in $existing){ $single=@{};Add-TrackedIdentity $single $record; $remaining=Stop-TrackedInvocation $single $cleaned;if(@($remaining).Count){$category='CleanupFailure';$scriptExitCode=$script:ExitCodes.CleanupFailure;throw 'RUNNER_PREEXISTING_CLEANUP_FAILURE'} }; if(@(Get-SameProjectHeadlessProcesses $resolvedGodot $resolvedProject).Count){$category='CleanupFailure';$scriptExitCode=$script:ExitCodes.CleanupFailure;throw 'RUNNER_PREEXISTING_VERIFY_FAILURE'} }

    $engineArguments=New-Object 'System.Collections.Generic.List[string]'
    # Runner-owned global options deliberately precede caller arguments in the public contract.
    # The explicit fixture-only seam exists because Python's interpreter grammar requires its .py script first.
    if($TestPythonEngineCompatibility){foreach($argument in $GodotArgument){[void]$engineArguments.Add($argument)};foreach($argument in @('--headless','--path',$resolvedProject,'--log-file',$resolvedLog)){[void]$engineArguments.Add($argument)}} else { foreach($argument in @('--headless','--path',$resolvedProject,'--log-file',$resolvedLog)){[void]$engineArguments.Add($argument)}; foreach($argument in $GodotArgument){[void]$engineArguments.Add($argument)} }
    $argumentLine=((@($engineArguments|ForEach-Object{ConvertTo-WindowsCommandLineArgument $_})) -join ' ')
    $startInfo=New-Object Diagnostics.ProcessStartInfo; $startInfo.FileName=$resolvedGodot;$startInfo.Arguments=$argumentLine;$startInfo.UseShellExecute=$false;$startInfo.CreateNoWindow=$true;$startInfo.RedirectStandardOutput=$true;$startInfo.RedirectStandardError=$true
    Test-Deadline 'launch';$process=New-Object Diagnostics.Process;$process.StartInfo=$startInfo
    try { if(-not $process.Start()){throw 'Process.Start returned false'}; $processStarted=$true } catch { $category='LaunchFailure';$scriptExitCode=$script:ExitCodes.LaunchFailure;throw "RUNNER_LAUNCH_FAILURE:$($_.Exception.Message)" }
    $stdoutTask=$process.StandardOutput.ReadToEndAsync();$stderrTask=$process.StandardError.ReadToEndAsync()
    # Keep the Process handle created by Start and capture its creation time now.  A short-lived
    # command may exit before a second snapshot can observe it, which is not a launch failure.
    try { $tracked[[int]$process.Id]=[long]$process.StartTime.ToUniversalTime().ToFileTimeUtc() } catch { $category='LaunchFailure';$scriptExitCode=$script:ExitCodes.LaunchFailure;throw 'RUNNER_LAUNCH_IDENTITY_FAILURE' }
    $job=[GodotTestRunner.Native]::CreateKillOnCloseJob();if($job -ne [IntPtr]::Zero){[void][GodotTestRunner.Native]::AssignToJob($job,$process.Id)}
    while(-not $process.HasExited){Test-Deadline 'parent';foreach($record in Get-LiveInventory $resolvedGodot){if($record.ParentProcessId -eq $process.Id){Add-TrackedIdentity $tracked $record}};Start-Sleep -Milliseconds ([Math]::Min($PollMilliseconds,(Get-RemainingMilliseconds)));$process.Refresh()}
    $processExitCode=$process.ExitCode
    # Parent exit is not authority to forget identities: all tracked identities are verified in finally.
    if(-not (Wait-StreamTasks $stdoutTask $stderrTask)){throw 'RUNNER_TIMEOUT:stream-drain'}
    [IO.File]::WriteAllText($stdoutFile,[string]$stdoutTask.Result);[IO.File]::WriteAllText($stderrFile,[string]$stderrTask.Result)
    $captured='';foreach($capturePath in @($stdoutFile,$stderrFile,$resolvedLog)){if(Test-Path -LiteralPath $capturePath -PathType Leaf){$captured+=[Environment]::NewLine+(Get-Content -LiteralPath $capturePath -Raw -ErrorAction SilentlyContinue)}}
    if($captured -match '(?im)CrashHandlerException|Program crashed|signal\s+11|C\+\+ backtrace|SCRIPT ERROR|Parser Error|Parse Error|Unhandled exception|Invalid call|^ERROR:'){$category='FatalOutput';$scriptExitCode=$script:ExitCodes.FatalOutput;throw 'RUNNER_FATAL_OUTPUT'}
    if($processExitCode -ne 0){$category='ProcessFailure';$scriptExitCode=$script:ExitCodes.ProcessFailure;throw "RUNNER_PROCESS_EXIT_$processExitCode"};$category='Success';$status='passed';$scriptExitCode=0
} catch {
    if($_.Exception.Message -like 'RUNNER_TIMEOUT:*'){$category='Timeout';$scriptExitCode=$script:ExitCodes.Timeout}
} finally {
    if($processStarted){
        # Closing a successfully assigned job kills its whole invocation tree; identities are still revalidated below.
        if($job -ne [IntPtr]::Zero){[GodotTestRunner.Native]::CloseJob($job);$job=[IntPtr]::Zero}
        $remaining=Stop-TrackedInvocation $tracked $cleaned
        if(@($remaining).Count -gt 0){$category='CleanupFailure';$status='failed';$scriptExitCode=$script:ExitCodes.CleanupFailure}
    }
    if($job -ne [IntPtr]::Zero){[GodotTestRunner.Native]::CloseJob($job)}
    if($mutex){try{$mutex.ReleaseMutex()}catch [Threading.AbandonedMutexException]{}catch [System.ApplicationException]{};$mutex.Dispose()}
    $stopwatch.Stop();Write-Output (Write-RunnerSummary $status $category $processExitCode $stopwatch.Elapsed.TotalSeconds $resolvedProject $resolvedLog @($cleaned))
}
exit $scriptExitCode
