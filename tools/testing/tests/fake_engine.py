"""Build the dedicated native fake engine used by the guarded-runner tests."""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path


SOURCE = r'''
using System;
using System.Diagnostics;
using System.IO;
using System.Threading;
public static class FakeGodot {
  static string Value(string[] a,string name,string fallback) { for(int i=0;i+1<a.Length;i++)if(a[i]==name)return a[i+1];return fallback; }
  static bool Has(string[] a,string name) { foreach(string x in a)if(x==name)return true;return false; }
  public static int Main(string[] args) {
    Console.WriteLine("ROOT_PID="+Process.GetCurrentProcess().Id);
    string mode=Value(args,"--mode","success"); double seconds=Double.Parse(Value(args,"--duration","30"),System.Globalization.CultureInfo.InvariantCulture);
    if(Has(args,"--child")){if(Has(args,"--grandchild")){var g=Process.Start(new ProcessStartInfo(Environment.GetEnvironmentVariable("COMSPEC"),"/d /c ping 127.0.0.1 -n 30 >nul"){UseShellExecute=false});Console.WriteLine("GRANDCHILD_PID="+g.Id);}Thread.Sleep(TimeSpan.FromSeconds(seconds));return 0;}
    if(Has(args,"--spawn-child")){
      string exe=Process.GetCurrentProcess().MainModule.FileName;
      var p=Process.Start(new ProcessStartInfo(exe,"--child --duration "+seconds.ToString(System.Globalization.CultureInfo.InvariantCulture)){UseShellExecute=false});
      Console.WriteLine("CHILD_PID="+p.Id);
    }
    if(Has(args,"--spawn-grandchild")){
      string exe=Process.GetCurrentProcess().MainModule.FileName;
      Process.Start(new ProcessStartInfo(exe,"--child --grandchild --duration "+seconds.ToString(System.Globalization.CultureInfo.InvariantCulture)){UseShellExecute=false});
    }
    if(mode=="sleep")Thread.Sleep(TimeSpan.FromSeconds(seconds));
    if(mode=="fatal"||mode=="fatal-nonzero")Console.WriteLine("Program crashed: fake marker");
    if(mode=="parser")Console.Error.WriteLine("Parser Error: fake marker");
    if(mode=="capture-overflow")Console.WriteLine(new string('X',262145));
    string log=Value(args,"--log-file",null);if(log!=null)File.WriteAllText(log,"fake log\n");
    return mode=="nonzero"||mode=="fatal-nonzero"?17:0;
  }
}
'''


def build(target: Path) -> None:
    candidates = [
        Path(r"C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"),
        Path(r"C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe"),
    ]
    compiler = next((path for path in candidates if path.is_file()), None)
    if compiler is None:
        raise RuntimeError("required C# compiler is unavailable")
    source = target.with_suffix(".cs")
    source.write_text(SOURCE, encoding="utf-8")
    try:
        subprocess.run(
            [str(compiler), "/nologo", "/target:exe", f"/out:{target}", str(source)],
            check=True,
            capture_output=True,
            text=True,
        )
    finally:
        source.unlink(missing_ok=True)


if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[1] != "--build":
        raise SystemExit("usage: fake_engine.py --build TARGET.exe")
    build(Path(sys.argv[2]).resolve())
