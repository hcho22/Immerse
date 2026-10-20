#!/usr/bin/env python3
"""Experiment-only: samples the host and the simulators while a CI part runs, to find what stalls a fresh simulator.

usage: sampler.py <outdir> [<simulator udid> ...]
Writes top.log (top every 2 s, stamped), vm.log (vm_stat and swap, 2 s), probe-<udid>.log (the time a trivial
process takes to spawn in the simulator, every 2 s) and ps.log (processes of the simulators and the build with their
CPU time, every 5 s). Stops on SIGTERM."""
import os, signal, subprocess, sys, threading, time

out = sys.argv[1]
udids = sys.argv[2:]
os.makedirs(out, exist_ok=True)
stop = threading.Event()
signal.signal(signal.SIGTERM, lambda *a: stop.set())
signal.signal(signal.SIGINT, lambda *a: stop.set())

def top():
    with open(f"{out}/top.log", "w") as f:
        p = subprocess.Popen(["top", "-l", "0", "-s", "2", "-n", "40", "-o", "cpu", "-stats", "pid,command,cpu,rsize,state"],
                             stdout=subprocess.PIPE, text=True, errors="replace")
        for line in p.stdout:
            f.write("%.2f %s" % (time.time(), line)); f.flush()
            if stop.is_set(): break
        p.terminate()

def vm():
    with open(f"{out}/vm.log", "w") as f:
        while not stop.is_set():
            t = time.time()
            r = subprocess.run(["vm_stat"], capture_output=True, text=True).stdout
            s = subprocess.run(["sysctl", "-n", "vm.swapusage", "kern.memorystatus_vm_pressure_level"],
                               capture_output=True, text=True).stdout.replace("\n", " | ")
            keep = [l.split(":")[0].replace("Pages ", "").replace('"', "") + "=" + l.split(":")[1].strip().rstrip(".")
                    for l in r.splitlines()[1:] if l.split(":")[0].strip('"') in
                    ("Pages free", "Pages active", "Pages inactive", "Pages wired down", "Pages occupied by compressor",
                     "Pageins", "Pageouts", "Swapins", "Swapouts", "Compressions", "Decompressions", "File-backed pages")]
            f.write("%.2f %s swap: %s\n" % (t, " ".join(keep), s)); f.flush()
            stop.wait(2)

def probe(udid):
    with open(f"{out}/probe-{udid}.log", "w") as f:
        while not stop.is_set():
            t = time.time()
            try:
                r = subprocess.run(["xcrun", "simctl", "spawn", udid, "/usr/bin/true"], capture_output=True, text=True, timeout=120)
                rc = r.returncode; err = (r.stderr or "").strip().replace("\n", " ")[:60]
            except subprocess.TimeoutExpired:
                rc = -1; err = "timeout"
            f.write("%.2f %.2f rc=%s %s\n" % (t, time.time() - t, rc, err)); f.flush()
            stop.wait(2)

def ps():
    pat = ("CoreSimulator", "launchd_sim", "xcodebuild", "swift-frontend", "swift-driver", "clang", "SWBBuildService",
           "XCTest", "xctest", "ld ", "ibtool", "actool", "simctl")
    with open(f"{out}/ps.log", "w") as f:
        while not stop.is_set():
            t = time.time()
            r = subprocess.run(["ps", "-Ao", "pid,ppid,time,rss,state,args"], capture_output=True, text=True, errors="replace").stdout
            f.write("== %.2f\n" % t)
            for l in r.splitlines()[1:]:
                if any(p in l for p in pat) and "sampler.py" not in l and " ps -Ao" not in l:
                    f.write(l[:240] + "\n")
            f.flush()
            stop.wait(5)

threads = [threading.Thread(target=top), threading.Thread(target=vm), threading.Thread(target=ps)]
threads += [threading.Thread(target=probe, args=(u,)) for u in udids]
for t in threads: t.start()
while not stop.is_set(): stop.wait(1)
for t in threads: t.join(timeout=5)
