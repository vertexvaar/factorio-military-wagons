"""In-game tests with a real player (opens a Factorio window for a few seconds).

Usage: python tests/ingame.py
"""
import os
import subprocess
import sys
import time

import run

HARNESS = "turret-wagon-ingame"


def main(timeout=180):
    failed = False
    for wagon in run.WAGONS:
        print("==", wagon)
        failed = not play(wagon, timeout) or failed
    if failed:
        sys.exit(1)


def play(wagon, timeout):
    """Runs the in-game tests for one wagon. Returns True if all passed."""
    run.HARNESS = HARNESS
    run.prepare(True, wagon)
    save = os.path.join(run.ENV, "game.zip")
    created = run.run(run.DEFAULT_EXE, "--create", save)
    if not os.path.exists(save):
        print(created.stdout[-3000:])
        print("map creation failed")
        return False
    cmd = [run.DEFAULT_EXE, "--config", os.path.join(run.ENV, "config", "config.ini"),
           "--mod-directory", os.path.join(run.ENV, "mods"), "--disable-audio", "--load-game", save]
    env = dict(os.environ, SteamAppId="427520", SteamGameId="427520")
    game = subprocess.Popen(cmd, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    report = os.path.join(run.ENV, "write", "script-output", "wagon-ingame", "report.txt")
    try:
        for _ in range(timeout * 2):
            time.sleep(0.5)
            if os.path.exists(report) and "WAGONTEST DONE" in open(report).read():
                break
            if game.poll() is not None:
                break
        time.sleep(1)
    finally:
        game.kill()
        game.wait(timeout=30)
    log = os.path.join(run.ENV, "write", "factorio-current.log")
    if os.path.exists(log):
        errors = [l for l in open(log, errors="replace").read().splitlines() if "Error" in l and "Steam" not in l]
        if errors:
            print("\n".join(errors)[-3000:])
    text = open(report).read() if os.path.exists(report) else ""
    print(text or "no report")
    return "WAGONTEST DONE" in text and "WAGONTEST FAIL" not in text


if __name__ == "__main__":
    main()
