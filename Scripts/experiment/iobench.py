#!/usr/bin/env python3
"""Experiment-only: how fast the runner's disk reads cold data, for the simulator runtime's disk image and for Xcode.
usage: iobench.py   (prints one line per measurement, stamped)"""
import fcntl, json, os, random, subprocess, sys, time

def say(*a): print("%.2f" % time.time(), *a, flush=True)

def runtime_image():
    try:
        out = subprocess.run(["xcrun", "simctl", "runtime", "list", "-j"], capture_output=True, text=True, timeout=60).stdout
        for v in json.loads(out).values():
            if v.get("build") == "23F77" and v.get("platformIdentifier", "").endswith("iphonesimulator"):
                return v["path"]
    except Exception as e:
        say("runtime list failed", e)

def bench(label, path, rng):
    try:
        fd = os.open(path, os.O_RDONLY)
    except OSError as e:
        say(label, "open failed", e); return
    try:
        fcntl.fcntl(fd, 48, 1)  # F_NOCACHE
    except OSError:
        pass
    size = os.fstat(fd).st_size
    say(label, "size_MB", size // 2**20)
    for rnd in (1, 2):
        offs = [rng.randrange(0, max(1, size - 2**20)) // 16384 * 16384 for _ in range(64)] if rnd == 1 else offs
        lats = []
        for o in offs:
            t = time.time(); os.pread(fd, 16384, o); lats.append(time.time() - t)
        lats.sort()
        say(label, "random16K pass", rnd, "p50_ms %.1f p90_ms %.1f max_ms %.1f total_s %.2f" % (lats[32] * 1e3, lats[57] * 1e3, lats[-1] * 1e3, sum(lats)))
    start = rng.randrange(0, max(1, size - 2**29)) // 2**20 * 2**20
    t = time.time(); got = 0
    while got < 2**29:
        b = os.pread(fd, 8 * 2**20, start + got)
        if not b: break
        got += len(b)
    dt = time.time() - t
    say(label, "sequential 512MB: %.1f MB/s (%.1f s)" % (got / 2**20 / dt, dt))
    os.close(fd)

rng = random.Random(7)
say("host", subprocess.run(["sysctl", "-n", "hw.ncpu", "hw.memsize"], capture_output=True, text=True).stdout.replace("\n", " "))
img = runtime_image()
say("runtime image", img)
if img: bench("runtime image", img, rng)
xc = subprocess.run(["xcrun", "--find", "swift-frontend"], capture_output=True, text=True).stdout.strip()
if xc: bench("swift-frontend", xc, rng)
