"""Runs the artillery parking probe (tests/artillery-park-probe) and prints its PARKPROBE lines."""
import os

import run

run.HARNESS = "artillery-park-probe"
run.prepare(True, run.WAGONS[0])
save = os.path.join(run.ENV, "probe.zip")
run.run(run.DEFAULT_EXE, "--create", save)
result = run.run(run.DEFAULT_EXE, "--benchmark", save, "--benchmark-ticks", "700", "--benchmark-runs", "1")
log = open(os.path.join(run.ENV, "write", "factorio-current.log"), encoding="utf-8", errors="replace").read()
print("\n".join(l for l in log.splitlines() if "PARKPROBE" in l or "Error" in l))
