[CmdletBinding()]
param(
    [string]$GodotPath,
    [string]$ProjectPath,
    [Alias('GodotArguments')][string[]]$GodotArgument,
    [string]$GodotArgumentJson,
    [int]$TimeoutSeconds=120,
    [string]$LogFile,
    [switch]$CleanupExisting,
    [int]$PollMilliseconds=100,
    # Private transport parameters.  They are deliberately not documented and cannot
    # grant any process or cleanup authority when supplied without -Worker.
    [switch]$Worker,[string]$Nonce,[int]$SupervisorPid,[long]$SupervisorCreation,[long]$DeadlineTicks,
    [string]$WorkerFault,[string]$WorkerArgumentB64
)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$script:Codes=@{Success=0;ProcessFailure=1;Timeout=2;FatalOutput=3;LockContention=4;PreexistingHeadlessProcess=5;InvalidInput=6;CleanupFailure=7;LaunchFailure=8}
$script:MaxFrame=16384; $script:MaxInput=65536; $script:MaxArguments=256; $script:MaxCapture=262144; $script:MaxDiagnostics=262144

function Get-Sha256([string]$Text) { ([BitConverter]::ToString(([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))))).Replace('-','') }
function ConvertTo-B64Url([string]$Text) { [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Text)).TrimEnd('=').Replace('+','-').Replace('/','_') }
function ConvertFrom-B64Url([string]$Text) { $s=$Text.Replace('-','+').Replace('_','/'); while(($s.Length%4)-ne 0){$s+='='}; [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($s)) }
function New-Frame([string]$Kind,[string]$FrameNonce,[hashtable]$Data) {
    $payload=ConvertTo-B64Url ($Data|ConvertTo-Json -Compress -Depth 4)
    $line="GTR1 $Kind $FrameNonce $payload $(Get-Sha256 "$Kind`n$FrameNonce`n$payload")"
    if($line.Length -gt $script:MaxFrame){throw 'protocol frame exceeds cap'}; $line
}
function Read-Frame([string]$Line,[string]$ExpectedKind,[string]$ExpectedNonce) {
    # Windows PowerShell 5.1 may decode a UTF-8 pipe preamble through CP936.
    # Strip only that transport artefact; all protocol bytes remain authenticated.
    while($null -ne $Line -and $Line.Length -gt 0 -and ([int][char]$Line[0] -eq 0xFEFF -or [int][char]$Line[0] -eq 0x9518 -or [int][char]$Line[0] -eq 0x7E02 -or [int][char]$Line[0] -eq 0xFFFD)){$Line=$Line.Substring(1)}
    if([string]::IsNullOrEmpty($Line) -or $Line.Length -gt $script:MaxFrame){throw 'invalid protocol frame length'}
    $p=$Line -split ' ',5
    if($p.Count -ne 5 -or $p[0] -cne 'GTR1' -or $p[1] -cne $ExpectedKind -or $p[2] -cne $ExpectedNonce){throw "invalid protocol frame header: $Line"}
    if((Get-Sha256 "$($p[1])`n$($p[2])`n$($p[3])") -cne $p[4]){throw 'invalid protocol frame hash'}
    try { ConvertFrom-B64Url $p[3] | ConvertFrom-Json -ErrorAction Stop } catch { throw 'invalid protocol payload' }
}
function Read-ProtocolStdinLine {
    $stream=[Console]::OpenStandardInput();$bytes=New-Object 'System.Collections.Generic.List[byte]'
    while($bytes.Count -le ($script:MaxFrame+3)){$value=$stream.ReadByte();if($value -lt 0 -or $value -eq 10){break};if($value -eq 13){continue};$bytes.Add([byte]$value)}
    if($bytes.Count -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF){$bytes.RemoveRange(0,3)}
    if($bytes.Count -gt $script:MaxFrame){throw 'protocol stdin exceeds cap'}
    foreach($value in $bytes){if($value -gt 127){throw 'non-ASCII protocol input'}}
    [Text.Encoding]::ASCII.GetString($bytes.ToArray())
}
function Quote-WindowsArgument([string]$Value) {
    if($Value.Length -eq 0){return '""'}; if($Value -notmatch '[\s"]'){return $Value}
    $b=New-Object Text.StringBuilder;[void]$b.Append('"');$n=0
    foreach($c in $Value.ToCharArray()){if($c -eq '\'){$n++;continue};if($c -eq '"'){[void]$b.Append(('\'*(2*$n+1)));[void]$b.Append('"');$n=0;continue};if($n){[void]$b.Append(('\'*$n));$n=0};[void]$b.Append($c)}
    if($n){[void]$b.Append(('\'*(2*$n)))};[void]$b.Append('"');$b.ToString()
}
function Write-Summary([string]$Status,[string]$Category,$Exit,[double]$Elapsed,[string]$Project,[string]$Log,[long[]]$Cleaned) {
    [ordered]@{status=$Status;category=$Category;processExitCode=$Exit;elapsedSeconds=[Math]::Round($Elapsed,3);project=$Project;logPath=$Log;cleanedPids=@($Cleaned|Sort-Object -Unique)}|ConvertTo-Json -Compress
}
function Get-Remaining([long]$DeadlineTicks) {
    $ticks=$DeadlineTicks-[Diagnostics.Stopwatch]::GetTimestamp()
    if($ticks -le 0){return 0}
    [Math]::Max(1,[int][Math]::Floor($ticks*1000/[Diagnostics.Stopwatch]::Frequency))
}
function Test-BoundedArguments([object[]]$Values,[string]$Name) {
    if($Values.Count -eq 0 -or $Values.Count -gt $script:MaxArguments){throw "$Name must be a bounded nonempty array of strings"}
    $total=0
    foreach($item in $Values){
        if($item -isnot [string] -or $item.Length -gt $script:MaxInput -or $item.IndexOf([char]0)-ge 0){throw "$Name must be a bounded array of strings"}
        $total+=[Text.Encoding]::UTF8.GetByteCount($item)
        if($total -gt $script:MaxInput){throw "$Name aggregate exceeds cap"}
    }
    return ,$Values
}
function Test-PublicArguments {
    if([string]::IsNullOrWhiteSpace($GodotPath) -or [string]::IsNullOrWhiteSpace($ProjectPath)){throw 'GodotPath and ProjectPath are required'}
    if($TimeoutSeconds -lt 1 -or $TimeoutSeconds -gt 86400 -or $PollMilliseconds -lt 25 -or $PollMilliseconds -gt 5000){throw 'invalid timeout or poll interval'}
    foreach($v in @($GodotPath,$ProjectPath,$GodotArgumentJson,$LogFile)){if($null -ne $v -and ($v.Length -gt $script:MaxInput -or $v.IndexOf([char]0)-ge 0)){throw 'invalid input'}}
    $hasJson=-not [string]::IsNullOrWhiteSpace($GodotArgumentJson);$hasDirect=($null -ne $GodotArgument -and @($GodotArgument).Count -gt 0)
    if($hasJson -eq $hasDirect){throw 'provide exactly one argument form'}
    if($hasJson){try{$decoded=ConvertFrom-Json -InputObject $GodotArgumentJson -ErrorAction Stop}catch{throw 'GodotArgumentJson must be JSON'};if($null -eq $decoded -or $decoded -is [string] -or -not ($decoded -is [Collections.IEnumerable])){throw 'GodotArgumentJson must be a nonempty array of strings'};return (Test-BoundedArguments -Values @($decoded) -Name 'GodotArgumentJson')}
    return (Test-BoundedArguments -Values @($GodotArgument) -Name 'GodotArgument')
}
function Test-WorkerArguments {
    if([string]::IsNullOrEmpty($WorkerArgumentB64) -or $WorkerArgumentB64.Length -gt ($script:MaxInput*2)){throw 'worker argument transport exceeds cap'}
    $encoded=@($WorkerArgumentB64.Split(','));if($encoded.Count -eq 0 -or $encoded.Count -gt $script:MaxArguments){throw 'worker argument transport count exceeds cap'}
    try{$decoded=@($encoded|ForEach-Object{if($_.Length -gt ($script:MaxInput*2)){throw 'worker argument transport item exceeds cap'};ConvertFrom-B64Url $_})}catch{throw 'worker argument transport is invalid'}
    return (Test-BoundedArguments -Values $decoded -Name 'worker arguments')
}
function Test-ExactProperties([object]$Value,[string[]]$Expected,[string]$Name) {
    if($null -eq $Value){throw "invalid $Name contract"}
    $actual=@($Value.PSObject.Properties.Name|Sort-Object);$wanted=@($Expected|Sort-Object)
    if($actual.Count -ne $wanted.Count -or (@(Compare-Object $actual $wanted).Count -ne 0)){throw "invalid $Name contract"}
}
function Initialize-ProtocolPump {
    if('Gtr.ProtocolPump' -as [type]){return}
    Add-Type -TypeDefinition @'
using System; using System.IO; using System.Text; using System.Collections.Generic; using System.Threading;
namespace Gtr { public sealed class ProtocolPump { readonly Stream stream; readonly int frameCap,totalCap; readonly List<string> frames=new List<string>(); readonly StringBuilder text=new StringBuilder(); readonly object gate=new object(); volatile bool complete; string failure; public ProtocolPump(Stream s,int f,int t){stream=s;frameCap=f;totalCap=t;} public void Start(){new Thread(()=>{try{var line=new List<byte>();int total=0,v;while((v=stream.ReadByte())>=0){if(++total>totalCap)throw new InvalidOperationException("diagnostic stream exceeds cap");if(v==10){if(line.Count>frameCap)throw new InvalidOperationException("protocol frame exceeds cap");string x=Encoding.UTF8.GetString(line.ToArray()).TrimEnd('\r');lock(gate){frames.Add(x);text.Append(x).Append('\n');}line.Clear();continue;}line.Add((byte)v);if(line.Count>frameCap)throw new InvalidOperationException("unterminated protocol frame exceeds cap");}if(line.Count!=0)throw new InvalidOperationException("unterminated protocol frame");}catch(Exception e){failure=e.Message;}finally{complete=true;}}){IsBackground=true}.Start();} public int Count{get{lock(gate)return frames.Count;}} public string Frame(int i){lock(gate)return i<frames.Count?frames[i]:null;} public string Text{get{lock(gate)return text.ToString();}} public bool Complete{get{return complete;}} public string Failure{get{return failure;}} } }
'@
}

# W0: only the worker may compile/use the native containment implementation.
function Initialize-WorkerNative {
if('Gtr.Native' -as [type]){return}
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
namespace Gtr {
 public sealed class Existing { public int Pid; public IntPtr Handle; public long Creation; }
 public sealed class FileIdentity { public IntPtr Handle; public string DiagnosticPath; public uint Volume; public uint IndexHigh; public uint IndexLow; public bool Same(FileIdentity other){return other!=null&&Volume==other.Volume&&IndexHigh==other.IndexHigh&&IndexLow==other.IndexLow;} }
 public sealed class Result { public int ExitCode; public bool TimedOut; public bool Empty; public string Stdout; public string Stderr; }
 public sealed class SupervisorWatch { public IntPtr Handle; public long Creation; public IntPtr Job; public volatile bool Failed; public readonly object Gate=new object(); public readonly ManualResetEvent Stop=new ManualResetEvent(false); public readonly ManualResetEvent Ready=new ManualResetEvent(false); public readonly ManualResetEvent Done=new ManualResetEvent(false); }
 public sealed class CaptureRead { public byte[] Data; public Exception Error; public readonly ManualResetEvent Done=new ManualResetEvent(false); }
 public sealed class BytePump { readonly Stream stream; readonly int frameCap,totalCap; readonly List<string> frames=new List<string>(); readonly StringBuilder text=new StringBuilder(); readonly object gate=new object(); volatile bool complete; string failure; public BytePump(Stream s,int f,int t){stream=s;frameCap=f;totalCap=t;} public void Start(){new Thread(()=>{try{var line=new List<byte>();int total=0,v;while((v=stream.ReadByte())>=0){if(++total>totalCap)throw new InvalidOperationException("diagnostic stream exceeds cap");if(v==10){if(line.Count>frameCap)throw new InvalidOperationException("protocol frame exceeds cap");string x=Encoding.UTF8.GetString(line.ToArray()).TrimEnd('\r');lock(gate){frames.Add(x);text.Append(x).Append('\n');}line.Clear();continue;}line.Add((byte)v);if(line.Count>frameCap)throw new InvalidOperationException("unterminated protocol frame exceeds cap");}if(line.Count!=0)throw new InvalidOperationException("unterminated protocol frame");}catch(Exception e){failure=e.Message;}finally{complete=true;}}){IsBackground=true}.Start();} public int Count{get{lock(gate)return frames.Count;}} public string Frame(int i){lock(gate)return i<frames.Count?frames[i]:null;} public string Text{get{lock(gate)return text.ToString();}} public bool Complete{get{return complete;}} public string Failure{get{return failure;}} }
 public static class Native {
  const uint TH32CS_SNAPPROCESS=2, PROCESS_QUERY_LIMITED_INFORMATION=0x1000, PROCESS_TERMINATE=1, SYNCHRONIZE=0x100000;
  const uint CREATE_SUSPENDED=4, EXTENDED_STARTUPINFO_PRESENT=0x80000, INFINITE=0xffffffff, WAIT_OBJECT_0=0, WAIT_TIMEOUT=258;
  const int JobObjectExtendedLimitInformation=9, JobObjectBasicAccountingInformation=1;
  const uint JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE=0x2000, PROC_THREAD_ATTRIBUTE_JOB_LIST=0x0002000D, PROC_THREAD_ATTRIBUTE_HANDLE_LIST=0x00020002;
  static readonly IntPtr INVALID=new IntPtr(-1);
  [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)] struct PROCESSENTRY32W {public uint dwSize,cntUsage,th32ProcessID;public IntPtr heap;public uint mod,threads,parent;public int pri;public uint flags;[MarshalAs(UnmanagedType.ByValTStr,SizeConst=260)]public string exe;}
  [StructLayout(LayoutKind.Sequential)] struct UNICODE_STRING {public ushort Length,MaximumLength;public IntPtr Buffer;}
  [StructLayout(LayoutKind.Sequential)] struct JOBOBJECT_BASIC_LIMIT_INFORMATION {public long a,b;public uint LimitFlags;public UIntPtr min,max;public uint active;public IntPtr affinity;public uint priority,scheduling;}
  [StructLayout(LayoutKind.Sequential)] struct IO_COUNTERS {public ulong a,b,c,d,e,f;}
  [StructLayout(LayoutKind.Sequential)] struct JOBOBJECT_EXTENDED_LIMIT_INFORMATION {public JOBOBJECT_BASIC_LIMIT_INFORMATION BasicLimitInformation;public IO_COUNTERS IoInfo;public UIntPtr a,b,c,d;}
  [StructLayout(LayoutKind.Sequential)] struct JOBOBJECT_BASIC_ACCOUNTING_INFORMATION {public long a,b,c,d;public uint faults,TotalProcesses,ActiveProcesses,TerminatedProcesses;}
  [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)] struct STARTUPINFO {public uint cb;public string r1,r2,r3;public uint x,y,xs,ys,xc,yc,fill,flags;public ushort show,reserved;public IntPtr r5,hStdInput,hStdOutput,hStdError;}
  [StructLayout(LayoutKind.Sequential)] struct STARTUPINFOEX {public STARTUPINFO StartupInfo;public IntPtr AttributeList;}
  [StructLayout(LayoutKind.Sequential)] struct PROCESS_INFORMATION {public IntPtr hProcess,hThread;public uint dwProcessId,dwThreadId;}
  [StructLayout(LayoutKind.Sequential)] struct SECURITY_ATTRIBUTES {public int nLength;public IntPtr lpSecurityDescriptor;public bool bInheritHandle;}
  [StructLayout(LayoutKind.Sequential)] struct FILETIME {public uint low,high;}
  [StructLayout(LayoutKind.Sequential)] struct BY_HANDLE_FILE_INFORMATION {public uint attributes;public FILETIME creation,access,write;public uint volume,sizeHigh,sizeLow,links,indexHigh,indexLow;}
  [DllImport("kernel32.dll",SetLastError=true)] static extern IntPtr CreateToolhelp32Snapshot(uint f,uint p);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool Process32FirstW(IntPtr s,ref PROCESSENTRY32W e);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool Process32NextW(IntPtr s,ref PROCESSENTRY32W e);
  [DllImport("kernel32.dll",SetLastError=true)] static extern IntPtr OpenProcess(uint a,bool i,uint p);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool CloseHandle(IntPtr h);
  [DllImport("kernel32.dll",SetLastError=true,CharSet=CharSet.Unicode)] static extern bool QueryFullProcessImageNameW(IntPtr h,uint f,StringBuilder b,ref int n);
  [DllImport("kernel32.dll",SetLastError=true,CharSet=CharSet.Unicode)] static extern uint GetFinalPathNameByHandleW(IntPtr h,StringBuilder b,uint n,uint f);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool GetFileInformationByHandle(IntPtr h,out BY_HANDLE_FILE_INFORMATION i);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool GetProcessTimes(IntPtr h,out long c,out long e,out long k,out long u);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool GetExitCodeProcess(IntPtr h,out uint c);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool TerminateProcess(IntPtr h,uint c);
  [DllImport("kernel32.dll",SetLastError=true)] static extern uint WaitForSingleObject(IntPtr h,uint t);
  [DllImport("kernel32.dll",SetLastError=true,CharSet=CharSet.Unicode)] static extern IntPtr CreateJobObjectW(IntPtr a,string n);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool SetInformationJobObject(IntPtr j,int c,IntPtr b,uint n);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool QueryInformationJobObject(IntPtr j,int c,IntPtr b,uint n,IntPtr r);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool TerminateJobObject(IntPtr j,uint c);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool IsProcessInJob(IntPtr p,IntPtr j,out bool v);
  [DllImport("kernel32.dll",SetLastError=true)] static extern uint ResumeThread(IntPtr h);
  [DllImport("kernel32.dll",SetLastError=true,CharSet=CharSet.Unicode)] static extern bool CreateProcessW(string app,StringBuilder cmd,IntPtr pa,IntPtr ta,bool inherit,uint flags,IntPtr env,string cwd,ref STARTUPINFOEX si,out PROCESS_INFORMATION pi);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool InitializeProcThreadAttributeList(IntPtr l,int c,int f,ref IntPtr s);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool UpdateProcThreadAttribute(IntPtr l,uint f,IntPtr a,IntPtr v,IntPtr n,IntPtr p,IntPtr q);
  [DllImport("kernel32.dll")] static extern void DeleteProcThreadAttributeList(IntPtr l);
  [DllImport("kernel32.dll",SetLastError=true,CharSet=CharSet.Unicode)] static extern IntPtr CreateFileW(string n,uint a,uint sh,ref SECURITY_ATTRIBUTES sa,uint d,uint fl,IntPtr t);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool GetFileSizeEx(IntPtr h,out long n);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool SetFilePointerEx(IntPtr h,long d,out long p,uint m);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool ReadFile(IntPtr h,byte[] b,uint n,out uint r,IntPtr o);
  [DllImport("kernel32.dll")] static extern void SetLastError(uint e);
  [DllImport("ntdll.dll")] static extern int NtQueryInformationProcess(IntPtr h,int c,IntPtr b,int n,out int r);
  [DllImport("shell32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern IntPtr CommandLineToArgvW(string x,out int n);
  [DllImport("kernel32.dll")] static extern IntPtr LocalFree(IntPtr p);
  static void Need(bool ok,string what){if(!ok)throw new Win32Exception(Marshal.GetLastWin32Error(),what);}
  static void AbiSize(Type t,int x86,int x64){int actual=Marshal.SizeOf(t),expected=IntPtr.Size==8?x64:x86;if(actual!=expected)throw new InvalidOperationException(String.Format("native ABI size failed {0}: {1}!={2}",t.Name,actual,expected));}
  static void AbiOffset(Type t,string field,int x86,int x64){long actual=Marshal.OffsetOf(t,field).ToInt64(),expected=IntPtr.Size==8?x64:x86;if(actual!=expected)throw new InvalidOperationException(String.Format("native ABI offset failed {0}.{1}: {2}!={3}",t.Name,field,actual,expected));}
  public static void AssertAbi(){
   AbiSize(typeof(PROCESSENTRY32W),556,568);AbiOffset(typeof(PROCESSENTRY32W),"dwSize",0,0);AbiOffset(typeof(PROCESSENTRY32W),"cntUsage",4,4);AbiOffset(typeof(PROCESSENTRY32W),"th32ProcessID",8,8);AbiOffset(typeof(PROCESSENTRY32W),"heap",12,16);AbiOffset(typeof(PROCESSENTRY32W),"mod",16,24);AbiOffset(typeof(PROCESSENTRY32W),"threads",20,28);AbiOffset(typeof(PROCESSENTRY32W),"parent",24,32);AbiOffset(typeof(PROCESSENTRY32W),"pri",28,36);AbiOffset(typeof(PROCESSENTRY32W),"flags",32,40);AbiOffset(typeof(PROCESSENTRY32W),"exe",36,44);
   AbiSize(typeof(UNICODE_STRING),8,16);AbiOffset(typeof(UNICODE_STRING),"Length",0,0);AbiOffset(typeof(UNICODE_STRING),"MaximumLength",2,2);AbiOffset(typeof(UNICODE_STRING),"Buffer",4,8);
   AbiSize(typeof(JOBOBJECT_BASIC_LIMIT_INFORMATION),48,64);AbiOffset(typeof(JOBOBJECT_BASIC_LIMIT_INFORMATION),"a",0,0);AbiOffset(typeof(JOBOBJECT_BASIC_LIMIT_INFORMATION),"b",8,8);AbiOffset(typeof(JOBOBJECT_BASIC_LIMIT_INFORMATION),"LimitFlags",16,16);AbiOffset(typeof(JOBOBJECT_BASIC_LIMIT_INFORMATION),"min",20,24);AbiOffset(typeof(JOBOBJECT_BASIC_LIMIT_INFORMATION),"max",24,32);AbiOffset(typeof(JOBOBJECT_BASIC_LIMIT_INFORMATION),"active",28,40);AbiOffset(typeof(JOBOBJECT_BASIC_LIMIT_INFORMATION),"affinity",32,48);AbiOffset(typeof(JOBOBJECT_BASIC_LIMIT_INFORMATION),"priority",36,56);AbiOffset(typeof(JOBOBJECT_BASIC_LIMIT_INFORMATION),"scheduling",40,60);
   AbiSize(typeof(IO_COUNTERS),48,48);AbiOffset(typeof(IO_COUNTERS),"a",0,0);AbiOffset(typeof(IO_COUNTERS),"b",8,8);AbiOffset(typeof(IO_COUNTERS),"c",16,16);AbiOffset(typeof(IO_COUNTERS),"d",24,24);AbiOffset(typeof(IO_COUNTERS),"e",32,32);AbiOffset(typeof(IO_COUNTERS),"f",40,40);
   AbiSize(typeof(JOBOBJECT_EXTENDED_LIMIT_INFORMATION),112,144);AbiOffset(typeof(JOBOBJECT_EXTENDED_LIMIT_INFORMATION),"BasicLimitInformation",0,0);AbiOffset(typeof(JOBOBJECT_EXTENDED_LIMIT_INFORMATION),"IoInfo",48,64);AbiOffset(typeof(JOBOBJECT_EXTENDED_LIMIT_INFORMATION),"a",96,112);AbiOffset(typeof(JOBOBJECT_EXTENDED_LIMIT_INFORMATION),"b",100,120);AbiOffset(typeof(JOBOBJECT_EXTENDED_LIMIT_INFORMATION),"c",104,128);AbiOffset(typeof(JOBOBJECT_EXTENDED_LIMIT_INFORMATION),"d",108,136);
   AbiSize(typeof(JOBOBJECT_BASIC_ACCOUNTING_INFORMATION),48,48);AbiOffset(typeof(JOBOBJECT_BASIC_ACCOUNTING_INFORMATION),"a",0,0);AbiOffset(typeof(JOBOBJECT_BASIC_ACCOUNTING_INFORMATION),"b",8,8);AbiOffset(typeof(JOBOBJECT_BASIC_ACCOUNTING_INFORMATION),"c",16,16);AbiOffset(typeof(JOBOBJECT_BASIC_ACCOUNTING_INFORMATION),"d",24,24);AbiOffset(typeof(JOBOBJECT_BASIC_ACCOUNTING_INFORMATION),"faults",32,32);AbiOffset(typeof(JOBOBJECT_BASIC_ACCOUNTING_INFORMATION),"TotalProcesses",36,36);AbiOffset(typeof(JOBOBJECT_BASIC_ACCOUNTING_INFORMATION),"ActiveProcesses",40,40);AbiOffset(typeof(JOBOBJECT_BASIC_ACCOUNTING_INFORMATION),"TerminatedProcesses",44,44);
   AbiSize(typeof(STARTUPINFO),68,104);AbiOffset(typeof(STARTUPINFO),"cb",0,0);AbiOffset(typeof(STARTUPINFO),"r1",4,8);AbiOffset(typeof(STARTUPINFO),"r2",8,16);AbiOffset(typeof(STARTUPINFO),"r3",12,24);AbiOffset(typeof(STARTUPINFO),"x",16,32);AbiOffset(typeof(STARTUPINFO),"y",20,36);AbiOffset(typeof(STARTUPINFO),"xs",24,40);AbiOffset(typeof(STARTUPINFO),"ys",28,44);AbiOffset(typeof(STARTUPINFO),"xc",32,48);AbiOffset(typeof(STARTUPINFO),"yc",36,52);AbiOffset(typeof(STARTUPINFO),"fill",40,56);AbiOffset(typeof(STARTUPINFO),"flags",44,60);AbiOffset(typeof(STARTUPINFO),"show",48,64);AbiOffset(typeof(STARTUPINFO),"reserved",50,66);AbiOffset(typeof(STARTUPINFO),"r5",52,72);AbiOffset(typeof(STARTUPINFO),"hStdInput",56,80);AbiOffset(typeof(STARTUPINFO),"hStdOutput",60,88);AbiOffset(typeof(STARTUPINFO),"hStdError",64,96);
   AbiSize(typeof(STARTUPINFOEX),72,112);AbiOffset(typeof(STARTUPINFOEX),"StartupInfo",0,0);AbiOffset(typeof(STARTUPINFOEX),"AttributeList",68,104);
   AbiSize(typeof(PROCESS_INFORMATION),16,24);AbiOffset(typeof(PROCESS_INFORMATION),"hProcess",0,0);AbiOffset(typeof(PROCESS_INFORMATION),"hThread",4,8);AbiOffset(typeof(PROCESS_INFORMATION),"dwProcessId",8,16);AbiOffset(typeof(PROCESS_INFORMATION),"dwThreadId",12,20);
   AbiSize(typeof(SECURITY_ATTRIBUTES),12,24);AbiOffset(typeof(SECURITY_ATTRIBUTES),"nLength",0,0);AbiOffset(typeof(SECURITY_ATTRIBUTES),"lpSecurityDescriptor",4,8);AbiOffset(typeof(SECURITY_ATTRIBUTES),"bInheritHandle",8,16);
   AbiSize(typeof(FILETIME),8,8);AbiOffset(typeof(FILETIME),"low",0,0);AbiOffset(typeof(FILETIME),"high",4,4);
   AbiSize(typeof(BY_HANDLE_FILE_INFORMATION),52,52);AbiOffset(typeof(BY_HANDLE_FILE_INFORMATION),"attributes",0,0);AbiOffset(typeof(BY_HANDLE_FILE_INFORMATION),"creation",4,4);AbiOffset(typeof(BY_HANDLE_FILE_INFORMATION),"access",12,12);AbiOffset(typeof(BY_HANDLE_FILE_INFORMATION),"write",20,20);AbiOffset(typeof(BY_HANDLE_FILE_INFORMATION),"volume",28,28);AbiOffset(typeof(BY_HANDLE_FILE_INFORMATION),"sizeHigh",32,32);AbiOffset(typeof(BY_HANDLE_FILE_INFORMATION),"sizeLow",36,36);AbiOffset(typeof(BY_HANDLE_FILE_INFORMATION),"links",40,40);AbiOffset(typeof(BY_HANDLE_FILE_INFORMATION),"indexHigh",44,44);AbiOffset(typeof(BY_HANDLE_FILE_INFORMATION),"indexLow",48,48);
  }
   static long Now(){return Stopwatch.GetTimestamp();}
   static int Remaining(long deadline){long delta=deadline-Now();if(delta<=0)return 0;long ms=delta*1000/Stopwatch.Frequency;return (int)Math.Min(Int32.MaxValue,Math.Max(1,ms));}
   static void CheckWatch(SupervisorWatch w){if(w==null)throw new InvalidOperationException("supervisor watcher failure");IntPtr h;lock(w.Gate){if(w.Failed||w.Handle==IntPtr.Zero)throw new InvalidOperationException("supervisor watcher failure");h=w.Handle;}if(Created(h)!=w.Creation)throw new InvalidOperationException("supervisor watcher failure");uint r=WaitForSingleObject(h,0);if(r==WAIT_TIMEOUT)return;if(r==0xffffffff)throw new Win32Exception(Marshal.GetLastWin32Error(),"WaitForSingleObject supervisor");throw new InvalidOperationException("supervisor watcher failure");}
   static void FailWatch(SupervisorWatch w){IntPtr j;lock(w.Gate){w.Failed=true;j=w.Job;}if(j!=IntPtr.Zero&&!TerminateJobObject(j,9))Environment.FailFast("supervisor watcher containment failure",new Win32Exception(Marshal.GetLastWin32Error()));Environment.Exit(7);}
   static void StartWatch(SupervisorWatch w,long deadline,string fault){
    var thread=new Thread(()=>{
     try{
      IntPtr h;lock(w.Gate){h=w.Handle;}
      if(h==IntPtr.Zero||Created(h)!=w.Creation)throw new InvalidOperationException("supervisor watcher failure");
      uint first=WaitForSingleObject(h,0);
      if(first!=WAIT_TIMEOUT){if(first==0xffffffff)Environment.FailFast("supervisor watcher wait failure",new Win32Exception(Marshal.GetLastWin32Error()));FailWatch(w);return;}
      if(fault=="watcher-ready-timeout")Thread.Sleep(Remaining(deadline)+50);
      w.Ready.Set();
      while(true){
       if(w.Stop.WaitOne(Math.Min(5,Math.Max(1,Remaining(deadline)))))return;
       if(Now()>=deadline){FailWatch(w);return;}
       lock(w.Gate){h=w.Handle;}
       if(h==IntPtr.Zero)return;
       uint r=WaitForSingleObject(h,0);
       if(r==WAIT_TIMEOUT)continue;
       if(r==0xffffffff)Environment.FailFast("supervisor watcher wait failure",new Win32Exception(Marshal.GetLastWin32Error()));
       FailWatch(w);return;
      }
     }catch(Exception){lock(w.Gate){w.Failed=true;}w.Ready.Set();}
     finally{w.Done.Set();}
    });
    thread.IsBackground=true;thread.Start();
   }
   static void AttachWatch(SupervisorWatch w,IntPtr job){CheckWatch(w);lock(w.Gate){if(w.Failed||w.Handle==IntPtr.Zero)throw new InvalidOperationException("supervisor watcher failure");w.Job=job;}CheckWatch(w);}
   static void DetachWatch(SupervisorWatch w,IntPtr job){if(w==null)return;lock(w.Gate){if(w.Job==job)w.Job=IntPtr.Zero;}}
  static string FinalPath(IntPtr h){var b=new StringBuilder(32768);uint n=GetFinalPathNameByHandleW(h,b,(uint)b.Capacity,0);if(n==0)throw new Win32Exception(Marshal.GetLastWin32Error(),"GetFinalPathNameByHandleW");if(n>=b.Capacity)throw new InvalidOperationException("final path buffer changed");string path=b.ToString();if(path.StartsWith(@"\\?\UNC\",StringComparison.OrdinalIgnoreCase))return @"\\"+path.Substring(8);if(path.StartsWith(@"\\?\",StringComparison.OrdinalIgnoreCase))return path.Substring(4);return path;}
  static FileIdentity FromHandle(IntPtr h){BY_HANDLE_FILE_INFORMATION i;if(h==IntPtr.Zero)throw new InvalidOperationException("zero identity handle");if(!GetFileInformationByHandle(h,out i))throw new Win32Exception(Marshal.GetLastWin32Error(),"GetFileInformationByHandle");string p=FinalPath(h);if(String.IsNullOrEmpty(p))throw new InvalidOperationException("empty final identity path");return new FileIdentity{Handle=h,DiagnosticPath=p,Volume=i.volume,IndexHigh=i.indexHigh,IndexLow=i.indexLow};}
   public static FileIdentity OpenIdentity(string path,bool directory){var sa=new SECURITY_ATTRIBUTES{nLength=Marshal.SizeOf(typeof(SECURITY_ATTRIBUTES)),bInheritHandle=false};uint share=directory?3u:7u;IntPtr h=CreateFileW(path,0x80|SYNCHRONIZE,share,ref sa,3,directory?0x02000000u:0,IntPtr.Zero);if(h==INVALID)throw new Win32Exception(Marshal.GetLastWin32Error(),"CreateFile identity");try{var x=FromHandle(h);bool actualDirectory=(GetAttributes(h)&0x10)!=0;if(actualDirectory!=directory)throw new InvalidOperationException("identity type mismatch");return x;}catch{Need(CloseHandle(h),"CloseHandle failed identity");throw;}}
   static uint GetAttributes(IntPtr h){BY_HANDLE_FILE_INFORMATION i;if(!GetFileInformationByHandle(h,out i))throw new Win32Exception(Marshal.GetLastWin32Error(),"GetFileInformationByHandle attributes");return i.attributes;}
   public static void ValidateProject(FileIdentity project){if(project==null||project.Handle==IntPtr.Zero||(GetAttributes(project.Handle)&0x10)==0)throw new InvalidOperationException("invalid retained project directory");var sa=new SECURITY_ATTRIBUTES{nLength=Marshal.SizeOf(typeof(SECURITY_ATTRIBUTES)),bInheritHandle=false};IntPtr h=CreateFileW(Path.Combine(project.DiagnosticPath,"project.godot"),0x80,3,ref sa,3,0,IntPtr.Zero);if(h==INVALID)throw new InvalidOperationException("retained project missing project.godot");try{if((GetAttributes(h)&0x10)!=0)throw new InvalidOperationException("project.godot is a directory");}finally{Need(CloseHandle(h),"CloseHandle project.godot");}}
   public static void RefreshProject(FileIdentity project){if(project==null||project.Handle==IntPtr.Zero)throw new InvalidOperationException("invalid retained project directory");string original=project.DiagnosticPath,current=FinalPath(project.Handle);project.DiagnosticPath=current;ValidateProject(project);if(!String.Equals(original,current,StringComparison.OrdinalIgnoreCase))throw new InvalidOperationException("retained project pathname replaced");}
  public static void CloseIdentity(FileIdentity x){if(x!=null&&x.Handle!=IntPtr.Zero){Need(CloseHandle(x.Handle),"CloseHandle identity");x.Handle=IntPtr.Zero;}}
  static FileIdentity ProcessImage(IntPtr h){int n=32768;var b=new StringBuilder(n);if(!QueryFullProcessImageNameW(h,0,b,ref n))throw new Win32Exception(Marshal.GetLastWin32Error(),"QueryFullProcessImageNameW");return OpenIdentity(b.ToString(),false);}
  static long Created(IntPtr h){long a,b,c,d;if(!GetProcessTimes(h,out a,out b,out c,out d))throw new Win32Exception(Marshal.GetLastWin32Error(),"GetProcessTimes");return a;}
  static string Cmd(IntPtr h){int n;int s=NtQueryInformationProcess(h,60,IntPtr.Zero,0,out n);if(s!=unchecked((int)0xC0000004)||n<Marshal.SizeOf(typeof(UNICODE_STRING))||n>1048576)return null;IntPtr b=Marshal.AllocHGlobal(n);try{s=NtQueryInformationProcess(h,60,b,n,out n);if(s!=0)return null;var u=(UNICODE_STRING)Marshal.PtrToStructure(b,typeof(UNICODE_STRING));long lo=b.ToInt64(),hi=lo+n,ptr=u.Buffer.ToInt64();if(ptr<lo||ptr+u.Length>hi||u.Buffer==IntPtr.Zero||u.Length>u.MaximumLength||((u.Length&1)!=0)||u.Length>65534)return null;return Marshal.PtrToStringUni(u.Buffer,u.Length/2);}finally{Marshal.FreeHGlobal(b);}}
  static string[] Argv(string s){int n;IntPtr p=CommandLineToArgvW(s,out n);if(p==IntPtr.Zero)return null;try{var r=new string[n];for(int i=0;i<n;i++){r[i]=Marshal.PtrToStringUni(Marshal.ReadIntPtr(p,i*IntPtr.Size));if(r[i]==null)return null;}return r;}finally{if(LocalFree(p)!=IntPtr.Zero)throw new Win32Exception(Marshal.GetLastWin32Error(),"LocalFree argv");}}
  enum Match { VerifiedTarget,VerifiedOther,Ambiguous }
   static Match SameProject(string cmd,FileIdentity project){var a=Argv(cmd);if(a==null||a.Length==0)return Match.Ambiguous;bool headless=false,other=false;var paths=new List<string>();for(int i=1;i<a.Length;i++){if(a[i]=="--")break;if(a[i]=="--headless"){if(headless)return Match.Ambiguous;headless=true;continue;}if(a[i].StartsWith("--headless=",StringComparison.OrdinalIgnoreCase))return Match.Ambiguous;string p=null;if(a[i]=="--path"){if(++i>=a.Length)return Match.Ambiguous;p=a[i];}else if(a[i].StartsWith("--path=",StringComparison.OrdinalIgnoreCase)){p=a[i].Substring(7);}if(p!=null){if(String.IsNullOrEmpty(p)||!Path.IsPathRooted(p)||paths.Count>=1)return Match.Ambiguous;paths.Add(p);}}foreach(string p in paths){FileIdentity x=null;try{x=OpenIdentity(p,true);if(!x.Same(project))other=true;}catch{return Match.Ambiguous;}finally{if(x!=null)CloseIdentity(x);}}return headless&&paths.Count==1&&!other?Match.VerifiedTarget:Match.VerifiedOther;}
  // W2/W3: Toolhelp is only a basename filter.  Each same-basename process has
  // a retained query/terminate handle and must have complete native identity.
  public static Existing[] Inventory(FileIdentity exe,FileIdentity project,string fault){var r=new List<Existing>();if(fault=="inventory-denied")throw new InvalidOperationException("unverifiable same-basename process");IntPtr s=CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS,0);if(s==INVALID)throw new Win32Exception(Marshal.GetLastWin32Error(),"snapshot");try{var e=new PROCESSENTRY32W();e.dwSize=(uint)Marshal.SizeOf(typeof(PROCESSENTRY32W));if(fault=="toolhelp-first")throw new Win32Exception(5,"Process32FirstW");if(!Process32FirstW(s,ref e)){int z=Marshal.GetLastWin32Error();if(z==18)return r.ToArray();throw new Win32Exception(z,"Process32FirstW");}while(true){if(String.Equals(e.exe,Path.GetFileName(exe.DiagnosticPath),StringComparison.OrdinalIgnoreCase)){IntPtr h=OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION|PROCESS_TERMINATE|SYNCHRONIZE,false,e.th32ProcessID);if(h==IntPtr.Zero)throw new InvalidOperationException("unverifiable same-basename process");FileIdentity im=null;try{im=ProcessImage(h);string cmd=Cmd(h);long cr=Created(h);Match m=cmd==null?Match.Ambiguous:SameProject(cmd,project);if(cr==0||m==Match.Ambiguous)throw new InvalidOperationException("unverifiable same-basename process");if(im.Same(exe)&&m==Match.VerifiedTarget){r.Add(new Existing{Pid=(int)e.th32ProcessID,Handle=h,Creation=cr});h=IntPtr.Zero;}}finally{if(im!=null)CloseIdentity(im);if(h!=IntPtr.Zero)Need(CloseHandle(h),"CloseHandle inventory process");}}if(fault=="toolhelp-next")throw new Win32Exception(5,"Process32NextW");e.dwSize=(uint)Marshal.SizeOf(typeof(PROCESSENTRY32W));SetLastError(0);if(Process32NextW(s,ref e))continue;int z2=Marshal.GetLastWin32Error();if(z2==18)break;throw new Win32Exception(z2,"Process32NextW");}return r.ToArray();}catch{Exception closeError=null;foreach(var x in r){IntPtr retained=x.Handle;CloseOrdered(ref retained,"CloseHandle retained inventory process",ref closeError);x.Handle=IntPtr.Zero;}if(closeError!=null)throw new InvalidOperationException("inventory handle cleanup failure",closeError);throw;}finally{Need(CloseHandle(s),"CloseHandle snapshot");}}
   public static int[] Cleanup(Existing[] xs,string fault,long deadline){var p=new List<int>();try{foreach(var x in xs){if(Now()>=deadline||fault=="retained-identity"||Created(x.Handle)!=x.Creation)throw new InvalidOperationException("retained identity changed");uint w=WaitForSingleObject(x.Handle,0);if(w==WAIT_OBJECT_0)continue;if(w==0xffffffff)throw new Win32Exception(Marshal.GetLastWin32Error(),"WaitForSingleObject existing");if(w!=WAIT_TIMEOUT)throw new InvalidOperationException("unexpected existing wait state");Need(TerminateProcess(x.Handle,1),"TerminateProcess");int left=Remaining(deadline);if(left<=0)throw new TimeoutException("preexisting cleanup deadline");w=WaitForSingleObject(x.Handle,(uint)left);if(w==0xffffffff)throw new Win32Exception(Marshal.GetLastWin32Error(),"WaitForSingleObject terminated existing");if(w!=WAIT_OBJECT_0)throw new InvalidOperationException("preexisting cleanup wait failed");p.Add(x.Pid);}return p.ToArray();}finally{Exception closeError=null;foreach(var x in xs){IntPtr retained=x.Handle;CloseOrdered(ref retained,"CloseHandle cleaned process",ref closeError);x.Handle=IntPtr.Zero;}if(closeError!=null)throw new InvalidOperationException("cleaned handle close failure",closeError);}}
  static IntPtr Job(){IntPtr j=CreateJobObjectW(IntPtr.Zero,null);if(j==IntPtr.Zero)throw new Win32Exception(Marshal.GetLastWin32Error(),"CreateJobObject");var x=new JOBOBJECT_EXTENDED_LIMIT_INFORMATION();x.BasicLimitInformation.LimitFlags=JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;int n=Marshal.SizeOf(x);IntPtr b=Marshal.AllocHGlobal(n);try{Marshal.StructureToPtr(x,b,false);Need(SetInformationJobObject(j,JobObjectExtendedLimitInformation,b,(uint)n),"SetInformationJobObject");return j;}catch{Need(CloseHandle(j),"CloseHandle failed job");throw;}finally{Marshal.FreeHGlobal(b);}}
  static bool Empty(IntPtr j,string fault){if(fault=="query-failure"||fault=="cleanup-overrides")throw new Win32Exception(5,"QueryInformationJobObject");int n=Marshal.SizeOf(typeof(JOBOBJECT_BASIC_ACCOUNTING_INFORMATION));IntPtr b=Marshal.AllocHGlobal(n);try{Need(QueryInformationJobObject(j,JobObjectBasicAccountingInformation,b,(uint)n,IntPtr.Zero),"QueryInformationJobObject");return ((JOBOBJECT_BASIC_ACCOUNTING_INFORMATION)Marshal.PtrToStructure(b,typeof(JOBOBJECT_BASIC_ACCOUNTING_INFORMATION))).ActiveProcesses==0;}finally{Marshal.FreeHGlobal(b);}}
  static IntPtr Capture(string path){var sa=new SECURITY_ATTRIBUTES{nLength=Marshal.SizeOf(typeof(SECURITY_ATTRIBUTES)),bInheritHandle=true};IntPtr h=CreateFileW(path,0xC0000000,3,ref sa,2,0x80,IntPtr.Zero);if(h==INVALID)throw new Win32Exception(Marshal.GetLastWin32Error(),"CreateFile capture");return h;}
  static CaptureRead StartCaptureRead(IntPtr h,int cap,long deadline,string fault){var result=new CaptureRead();new Thread(()=>{try{if(fault=="capture-read-failure")throw new Win32Exception(5,"forced capture ReadFile failure");long initial,pos;Need(GetFileSizeEx(h,out initial),"GetFileSizeEx capture");if(initial<0||initial>cap)throw new InvalidOperationException("capture cap exceeded");Need(SetFilePointerEx(h,0,out pos,0),"SetFilePointerEx capture");var data=new MemoryStream();var buffer=new byte[4096];while(true){if(Now()>=deadline)throw new TimeoutException("capture deadline");uint got;Need(ReadFile(h,buffer,(uint)buffer.Length,out got,IntPtr.Zero),"ReadFile capture");if(got==0)break;if(data.Length+got>cap)throw new InvalidOperationException("capture cap exceeded");data.Write(buffer,0,(int)got);}long finalSize;Need(GetFileSizeEx(h,out finalSize),"GetFileSizeEx capture final");if(finalSize!=initial||data.Length!=initial)throw new InvalidOperationException("capture growth or short read");var extra=new byte[1];uint extraCount;Need(ReadFile(h,extra,1,out extraCount,IntPtr.Zero),"ReadFile capture sentinel");if(extraCount!=0)throw new InvalidOperationException("capture extra data");result.Data=data.ToArray();}catch(Exception e){result.Error=e;}finally{result.Done.Set();}}){IsBackground=true}.Start();return result;}
   static string FinishCapture(CaptureRead read,long deadline){int remaining=Remaining(deadline);if(remaining<=0||!read.Done.WaitOne(remaining))throw new TimeoutException("capture deadline");if(read.Error!=null)throw new InvalidOperationException("capture read failed",read.Error);return Encoding.UTF8.GetString(read.Data??new byte[0]);}
  static void FinishCapturePair(CaptureRead stdout,CaptureRead stderr,long deadline,out string stdoutText,out string stderrText){stdoutText=null;stderrText=null;Exception first=null;try{stdoutText=FinishCapture(stdout,deadline);}catch(Exception e){first=e;}try{stderrText=FinishCapture(stderr,deadline);}catch(Exception e){if(first==null)first=e;}if(first!=null)throw first;}
  static void CloseOrdered(ref IntPtr h,string what,ref Exception first){if(h==IntPtr.Zero)return;try{Need(CloseHandle(h),what);}catch(Exception e){if(first==null)first=e;}finally{h=IntPtr.Zero;}}
   public static SupervisorWatch OpenSupervisorWatch(int pid,long creation,long deadline,string fault){IntPtr h=OpenProcess(SYNCHRONIZE|PROCESS_QUERY_LIMITED_INFORMATION,false,(uint)pid);if(h==IntPtr.Zero||fault=="watcher-failure"){if(h!=IntPtr.Zero)Need(CloseHandle(h),"CloseHandle rejected supervisor");throw new InvalidOperationException("supervisor watcher failure");}var w=new SupervisorWatch{Handle=h,Creation=creation};try{CheckWatch(w);StartWatch(w,deadline,fault);int remaining=Remaining(deadline);if(remaining<=0||!w.Ready.WaitOne(remaining)){throw new TimeoutException("supervisor watcher ready deadline");}CheckWatch(w);return w;}catch{w.Stop.Set();w.Done.WaitOne(Math.Max(1,Remaining(deadline)));lock(w.Gate){h=w.Handle;w.Handle=IntPtr.Zero;}if(h!=IntPtr.Zero)Need(CloseHandle(h),"CloseHandle failed supervisor watch");throw;}}
  public static void VerifySupervisorWatch(SupervisorWatch w){CheckWatch(w);}
   public static void CloseSupervisorWatch(SupervisorWatch w,long deadline){if(w==null)return;w.Stop.Set();int remaining=Remaining(deadline);if(remaining<=0||!w.Done.WaitOne(remaining))throw new TimeoutException("supervisor watcher close deadline");IntPtr h;lock(w.Gate){h=w.Handle;w.Handle=IntPtr.Zero;w.Job=IntPtr.Zero;}if(h!=IntPtr.Zero)Need(CloseHandle(h),"CloseHandle supervisor");}
  // W4-W8: JOB_LIST and HANDLE_LIST are installed before CreateProcessW.  Captures
  // are completed from the retained native handles only after root/job completion.
  public static Result Run(FileIdentity exe,string args,FileIdentity project,string outp,string errp,SupervisorWatch watch,long engineDeadline,long totalDeadline,int poll,string fault){
   AssertAbi();IntPtr j=IntPtr.Zero,attr=IntPtr.Zero,jobp=IntPtr.Zero,handles=IntPtr.Zero,oh=IntPtr.Zero,eh=IntPtr.Zero;PROCESS_INFORMATION pi=new PROCESS_INFORMATION();bool made=false;Exception cleanupError=null;
   try{
    CheckWatch(watch);j=Job();AttachWatch(watch,j);CheckWatch(watch);oh=Capture(outp);eh=Capture(errp);
    IntPtr size=IntPtr.Zero;SetLastError(0);bool sizing=InitializeProcThreadAttributeList(IntPtr.Zero,2,0,ref size);int sizingError=Marshal.GetLastWin32Error();if(sizing||sizingError!=122||size==IntPtr.Zero)throw new Win32Exception(sizingError,"InitializeProcThreadAttributeList sizing");
    attr=Marshal.AllocHGlobal(size);Need(InitializeProcThreadAttributeList(attr,2,0,ref size),"InitializeProcThreadAttributeList");jobp=Marshal.AllocHGlobal(IntPtr.Size);Marshal.WriteIntPtr(jobp,j);if(fault=="job-attribute")throw new Win32Exception(5,"JOB_LIST");Need(UpdateProcThreadAttribute(attr,0,new IntPtr(PROC_THREAD_ATTRIBUTE_JOB_LIST),jobp,new IntPtr(IntPtr.Size),IntPtr.Zero,IntPtr.Zero),"JOB_LIST");
    handles=Marshal.AllocHGlobal(IntPtr.Size*2);Marshal.WriteIntPtr(handles,0,oh);Marshal.WriteIntPtr(handles,IntPtr.Size,eh);Need(UpdateProcThreadAttribute(attr,0,new IntPtr(PROC_THREAD_ATTRIBUTE_HANDLE_LIST),handles,new IntPtr(IntPtr.Size*2),IntPtr.Zero,IntPtr.Zero),"HANDLE_LIST");
    var si=new STARTUPINFOEX();si.StartupInfo.cb=(uint)Marshal.SizeOf(typeof(STARTUPINFOEX));si.StartupInfo.flags=0x100;si.StartupInfo.hStdOutput=oh;si.StartupInfo.hStdError=eh;si.AttributeList=attr;var command=new StringBuilder("\""+exe.DiagnosticPath+"\" "+args);
     if(fault=="pause-before-create")Thread.Sleep(5000);CheckWatch(watch);if(fault=="create-failure")throw new Win32Exception(5,"CreateProcessW JOB_LIST");Need(CreateProcessW(exe.DiagnosticPath,command,IntPtr.Zero,IntPtr.Zero,true,CREATE_SUSPENDED|EXTENDED_STARTUPINFO_PRESENT,IntPtr.Zero,project.DiagnosticPath,ref si,out pi),"CreateProcessW JOB_LIST");made=true;if(fault=="post-create-kill")throw new InvalidOperationException("post-create pre-resume failure");
    bool inJob;FileIdentity actual=ProcessImage(pi.hProcess);try{CheckWatch(watch);Need(IsProcessInJob(pi.hProcess,j,out inJob),"IsProcessInJob");if(fault=="post-create-identity"||!inJob||!actual.Same(exe)||Created(pi.hProcess)==0)throw new InvalidOperationException("post-create identity/job verification failed");}finally{if(actual!=null)CloseIdentity(actual);}
     if(fault=="pause-before-resume")Thread.Sleep(10000);CheckWatch(watch);RefreshProject(project);if(fault=="resume-failure")throw new Win32Exception(5,"ResumeThread");if(ResumeThread(pi.hThread)==uint.MaxValue)throw new Win32Exception(Marshal.GetLastWin32Error(),"ResumeThread");
    var result=new Result();while(true){if(Now()>=engineDeadline){result.TimedOut=true;break;}uint w=WaitForSingleObject(pi.hProcess,(uint)Math.Min(poll,Math.Max(1,Remaining(engineDeadline))));if(w==0xffffffff)throw new Win32Exception(Marshal.GetLastWin32Error(),"WaitForSingleObject engine");if(w==WAIT_TIMEOUT)continue;if(w!=WAIT_OBJECT_0)throw new InvalidOperationException("unexpected engine wait state");if(Empty(j,fault)){uint code;Need(GetExitCodeProcess(pi.hProcess,out code),"GetExitCodeProcess");result.ExitCode=(int)code;result.Empty=true;break;}}
    if(!result.Empty){Need(TerminateJobObject(j,2),"TerminateJobObject");while(Now()<totalDeadline&&!Empty(j,fault))Thread.Sleep(Math.Min(10,Math.Max(1,Remaining(totalDeadline))));result.Empty=Empty(j,fault);}
    if(!result.Empty)throw new InvalidOperationException("job containment deadline");CaptureRead stdout=StartCaptureRead(oh,262144,totalDeadline,fault),stderr=StartCaptureRead(eh,262144,totalDeadline,fault);FinishCapturePair(stdout,stderr,totalDeadline,out result.Stdout,out result.Stderr);return result;
   }finally{
     if(made&&j!=IntPtr.Zero){try{if(!Empty(j,"")){Need(TerminateJobObject(j,2),"TerminateJobObject cleanup");while(Now()<totalDeadline&&!Empty(j,""))Thread.Sleep(Math.Min(10,Math.Max(1,Remaining(totalDeadline))));if(!Empty(j,""))throw new InvalidOperationException("job cleanup proof failed");}}catch(Exception e){cleanupError=e;}}
    if(attr!=IntPtr.Zero){DeleteProcThreadAttributeList(attr);Marshal.FreeHGlobal(attr);attr=IntPtr.Zero;}if(jobp!=IntPtr.Zero){Marshal.FreeHGlobal(jobp);jobp=IntPtr.Zero;}if(handles!=IntPtr.Zero){Marshal.FreeHGlobal(handles);handles=IntPtr.Zero;}
     CloseOrdered(ref oh,"CloseHandle stdout capture",ref cleanupError);CloseOrdered(ref eh,"CloseHandle stderr capture",ref cleanupError);CloseOrdered(ref pi.hProcess,"CloseHandle process",ref cleanupError);CloseOrdered(ref pi.hThread,"CloseHandle thread",ref cleanupError);DetachWatch(watch,j);CloseOrdered(ref j,"CloseHandle job",ref cleanupError);if(cleanupError!=null)throw new InvalidOperationException("native cleanup failure",cleanupError);
   }
  }
 }
}
'@
}

# W0-W8 worker: no supervisor code below performs native access, path resolution,
# inventory, engine launch, capture, or cleanup.
function Invoke-Worker {
    $clock=[Diagnostics.Stopwatch]::StartNew()
    $project='';$log='';$cleaned=@();$exit=$null;$category='InvalidInput';$status='failed';$exeIdentity=$null;$projectIdentity=$null;$watch=$null
    try {
        if($WorkerFault -eq 'partial'){[Console]::Out.Write('GTR1 READY ');return}
        if($WorkerFault -eq 'hang-before-ready'){Start-Sleep -Seconds ($TimeoutSeconds+2)}
        if([string]::IsNullOrWhiteSpace($Nonce) -or $Nonce -notmatch '^[0-9a-f]{64}$'){throw 'invalid worker nonce'}
        # W1: retained native handles, not path spelling, establish executable/project authority.
        $args=Test-WorkerArguments
        foreach($a in $args){if($a.Length -gt $script:MaxInput -or $a.IndexOf([char]0)-ge 0 -or $a -ceq '--headless' -or $a -like '--headless=*' -or $a -ceq '--path' -or $a -like '--path=*' -or $a -ceq '--log-file' -or $a -like '--log-file=*'){throw 'reserved engine option'}}
        if([string]::IsNullOrWhiteSpace($LogFile)){$log=Join-Path ([IO.Path]::GetTempPath()) ('godot-test-'+[Guid]::NewGuid().ToString('N')+'.log')}else{$log=$LogFile}
        if((Get-Remaining $DeadlineTicks) -le 0){throw 'deadline'}
        Initialize-WorkerNative; [Gtr.Native]::AssertAbi();$watch=[Gtr.Native]::OpenSupervisorWatch($SupervisorPid,$SupervisorCreation,$DeadlineTicks,$WorkerFault);$exeIdentity=[Gtr.Native]::OpenIdentity($GodotPath,$false);$projectIdentity=[Gtr.Native]::OpenIdentity($ProjectPath,$true);[Gtr.Native]::ValidateProject($projectIdentity);$project=$projectIdentity.DiagnosticPath
        # W2: mutex derives from stable volume/file identity, not a canonical string.
        $key=Get-Sha256 "$($projectIdentity.Volume):$($projectIdentity.IndexHigh):$($projectIdentity.IndexLow)"
        if($WorkerFault -eq 'malformed-ready'){[Console]::Out.WriteLine((New-Frame 'READY' $Nonce @{mutexKey=$key;project=$project;extra='x'}));[Console]::Out.Flush();return}
        [Console]::Out.WriteLine((New-Frame 'READY' $Nonce @{mutexKey=$key;project=$project}));[Console]::Out.Flush()
        $go=Read-Frame (Read-ProtocolStdinLine) 'GO' $Nonce; if($go.action -cne 'go'){throw 'missing GO'}
        if($WorkerFault -eq 'hang-after-go'){Start-Sleep -Seconds ($TimeoutSeconds+2)}
        if($WorkerFault -eq 'pause-before-inventory'){Start-Sleep -Seconds 10}
        if($WorkerFault -eq 'malformed-final'){[Console]::Out.WriteLine((New-Frame 'FINAL' $Nonce @{status='failed';category='LaunchFailure';processExitCode=$null;project=$project;logPath=$log;cleanedPids=@();elapsedSeconds=0;extra='x'}));[Console]::Out.Flush();return}
        if($WorkerFault -eq 'final-duplicate'){[Console]::Out.WriteLine((New-Frame 'FINAL' $Nonce @{category='LaunchFailure';status='failed'}));[Console]::Out.Flush()}
        [Gtr.Native]::VerifySupervisorWatch($watch)
        $existing=@([Gtr.Native]::Inventory($exeIdentity,$projectIdentity,$WorkerFault))
        if($existing.Count -and -not $CleanupExisting){$category='PreexistingHeadlessProcess';throw 'existing guarded process'}
        if($existing.Count){[Console]::Out.WriteLine((New-Frame 'CLEANUP_BEGIN' $Nonce @{count=$existing.Count}));[Console]::Out.Flush();$category='CleanupFailure';[Gtr.Native]::VerifySupervisorWatch($watch);$cleaned=@([Gtr.Native]::Cleanup($existing,$WorkerFault,$DeadlineTicks));[Gtr.Native]::VerifySupervisorWatch($watch);$again=@([Gtr.Native]::Inventory($exeIdentity,$projectIdentity,''));if($again.Count){throw 'cleanup verification failed'};$category='InvalidInput'}elseif($WorkerFault -eq 'retained-identity'){$category='CleanupFailure';throw 'retained identity changed'}
        $remaining=Get-Remaining $DeadlineTicks;if($remaining -le 0){$category='Timeout';throw 'deadline'};$reserve=[Math]::Min(2000,[Math]::Max(250,[int][Math]::Ceiling(($TimeoutSeconds*1000)/10.0)));$engineDeadline=$DeadlineTicks-[int64]($reserve*[Diagnostics.Stopwatch]::Frequency/1000);if((Get-Remaining $engineDeadline) -le 0){$category='Timeout';throw 'deadline'}
        $engine=@($args)+@('--headless','--path',$project,'--log-file',$log); $line=(($engine|ForEach-Object{Quote-WindowsArgument $_}) -join ' ')
        $category='CleanupFailure';$r=[Gtr.Native]::Run($exeIdentity,$line,$projectIdentity,"$log.stdout","$log.stderr",$watch,$engineDeadline,$DeadlineTicks,$PollMilliseconds,$WorkerFault);$category='InvalidInput'
        $exit=[int]$r.ExitCode
        if(-not $r.Empty){$category='CleanupFailure';throw 'job did not empty'}
        if($r.TimedOut){$category='Timeout';throw 'engine deadline'}
        $capture=[string]$r.Stdout+[string]$r.Stderr
        if($capture -match '(?im)CrashHandlerException|Program crashed|signal\s+11|C\+\+ backtrace|SCRIPT ERROR|Parser Error|Parse Error|Unhandled exception|Invalid call|^ERROR:'){$category='FatalOutput';throw 'fatal output'}
        if($exit -ne 0){$category='ProcessFailure';throw 'engine nonzero'};$status='passed';$category='Success'
    } catch {
        [Console]::Error.WriteLine("worker failure: $($_.Exception.Message)")
        if($WorkerFault -in @('watcher-failure','watcher-ready-timeout')){$category='CleanupFailure'}
        if($category -eq 'InvalidInput' -and $_.Exception.Message -match 'ABI|snapshot|Process32|unverifiable|cleanup|identity|QueryInformationJobObject'){$category='CleanupFailure'}
        if($_.Exception.Message -match 'CreateProcess|JOB_LIST|ResumeThread|post-create|CreateJob|SetInformationJob'){$category='LaunchFailure'}
        if($_.Exception.Message -match 'deadline'){$category='Timeout'}
    } finally {
        if($watch){try{[Gtr.Native]::CloseSupervisorWatch($watch,$DeadlineTicks)}catch{$category='CleanupFailure'}};if($projectIdentity){try{[Gtr.Native]::CloseIdentity($projectIdentity)}catch{$category='CleanupFailure'}};if($exeIdentity){try{[Gtr.Native]::CloseIdentity($exeIdentity)}catch{$category='CleanupFailure'}};$clock.Stop(); [Console]::Out.WriteLine((New-Frame 'FINAL' $Nonce @{status=$status;category=$category;processExitCode=$exit;project=$project;logPath=$log;cleanedPids=@($cleaned);elapsedSeconds=[Math]::Round($clock.Elapsed.TotalSeconds,3)}));[Console]::Out.Flush()
    }
}

function Invoke-Supervisor {
    # S0: one QPC deadline is fixed before every validation/work step and is never renewed.
    $clock=[Diagnostics.Stopwatch]::StartNew();$budget=[Math]::Max(1,[long]$TimeoutSeconds*1000);$deadline=[Diagnostics.Stopwatch]::GetTimestamp()+[int64]($budget*[Diagnostics.Stopwatch]::Frequency/1000)
    $category='InvalidInput';$status='failed';$exit=$null;$project='';$log='';$cleaned=@();$mutex=$null;$worker=$null;$workerExitConfirmed=$false;$emergencyUsed=$false;$stdoutPump=$null;$stderrPump=$null;$hadReady=$false;$firstWorkerFrame='';$readyProject='';$cleanupCount=$null
    try {
        # S1: manual bounded validation is always converted to the public JSON result.
        $workerArguments=Test-PublicArguments
        $nonce=([Guid]::NewGuid().ToString('N')+[Guid]::NewGuid().ToString('N'));$self=[Diagnostics.Process]::GetCurrentProcess();$creation=$self.StartTime.ToUniversalTime().ToFileTimeUtc()
        $psi=New-Object Diagnostics.ProcessStartInfo;$psi.FileName=(Get-Process -Id $PID).Path;$psi.UseShellExecute=$false;$psi.RedirectStandardInput=$true;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true;$psi.CreateNoWindow=$true
        $forward=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$PSCommandPath,'-Worker','-GodotPath',$GodotPath,'-ProjectPath',$ProjectPath,'-TimeoutSeconds',$TimeoutSeconds,'-PollMilliseconds',$PollMilliseconds,'-Nonce',$nonce,'-SupervisorPid',$PID,'-SupervisorCreation',$creation,'-DeadlineTicks',$deadline)
        $argumentB64=[string]::Join(',',@($workerArguments|ForEach-Object{ConvertTo-B64Url $_}));if($argumentB64.Length -gt ($script:MaxInput*2)){throw 'worker argument transport exceeds cap'};$forward+=@('-WorkerArgumentB64',$argumentB64);if($LogFile){$forward+=@('-LogFile',$LogFile)};if($CleanupExisting){$forward+='-CleanupExisting'};if($WorkerFault){$forward+=@('-WorkerFault',$WorkerFault)}
        Initialize-ProtocolPump;$psi.Arguments=(($forward|ForEach-Object{Quote-WindowsArgument $_}) -join ' ');$worker=New-Object Diagnostics.Process;$worker.StartInfo=$psi;if(-not $worker.Start()){throw 'worker launch failure'};$stdoutPump=New-Object Gtr.ProtocolPump($worker.StandardOutput.BaseStream,$script:MaxFrame,$script:MaxDiagnostics);$stderrPump=New-Object Gtr.ProtocolPump($worker.StandardError.BaseStream,$script:MaxFrame,$script:MaxDiagnostics);$stdoutPump.Start();$stderrPump.Start()
        # S2: continuous bounded byte pumps drain both redirected streams before READY.
        while($stdoutPump.Count -lt 1 -and -not $stdoutPump.Complete -and (Get-Remaining $deadline) -gt 0){Start-Sleep -Milliseconds 5};if($stdoutPump.Failure){throw $stdoutPump.Failure};if($stdoutPump.Count -ne 1){throw 'worker protocol ready deadline'};$firstWorkerFrame=$stdoutPump.Frame(0);try{$ready=Read-Frame $firstWorkerFrame 'READY' $nonce;Test-ExactProperties $ready @('mutexKey','project') 'ready';if($ready.mutexKey -isnot [string] -or $ready.mutexKey -notmatch '^[0-9A-F]{64}$' -or [string]::IsNullOrWhiteSpace([string]$ready.project)){throw 'invalid ready contract'};$hadReady=$true}catch{throw "$($_.Exception.Message) worker=$($stderrPump.Text)"};$project=[string]$ready.project;$readyProject=$project
        if($WorkerFault -eq 'global-denied'){throw 'mutex global denied'};if($WorkerFault -eq 'global-abandoned'){throw 'mutex abandoned'}
        $created=$false;$mutex=New-Object Threading.Mutex($false,"Global\GodotTestRunner_v1_$($ready.mutexKey)",[ref]$created);try{if(-not $mutex.WaitOne(0)){throw 'mutex contention'}}catch [Threading.AbandonedMutexException]{throw 'mutex abandoned'}
        # S3: nonce-authenticated GO only after the one Global mutex is held.
        $goBytes=[Text.Encoding]::ASCII.GetBytes((New-Frame 'GO' $nonce @{action='go'})+"`n");$goStream=$worker.StandardInput.BaseStream;$goStream.Write($goBytes,0,$goBytes.Length);$goStream.Flush();$goStream.Close()
        # S4/S5: exactly one fixed emergency grace follows kill; no later wait/retry is permitted.
        $remain=Get-Remaining $deadline;if($remain -le 0 -or -not $worker.WaitForExit($remain)){$emergencyUsed=$true;$worker.Kill();$workerExitConfirmed=$worker.WaitForExit(1000);if(-not $workerExitConfirmed){$category='CleanupFailure';throw 'unconfirmed worker termination'};throw 'deadline worker'};$workerExitConfirmed=$true
        while((-not $stdoutPump.Complete -or -not $stderrPump.Complete) -and (Get-Remaining $deadline) -gt 0){Start-Sleep -Milliseconds 5};if($stdoutPump.Failure){throw $stdoutPump.Failure};if($stderrPump.Failure){throw $stderrPump.Failure};if(-not $stdoutPump.Complete -or -not $stderrPump.Complete){throw 'worker protocol pipe deadline'}
        # S6: READY [CLEANUP_BEGIN] FINAL is the complete authenticated protocol.
        $index=1;if($stdoutPump.Count -eq 3){$cleanupFrame=Read-Frame $stdoutPump.Frame(1) 'CLEANUP_BEGIN' $nonce;Test-ExactProperties $cleanupFrame @('count') 'cleanup';if($cleanupFrame.count -isnot [int] -or $cleanupFrame.count -lt 1){throw 'invalid cleanup contract'};$cleanupCount=$cleanupFrame.count;$index=2}elseif($stdoutPump.Count -ne 2){throw 'extra or missing worker protocol frame'};$final=Read-Frame $stdoutPump.Frame($index) 'FINAL' $nonce;[Console]::Error.Write($stderrPump.Text)
        $status=[string]$final.status;$category=[string]$final.category;$exit=$final.processExitCode;$project=[string]$final.project;$log=[string]$final.logPath;$cleaned=@();if($null -ne $final.cleanedPids){$cleaned=@($final.cleanedPids)}
        Test-ExactProperties $final @('status','category','processExitCode','project','logPath','cleanedPids','elapsedSeconds') 'final';if($status -notin @('passed','failed') -or -not $script:Codes.ContainsKey($category) -or $final.project -isnot [string] -or $final.logPath -isnot [string] -or $final.elapsedSeconds -isnot [ValueType] -or $final.elapsedSeconds -is [bool] -or $final.elapsedSeconds -lt 0 -or $project -cne $readyProject){throw 'invalid final contract'};if($null -ne $exit -and ($exit -isnot [ValueType] -or $exit -is [bool] -or $exit -lt 0 -or $exit -gt 4294967295)){throw 'invalid final exit'};foreach($cleanedPid in $cleaned){if($cleanedPid -isnot [ValueType] -or $cleanedPid -is [bool] -or $cleanedPid -le 0 -or $cleanedPid -gt 4294967295){throw 'invalid cleaned pid'}};if(@($cleaned|Sort-Object -Unique).Count -ne $cleaned.Count){throw 'duplicate cleaned pid'};if($null -ne $cleanupCount -and $cleaned.Count -gt $cleanupCount){throw 'inconsistent cleaned pid count'};if($category -eq 'Success' -and ($status -ne 'passed' -or $exit -ne 0 -or [string]::IsNullOrWhiteSpace($project) -or [string]::IsNullOrWhiteSpace($log))){throw 'inconsistent successful final'};if($category -ne 'Success' -and $status -ne 'failed'){throw 'inconsistent failed final'}
    } catch {
        [Console]::Error.WriteLine("supervisor failure: $($_.Exception.Message)")
        if($WorkerFault -in @('watcher-failure','watcher-ready-timeout')){$category='CleanupFailure'}elseif($_.Exception.Message -match 'mutex'){$category='LockContention'}elseif($_.Exception.Message -match 'unconfirmed worker'){$category='CleanupFailure'}elseif($hadReady -and $_.Exception.Message -match 'protocol|contract|worker ready|worker protocol|extra or missing'){ $category='LaunchFailure'}elseif(-not $hadReady -and $firstWorkerFrame -like 'GTR1 READY*'){$category='LaunchFailure'}elseif($_.Exception.Message -match 'deadline'){$category='Timeout'}elseif($_.Exception.Message -match 'worker launch'){$category='LaunchFailure'}elseif($category -notin @('CleanupFailure','PreexistingHeadlessProcess','FatalOutput','ProcessFailure','LaunchFailure')){$category='InvalidInput'}
    } finally {
        if($worker -and -not $worker.HasExited -and -not $emergencyUsed){$emergencyUsed=$true;try{$worker.Kill();$workerExitConfirmed=$worker.WaitForExit(1000)}catch{$workerExitConfirmed=$false};if(-not $workerExitConfirmed){$category='CleanupFailure'}}
        # An unconfirmed worker may still own descendants: abandon, never release, the mutex.
        if($mutex -and $workerExitConfirmed){try{$mutex.ReleaseMutex()}catch{};$mutex.Dispose()};$clock.Stop();$code=$script:Codes[$category];if($category -eq 'Success'){$status='passed';$code=0}else{$status='failed'};Write-Output (Write-Summary $status $category $exit $clock.Elapsed.TotalSeconds $project $log $cleaned);exit $code
    }
}

if($Worker){Invoke-Worker;exit $script:Codes.Success}else{Invoke-Supervisor}
