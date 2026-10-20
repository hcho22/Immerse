#!/usr/bin/env python3
"""Experiment-only: how a fresh simulator settles on a CI runner.
usage: settle.py <udid> --minutes N [--apsd-off] [--build] [--out DIR]
Boots the simulator as validation does, optionally builds the app meanwhile, then every 15 s times the same few
simulator operations for N minutes and prints one line each."""
import argparse, os, plistlib, subprocess, sys, time

ap = argparse.ArgumentParser()
ap.add_argument("udid"); ap.add_argument("--minutes", type=float, default=20)
ap.add_argument("--apsd-off", action="store_true"); ap.add_argument("--build", action="store_true")
ap.add_argument("--out", default="DerivedData/probe")
a = ap.parse_args()
os.makedirs(a.out, exist_ok=True)
T0 = time.time()
def say(*x): print("%7.1f" % (time.time() - T0), *x, flush=True)
def sh(*cmd, timeout=300):
    t = time.time()
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    return time.time() - t, r.returncode, (r.stdout + r.stderr).strip()[:120]

sampler = subprocess.Popen([sys.executable, os.path.join(os.path.dirname(__file__), "light_sampler.py"), a.out])
say("host", subprocess.run(["sysctl", "-n", "hw.ncpu", "hw.memsize"], capture_output=True, text=True).stdout.replace("\n", " "))
if a.apsd_off:
    d = "/var/tmp/com.apple.CoreSimulator.SimDevice." + a.udid
    os.makedirs(d, mode=0o700, exist_ok=True)
    with open(d + "/disabled.plist", "wb") as f: plistlib.dump({"com.apple.apsd": True}, f)
    say("apsd disabled before the first boot")
t = time.time()
r = subprocess.run(["sh", "Scripts/quiet-simulator.sh", a.udid], capture_output=True, text=True)
say("booted by the quiet script in %.0f s" % (time.time() - t), r.stdout.strip()[:100])
sh("xcrun", "simctl", "ui", a.udid, "appearance", "light"); sh("xcrun", "simctl", "ui", a.udid, "content_size", "large")
t_boot = time.time() - T0
build = None
if a.build:
    build = subprocess.Popen(["xcodebuild", "-quiet", "-project", "App/Immerse/Immerse.xcodeproj", "-scheme", "Immerse", "-derivedDataPath", "DerivedData/ValidationSimulator",
                              "-destination", "platform=iOS Simulator,id=" + a.udid, "CODE_SIGNING_ALLOWED=NO", "build-for-testing"],
                             stdout=open(a.out + "/build.out", "w"), stderr=subprocess.STDOUT)
    say("build started")
built = None
n = 0
end = time.time() + a.minutes * 60
while time.time() < end:
    n += 1
    if build is not None and built is None and build.poll() is not None:
        built = time.time() - T0; say("build finished with", build.returncode)
    t_spawn = sh("xcrun", "simctl", "spawn", a.udid, "/usr/bin/true")[0]
    t_launch, rc, msg = sh("xcrun", "simctl", "launch", a.udid, "com.apple.Preferences")
    t_term = sh("xcrun", "simctl", "terminate", a.udid, "com.apple.Preferences")[0]
    t_shot = sh("xcrun", "simctl", "io", a.udid, "screenshot", "/dev/null")[0]
    load = os.getloadavg()[0]
    say("iter %3d  spawn %5.2f  launch %5.2f (rc %d)  terminate %5.2f  screenshot %5.2f  load %.1f %s" % (n, t_spawn, t_launch, rc, t_term, t_shot, load, "" if rc == 0 else msg))
    time.sleep(8)
say("done; boot finished at %.0f s" % t_boot)
sampler.terminate()
