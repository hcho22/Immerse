#!/usr/bin/env python3
"""Experiment-only, light: CPU and memory of the host and the simulator's processes, every 5 s.
usage: light_sampler.py <outdir>   (stops on SIGTERM; never hangs)"""
import os, signal, subprocess, sys, threading, time

out = sys.argv[1]
os.makedirs(out, exist_ok=True)
stop = threading.Event()
signal.signal(signal.SIGTERM, lambda *a: stop.set())
signal.signal(signal.SIGINT, lambda *a: stop.set())

topproc = []
def top():
    with open(f"{out}/top.log", "w") as f:
        p = subprocess.Popen(["top", "-l", "0", "-s", "5", "-n", "25", "-o", "cpu", "-stats", "pid,command,cpu,rsize,state"],
                             stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, errors="replace")
        topproc.append(p)
        for line in p.stdout:
            f.write("%.2f %s" % (time.time(), line)); f.flush()

def vm():
    with open(f"{out}/vm.log", "w") as f:
        while not stop.wait(5):
            r = subprocess.run(["vm_stat"], capture_output=True, text=True).stdout
            s = subprocess.run(["sysctl", "-n", "vm.swapusage", "kern.memorystatus_vm_pressure_level"], capture_output=True, text=True).stdout.replace("\n", " | ")
            keep = [l.split(":")[0].replace("Pages ", "") + "=" + l.split(":")[1].strip().rstrip(".") for l in r.splitlines()[1:]
                    if l.split(":")[0].strip('"') in ("Pages free", "Pages occupied by compressor", "Pageins", "Pageouts", "Swapins", "Swapouts")]
            f.write("%.2f %s swap: %s\n" % (time.time(), " ".join(keep), s)); f.flush()

def ps():
    pat = ("CoreSimulator", "launchd_sim", "diskimages", "xcodebuild", "swift-frontend", "swift-driver", "clang", "SWBBuildService", "XCBBuildService")
    with open(f"{out}/ps.log", "w") as f:
        while not stop.wait(5):
            r = subprocess.run(["ps", "-Ao", "pid,ppid,time,rss,state,args"], capture_output=True, text=True, errors="replace").stdout
            f.write("== %.2f\n" % time.time())
            for l in r.splitlines()[1:]:
                if any(p in l for p in pat) and "light_sampler" not in l and " ps -Ao" not in l:
                    f.write(l[:200] + "\n")
            f.flush()

for fn in (top, vm, ps):
    threading.Thread(target=fn, daemon=True).start()
while not stop.wait(1): pass
for p in topproc: p.kill()
os._exit(0)
