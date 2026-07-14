[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$GodotPath,
    [Parameter(Mandatory=$true)][string]$ProjectPath,
    [Alias('GodotArguments')][string[]]$GodotArgument,
    [string]$GodotArgumentJson,
    [ValidateRange(1,86400)][int]$TimeoutSeconds=120,
    [string]$LogFile,
    [switch]$CleanupExisting,
    [ValidateRange(25,5000)][int]$PollMilliseconds=100,
    # Private transport parameters.  They are deliberately not documented and cannot
    # grant any process or cleanup authority when supplied without -Worker.
    [switch]$Worker,[string]$Nonce,[int]$SupervisorPid,[long]$SupervisorCreation,[long]$DeadlineTicks,
    [string]$WorkerFault,[string]$WorkerArgumentB64,[switch]$AbiCheckOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$script:Codes=@{Success=0;ProcessFailure=1;Timeout=2;FatalOutput=3;LockContention=4;PreexistingHeadlessProcess=5;InvalidInput=6;CleanupFailure=7;LaunchFailure=8}
$script:MaxFrame=16384; $script:MaxInput=65536; $script:MaxCapture=262144

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
    if($p.Count -ne 5 -or $p[0] -cne 'GTR1' -or $p[1] -cne $ExpectedKind -or $p[2] -cne $ExpectedNonce){throw 'invalid protocol frame header'}
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
function Get-Remaining([Diagnostics.Stopwatch]$Clock,[long]$Budget) { [Math]::Max(0,[int][Math]::Floor($Budget-$Clock.ElapsedMilliseconds)) }

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
 public sealed class Result { public int ExitCode; public bool TimedOut; public bool Empty; public string Stdout; public string Stderr; }
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
  [DllImport("kernel32.dll",SetLastError=true)] static extern IntPtr CreateToolhelp32Snapshot(uint f,uint p);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool Process32FirstW(IntPtr s,ref PROCESSENTRY32W e);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool Process32NextW(IntPtr s,ref PROCESSENTRY32W e);
  [DllImport("kernel32.dll",SetLastError=true)] static extern IntPtr OpenProcess(uint a,bool i,uint p);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool CloseHandle(IntPtr h);
  [DllImport("kernel32.dll",SetLastError=true,CharSet=CharSet.Unicode)] static extern bool QueryFullProcessImageNameW(IntPtr h,uint f,StringBuilder b,ref int n);
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
  [DllImport("ntdll.dll")] static extern int NtQueryInformationProcess(IntPtr h,int c,IntPtr b,int n,out int r);
  [DllImport("shell32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern IntPtr CommandLineToArgvW(string x,out int n);
  [DllImport("kernel32.dll")] static extern IntPtr LocalFree(IntPtr p);
  static void Need(bool ok,string what){if(!ok)throw new Win32Exception(Marshal.GetLastWin32Error(),what);}
  public static void AssertAbi(){int p=IntPtr.Size,pe=Marshal.SizeOf(typeof(PROCESSENTRY32W)),bl=Marshal.SizeOf(typeof(JOBOBJECT_BASIC_LIMIT_INFORMATION)),io=Marshal.SizeOf(typeof(IO_COUNTERS)),ex=Marshal.SizeOf(typeof(JOBOBJECT_EXTENDED_LIMIT_INFORMATION)),us=Marshal.SizeOf(typeof(UNICODE_STRING)),si=Marshal.SizeOf(typeof(STARTUPINFO)),sx=Marshal.SizeOf(typeof(STARTUPINFOEX)),pi=Marshal.SizeOf(typeof(PROCESS_INFORMATION));if((p==8&&pe!=568)||(p==4&&pe!=556)||(p==8&&bl!=64)||(p==4&&bl!=48)||io!=48||(p==8&&ex!=144)||(p==4&&ex!=112)||(p==8&&us!=16)||(p==4&&us!=8)||(p==8&&si!=104)||(p==4&&si!=68)||(p==8&&sx!=112)||(p==4&&sx!=72)||(p==8&&pi!=24)||(p==4&&pi!=16))throw new InvalidOperationException(String.Format("native ABI assertion failed p={0} pe={1} bl={2} io={3} ex={4} us={5} si={6} sx={7} pi={8}",p,pe,bl,io,ex,us,si,sx,pi));}
  static string Image(IntPtr h){int n=32768;var b=new StringBuilder(n);return QueryFullProcessImageNameW(h,0,b,ref n)?Path.GetFullPath(b.ToString()):null;}
  static long Created(IntPtr h){long a,b,c,d;return GetProcessTimes(h,out a,out b,out c,out d)?a:0;}
  static string Cmd(IntPtr h){int n;NtQueryInformationProcess(h,60,IntPtr.Zero,0,out n);if(n<Marshal.SizeOf(typeof(UNICODE_STRING))||n>1048576)return null;IntPtr b=Marshal.AllocHGlobal(n);try{if(NtQueryInformationProcess(h,60,b,n,out n)!=0)return null;var u=(UNICODE_STRING)Marshal.PtrToStructure(b,typeof(UNICODE_STRING));if(u.Buffer==IntPtr.Zero||u.Length>u.MaximumLength||((u.Length&1)!=0)||u.Length>65534)return null;return Marshal.PtrToStringUni(u.Buffer,u.Length/2);}finally{Marshal.FreeHGlobal(b);}}
  static string[] Argv(string s){int n;IntPtr p=CommandLineToArgvW(s,out n);if(p==IntPtr.Zero)return null;try{var r=new string[n];for(int i=0;i<n;i++)r[i]=Marshal.PtrToStringUni(Marshal.ReadIntPtr(p,i*IntPtr.Size));return r;}finally{LocalFree(p);}}
  static bool SameProject(string cmd,string project){var a=Argv(cmd);if(a==null)return false;bool h=false;int paths=0;for(int i=1;i<a.Length;i++){if(a[i]=="--")break;if(a[i]=="--headless")h=true;else if(a[i].StartsWith("--headless="))return false;else if(a[i]=="--path"){if(++i>=a.Length||!Path.IsPathRooted(a[i]))return false;if(String.Equals(Path.GetFullPath(a[i]),project,StringComparison.OrdinalIgnoreCase))paths++;else return false;}else if(a[i].StartsWith("--path=")){string x=a[i].Substring(7);if(!Path.IsPathRooted(x)||String.IsNullOrEmpty(x))return false;if(String.Equals(Path.GetFullPath(x),project,StringComparison.OrdinalIgnoreCase))paths++;else return false;}}return h&&paths==1;}
  // W2/W3: Toolhelp is only a basename filter.  Each same-basename process has
  // a retained query/terminate handle and must have complete native identity.
  public static Existing[] Inventory(string exe,string project,string fault){var r=new List<Existing>();if(fault=="inventory-denied")throw new InvalidOperationException("unverifiable same-basename process");IntPtr s=CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS,0);if(s==INVALID)throw new Win32Exception(Marshal.GetLastWin32Error(),"snapshot");try{var e=new PROCESSENTRY32W();e.dwSize=(uint)Marshal.SizeOf(typeof(PROCESSENTRY32W));if(fault=="toolhelp-first")throw new Win32Exception(5,"Process32FirstW");if(!Process32FirstW(s,ref e))throw new Win32Exception(Marshal.GetLastWin32Error(),"Process32FirstW");while(true){if(String.Equals(e.exe,Path.GetFileName(exe),StringComparison.OrdinalIgnoreCase)){IntPtr h=OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION|PROCESS_TERMINATE,false,e.th32ProcessID);if(h==IntPtr.Zero)throw new InvalidOperationException("unverifiable same-basename process");string im=Image(h),cmd=Cmd(h);long cr=Created(h);if(im==null||cmd==null||cr==0){CloseHandle(h);throw new InvalidOperationException("unverifiable same-basename process");}if(String.Equals(im,exe,StringComparison.OrdinalIgnoreCase)&&SameProject(cmd,project))r.Add(new Existing{Pid=(int)e.th32ProcessID,Handle=h,Creation=cr});else CloseHandle(h);}if(fault=="toolhelp-next")throw new Win32Exception(5,"Process32NextW");e.dwSize=(uint)Marshal.SizeOf(typeof(PROCESSENTRY32W));if(Process32NextW(s,ref e))continue;int z=Marshal.GetLastWin32Error();if(z==18)break;throw new Win32Exception(z,"Process32NextW");}return r.ToArray();}catch{foreach(var x in r)CloseHandle(x.Handle);throw;}finally{CloseHandle(s);}}
  public static int[] Cleanup(Existing[] xs,string fault){var p=new List<int>();try{foreach(var x in xs){uint ec;if(fault=="retained-identity"||Created(x.Handle)!=x.Creation||!GetExitCodeProcess(x.Handle,out ec))throw new InvalidOperationException("retained identity changed");if(ec==259){Need(TerminateProcess(x.Handle,1),"TerminateProcess");p.Add(x.Pid);}}return p.ToArray();}finally{foreach(var x in xs)CloseHandle(x.Handle);}}
  static IntPtr Job(){IntPtr j=CreateJobObjectW(IntPtr.Zero,null);if(j==IntPtr.Zero)throw new Win32Exception(Marshal.GetLastWin32Error(),"CreateJobObject");var x=new JOBOBJECT_EXTENDED_LIMIT_INFORMATION();x.BasicLimitInformation.LimitFlags=JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;int n=Marshal.SizeOf(x);IntPtr b=Marshal.AllocHGlobal(n);try{Marshal.StructureToPtr(x,b,false);Need(SetInformationJobObject(j,JobObjectExtendedLimitInformation,b,(uint)n),"SetInformationJobObject");return j;}finally{Marshal.FreeHGlobal(b);}}
  static bool Empty(IntPtr j,string fault){if(fault=="query-failure"||fault=="cleanup-overrides")throw new Win32Exception(5,"QueryInformationJobObject");int n=Marshal.SizeOf(typeof(JOBOBJECT_BASIC_ACCOUNTING_INFORMATION));IntPtr b=Marshal.AllocHGlobal(n);try{Need(QueryInformationJobObject(j,JobObjectBasicAccountingInformation,b,(uint)n,IntPtr.Zero),"QueryInformationJobObject");return ((JOBOBJECT_BASIC_ACCOUNTING_INFORMATION)Marshal.PtrToStructure(b,typeof(JOBOBJECT_BASIC_ACCOUNTING_INFORMATION))).ActiveProcesses==0;}finally{Marshal.FreeHGlobal(b);}}
  static IntPtr Capture(string path){var sa=new SECURITY_ATTRIBUTES{nLength=Marshal.SizeOf(typeof(SECURITY_ATTRIBUTES)),bInheritHandle=true};IntPtr h=CreateFileW(path,0x40000000,3,ref sa,2,0x80,IntPtr.Zero);if(h==INVALID)throw new Win32Exception(Marshal.GetLastWin32Error(),"CreateFile capture");return h;}
  static void Watch(int pid,long creation,IntPtr job,long until){new Thread(()=>{IntPtr p=OpenProcess(SYNCHRONIZE|PROCESS_QUERY_LIMITED_INFORMATION,false,(uint)pid);if(p==IntPtr.Zero||Created(p)!=creation){TerminateJobObject(job,9);Environment.Exit(7);}try{int ms=(int)Math.Max(1,until-Stopwatch.GetTimestamp()*1000/Stopwatch.Frequency);if(WaitForSingleObject(p,(uint)ms)!=WAIT_TIMEOUT){TerminateJobObject(job,9);Environment.Exit(7);}}finally{CloseHandle(p);}}){IsBackground=true}.Start();}
  // W4-W7: there is intentionally no AssignProcessToJobObject path.  JOB_LIST
  // is supplied to CreateProcessW before resume; any failure closes/kills job.
  public static Result Run(string exe,string args,string cwd,string outp,string errp,int supervisor,long supCreation,long deadlineMs,int poll,string fault){AssertAbi();IntPtr j=IntPtr.Zero,attr=IntPtr.Zero,jobp=IntPtr.Zero,handles=IntPtr.Zero,oh=IntPtr.Zero,eh=IntPtr.Zero;PROCESS_INFORMATION pi=new PROCESS_INFORMATION();bool made=false;try{j=Job();Watch(supervisor,supCreation,j,deadlineMs);oh=Capture(outp);eh=Capture(errp);IntPtr size=IntPtr.Zero;InitializeProcThreadAttributeList(IntPtr.Zero,2,0,ref size);attr=Marshal.AllocHGlobal(size);Need(InitializeProcThreadAttributeList(attr,2,0,ref size),"InitializeProcThreadAttributeList");jobp=Marshal.AllocHGlobal(IntPtr.Size);Marshal.WriteIntPtr(jobp,j);if(fault=="job-attribute")throw new Win32Exception(5,"JOB_LIST");Need(UpdateProcThreadAttribute(attr,0,new IntPtr(PROC_THREAD_ATTRIBUTE_JOB_LIST),jobp,new IntPtr(IntPtr.Size),IntPtr.Zero,IntPtr.Zero),"JOB_LIST");handles=Marshal.AllocHGlobal(IntPtr.Size*2);Marshal.WriteIntPtr(handles,0,oh);Marshal.WriteIntPtr(handles,IntPtr.Size,eh);Need(UpdateProcThreadAttribute(attr,0,new IntPtr(PROC_THREAD_ATTRIBUTE_HANDLE_LIST),handles,new IntPtr(IntPtr.Size*2),IntPtr.Zero,IntPtr.Zero),"HANDLE_LIST");var si=new STARTUPINFOEX();si.StartupInfo.cb=(uint)Marshal.SizeOf(typeof(STARTUPINFOEX));si.StartupInfo.flags=0x100;si.StartupInfo.hStdOutput=oh;si.StartupInfo.hStdError=eh;si.AttributeList=attr;var command=new StringBuilder("\""+exe+"\" "+args);if(fault=="create-failure")throw new Win32Exception(5,"CreateProcessW JOB_LIST");Need(CreateProcessW(exe,command,IntPtr.Zero,IntPtr.Zero,true,CREATE_SUSPENDED|EXTENDED_STARTUPINFO_PRESENT,IntPtr.Zero,cwd,ref si,out pi),"CreateProcessW JOB_LIST");made=true;CloseHandle(oh);oh=IntPtr.Zero;CloseHandle(eh);eh=IntPtr.Zero;if(fault=="post-create-kill")throw new InvalidOperationException("post-create pre-resume failure");bool inJob;if(fault=="post-create-identity"||!IsProcessInJob(pi.hProcess,j,out inJob)||!inJob||!String.Equals(Image(pi.hProcess),exe,StringComparison.OrdinalIgnoreCase)||Created(pi.hProcess)==0)throw new InvalidOperationException("post-create identity/job verification failed");if(fault=="resume-failure")throw new Win32Exception(5,"ResumeThread");if(ResumeThread(pi.hThread)==uint.MaxValue)throw new Win32Exception(Marshal.GetLastWin32Error(),"ResumeThread");var result=new Result();while(true){long now=Stopwatch.GetTimestamp()*1000/Stopwatch.Frequency;if(now>=deadlineMs){result.TimedOut=true;break;}uint w=WaitForSingleObject(pi.hProcess,(uint)Math.Min(poll,Math.Max(1,deadlineMs-now)));if(w==WAIT_OBJECT_0&&Empty(j,fault)){uint code;Need(GetExitCodeProcess(pi.hProcess,out code),"GetExitCodeProcess");result.ExitCode=(int)code;result.Empty=true;break;}}if(!result.Empty){TerminateJobObject(j,2);long grace=Stopwatch.GetTimestamp()*1000/Stopwatch.Frequency+1000;while(!Empty(j,fault)&&Stopwatch.GetTimestamp()*1000/Stopwatch.Frequency<grace)Thread.Sleep(10);result.Empty=Empty(j,fault);}return result;}finally{bool cleanupBad=false;if(made&&j!=IntPtr.Zero){TerminateJobObject(j,2);long end=Stopwatch.GetTimestamp()*1000/Stopwatch.Frequency+1000;while(!Empty(j,"")&&Stopwatch.GetTimestamp()*1000/Stopwatch.Frequency<end)Thread.Sleep(10);cleanupBad=!Empty(j,"");}if(pi.hThread!=IntPtr.Zero)CloseHandle(pi.hThread);if(pi.hProcess!=IntPtr.Zero)CloseHandle(pi.hProcess);if(oh!=IntPtr.Zero)CloseHandle(oh);if(eh!=IntPtr.Zero)CloseHandle(eh);if(attr!=IntPtr.Zero){DeleteProcThreadAttributeList(attr);Marshal.FreeHGlobal(attr);}if(jobp!=IntPtr.Zero)Marshal.FreeHGlobal(jobp);if(handles!=IntPtr.Zero)Marshal.FreeHGlobal(handles);if(j!=IntPtr.Zero)CloseHandle(j);if(cleanupBad)throw new InvalidOperationException("job cleanup proof failed");}}
 }
}
'@
}

# W0-W8 worker: no supervisor code below performs native access, path resolution,
# inventory, engine launch, capture, or cleanup.
function Invoke-Worker {
    $clock=[Diagnostics.Stopwatch]::StartNew(); $budget=[Math]::Max(1,[int]($DeadlineTicks-[DateTime]::UtcNow.Ticks)/10000)
    $project='';$log='';$cleaned=@();$exit=$null;$category='InvalidInput';$status='failed'
    try {
        if($WorkerFault -eq 'partial'){[Console]::Out.Write('GTR1 READY ');return}
        if($WorkerFault -eq 'hang-before-ready'){Start-Sleep -Seconds ($TimeoutSeconds+2)}
        if([string]::IsNullOrWhiteSpace($Nonce) -or $Nonce -notmatch '^[0-9a-f]{64}$'){throw 'invalid worker nonce'}
        # W1: all canonical file/path work occurs after the worker is killable.
        if($GodotPath.Length -gt $script:MaxInput -or $ProjectPath.Length -gt $script:MaxInput -or $GodotPath.IndexOf([char]0)-ge 0 -or $ProjectPath.IndexOf([char]0)-ge 0){throw 'invalid input'}
        $exe=(Resolve-Path -LiteralPath $GodotPath -ErrorAction Stop).Path
        if(-not (Test-Path -LiteralPath $exe -PathType Leaf)){throw 'GodotPath is not a file'}
        $project=(Resolve-Path -LiteralPath $ProjectPath -ErrorAction Stop).Path
        if(-not (Test-Path -LiteralPath (Join-Path $project 'project.godot') -PathType Leaf)){throw 'project.godot missing'}
        if(-not $WorkerArgumentB64 -and ([string]::IsNullOrWhiteSpace($GodotArgumentJson)) -eq ($null -eq $GodotArgument -or @($GodotArgument).Count -eq 0)){throw 'provide exactly one argument form'}
        if($WorkerArgumentB64){$args=@($WorkerArgumentB64.Split(',')|ForEach-Object{ConvertFrom-B64Url $_})}elseif($GodotArgumentJson){$args=@(ConvertFrom-Json $GodotArgumentJson -ErrorAction Stop|ForEach-Object{[string]$_})}else{$args=@($GodotArgument)}
        foreach($a in $args){if($a.Length -gt $script:MaxInput -or $a.IndexOf([char]0)-ge 0 -or $a -ceq '--headless' -or $a -like '--headless=*' -or $a -ceq '--path' -or $a -like '--path=*' -or $a -ceq '--log-file' -or $a -like '--log-file=*'){throw 'reserved engine option'}}
        if([string]::IsNullOrWhiteSpace($LogFile)){$log=Join-Path ([IO.Path]::GetTempPath()) ('godot-test-'+[Guid]::NewGuid().ToString('N')+'.log')}else{$log=[IO.Path]::GetFullPath($LogFile)}
        Initialize-WorkerNative; [Gtr.Native]::AssertAbi()
        # W2: READY includes the worker-established canonical project identity key.
        $key=Get-Sha256 $project; [Console]::Out.WriteLine((New-Frame 'READY' $Nonce @{mutexKey=$key;project=$project}));[Console]::Out.Flush()
        $go=Read-Frame (Read-ProtocolStdinLine) 'GO' $Nonce; if($go.action -cne 'go'){throw 'missing GO'}
        if($WorkerFault -eq 'hang-after-go'){Start-Sleep -Seconds ($TimeoutSeconds+2)}
        if($AbiCheckOnly){$status='passed';$category='Success';return}
        if($WorkerFault -eq 'final-duplicate'){[Console]::Out.WriteLine((New-Frame 'FINAL' $Nonce @{category='LaunchFailure';status='failed'}));[Console]::Out.Flush()}
        $existing=@([Gtr.Native]::Inventory($exe,$project,$WorkerFault))
        if($existing.Count -and -not $CleanupExisting){$category='PreexistingHeadlessProcess';throw 'existing guarded process'}
        if($existing.Count){$cleaned=@([Gtr.Native]::Cleanup($existing,$WorkerFault));$again=@([Gtr.Native]::Inventory($exe,$project,''));if($again.Count){$category='CleanupFailure';throw 'cleanup verification failed'}}elseif($WorkerFault -eq 'retained-identity'){$category='CleanupFailure';throw 'retained identity changed'}
        $remaining=Get-Remaining $clock $budget;if($remaining -le 0){$category='Timeout';throw 'deadline'};$reserve=[Math]::Min(2000,[Math]::Max(250,[int][Math]::Ceiling(($TimeoutSeconds*1000)/10.0)));$engineRemaining=$remaining-$reserve;if($engineRemaining -le 0){$category='Timeout';throw 'deadline'}
        $engine=@($args)+@('--headless','--path',$project,'--log-file',$log); $line=(($engine|ForEach-Object{Quote-WindowsArgument $_}) -join ' ')
        $r=[Gtr.Native]::Run($exe,$line,$project,"$log.stdout","$log.stderr",$SupervisorPid,$SupervisorCreation,([Diagnostics.Stopwatch]::GetTimestamp()*1000/[Diagnostics.Stopwatch]::Frequency+$engineRemaining),$PollMilliseconds,$WorkerFault)
        $exit=[int]$r.ExitCode
        if(-not $r.Empty){$category='CleanupFailure';throw 'job did not empty'}
        if($r.TimedOut){$category='Timeout';throw 'engine deadline'}
        $capture='';foreach($p in @("$log.stdout","$log.stderr",$log)){if(Test-Path -LiteralPath $p){$i=Get-Item -LiteralPath $p;if($i.Length -gt $script:MaxCapture){$category='CleanupFailure';throw 'capture cap exceeded'};$capture+=Get-Content -LiteralPath $p -Raw}}
        if($capture -match '(?im)CrashHandlerException|Program crashed|signal\s+11|C\+\+ backtrace|SCRIPT ERROR|Parser Error|Parse Error|Unhandled exception|Invalid call|^ERROR:'){$category='FatalOutput';throw 'fatal output'}
        if($exit -ne 0){$category='ProcessFailure';throw 'engine nonzero'};$status='passed';$category='Success'
    } catch {
        [Console]::Error.WriteLine("worker failure: $($_.Exception.Message)")
        if($category -eq 'InvalidInput' -and $_.Exception.Message -match 'ABI|snapshot|Process32|unverifiable|cleanup|identity|QueryInformationJobObject'){$category='CleanupFailure'}
        if($_.Exception.Message -match 'CreateProcess|JOB_LIST|ResumeThread|post-create|CreateJob|SetInformationJob'){$category='LaunchFailure'}
        if($_.Exception.Message -match 'deadline'){$category='Timeout'}
    } finally {
        $clock.Stop(); [Console]::Out.WriteLine((New-Frame 'FINAL' $Nonce @{status=$status;category=$category;processExitCode=$exit;project=$project;logPath=$log;cleanedPids=@($cleaned);elapsedSeconds=[Math]::Round($clock.Elapsed.TotalSeconds,3)}));[Console]::Out.Flush()
    }
}

function Invoke-Supervisor {
    # S0: monotonic budget begins before every validation/work step.
    $clock=[Diagnostics.Stopwatch]::StartNew();$budget=[long]$TimeoutSeconds*1000;$category='InvalidInput';$status='failed';$exit=$null;$project='';$log='';$cleaned=@();$mutex=$null;$worker=$null
    try {
        # S1: syntax-only public validation.  The worker owns filesystem and native work.
        foreach($v in @($GodotPath,$ProjectPath,$GodotArgumentJson,$LogFile)){if($null -ne $v -and ($v.Length -gt $script:MaxInput -or $v.IndexOf([char]0)-ge 0)){throw 'invalid input'}}
        if(([string]::IsNullOrWhiteSpace($GodotArgumentJson)) -eq ($null -eq $GodotArgument -or @($GodotArgument).Count -eq 0)){throw 'provide exactly one argument form'}
        $nonce=([Guid]::NewGuid().ToString('N')+[Guid]::NewGuid().ToString('N'));$self=[Diagnostics.Process]::GetCurrentProcess();$creation=$self.StartTime.ToUniversalTime().ToFileTimeUtc();$deadline=[DateTime]::UtcNow.AddMilliseconds($budget).Ticks
        $psi=New-Object Diagnostics.ProcessStartInfo;$psi.FileName=(Get-Process -Id $PID).Path;$psi.UseShellExecute=$false;$psi.RedirectStandardInput=$true;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true;$psi.CreateNoWindow=$true
        $forward=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$PSCommandPath,'-Worker','-GodotPath',$GodotPath,'-ProjectPath',$ProjectPath,'-TimeoutSeconds',$TimeoutSeconds,'-PollMilliseconds',$PollMilliseconds,'-Nonce',$nonce,'-SupervisorPid',$PID,'-SupervisorCreation',$creation,'-DeadlineTicks',$deadline)
        if($GodotArgumentJson){$parsed=ConvertFrom-Json -InputObject $GodotArgumentJson -ErrorAction Stop;$workerArguments=@();foreach($item in $parsed){$workerArguments+=[string]$item}}else{$workerArguments=@($GodotArgument)}
        $argumentB64=[string]::Join(',',@($workerArguments|ForEach-Object{ConvertTo-B64Url $_}));$forward+=@('-WorkerArgumentB64',$argumentB64);if($LogFile){$forward+=@('-LogFile',$LogFile)};if($CleanupExisting){$forward+='-CleanupExisting'};if($WorkerFault){$forward+=@('-WorkerFault',$WorkerFault)};if($AbiCheckOnly){$forward+='-AbiCheckOnly'}
        $psi.Arguments=(($forward|ForEach-Object{Quote-WindowsArgument $_}) -join ' ');$worker=New-Object Diagnostics.Process;$worker.StartInfo=$psi;if(-not $worker.Start()){throw 'worker launch failure'};$stderrTask=$worker.StandardError.ReadToEndAsync()
        # S2 uses retained process plus asynchronous pipe reads.  No post-deadline drain occurs.
        $readyTask=$worker.StandardOutput.ReadLineAsync();$remain=Get-Remaining $clock $budget;if($remain -le 0 -or -not $readyTask.Wait($remain)){throw 'deadline worker ready'};$ready=Read-Frame $readyTask.Result 'READY' $nonce;$project=[string]$ready.project
        if($WorkerFault -eq 'global-denied'){throw 'mutex global denied'};if($WorkerFault -eq 'global-abandoned'){throw 'mutex abandoned'}
        $created=$false;$mutex=New-Object Threading.Mutex($false,"Global\GodotTestRunner_v1_$($ready.mutexKey)",[ref]$created);try{if(-not $mutex.WaitOne(0)){throw 'mutex contention'}}catch [Threading.AbandonedMutexException]{throw 'mutex abandoned'}
        # S3: nonce-authenticated GO only after the one Global mutex is held.
        $goBytes=[Text.Encoding]::ASCII.GetBytes((New-Frame 'GO' $nonce @{action='go'})+"`n");$goStream=$worker.StandardInput.BaseStream;$goStream.Write($goBytes,0,$goBytes.Length);$goStream.Flush();$goStream.Close()
        # S4/S5: wait retained worker handle; kill at deadline, then emergency grace only.
        $remain=Get-Remaining $clock $budget;if($remain -le 0 -or -not $worker.WaitForExit($remain)){$worker.Kill();if(-not $worker.WaitForExit(1000)){throw 'worker did not die'};throw 'deadline worker'}
        # S6: exactly one authenticated FINAL after confirmed exit; extra output fails closed.
        $final=Read-Frame ($worker.StandardOutput.ReadLine()) 'FINAL' $nonce;if($null -ne $worker.StandardOutput.ReadLine()){throw 'extra worker protocol frame'}
        if($stderrTask.Wait([Math]::Min(1000,(Get-Remaining $clock $budget)))){[Console]::Error.Write($stderrTask.Result)}
        $status=[string]$final.status;$category=[string]$final.category;$exit=$final.processExitCode;$project=[string]$final.project;$log=[string]$final.logPath;$cleaned=@($final.cleanedPids)
        if(-not $script:Codes.ContainsKey($category)){throw 'invalid final category'}
    } catch {
        if($_.Exception.Message -match 'mutex'){$category='LockContention'}elseif($_.Exception.Message -match 'deadline'){$category='Timeout'}elseif($_.Exception.Message -match 'worker launch'){$category='LaunchFailure'}elseif($category -notin @('CleanupFailure','PreexistingHeadlessProcess','FatalOutput','ProcessFailure','LaunchFailure')){$category='InvalidInput'}
    } finally {
        if($worker -and -not $worker.HasExited){try{$worker.Kill();$null=$worker.WaitForExit(1000)}catch{}}
        if($stderrTask -and $stderrTask.Wait(100)){[Console]::Error.Write($stderrTask.Result)}
        # Mutex release is intentionally after confirmed worker exit.
        if($mutex){try{$mutex.ReleaseMutex()}catch{};$mutex.Dispose()};$clock.Stop();$code=$script:Codes[$category];if($category -eq 'Success'){$status='passed';$code=0}else{$status='failed'};Write-Output (Write-Summary $status $category $exit $clock.Elapsed.TotalSeconds $project $log $cleaned);exit $code
    }
}

if($Worker){Invoke-Worker;exit $script:Codes.Success}else{Invoke-Supervisor}
