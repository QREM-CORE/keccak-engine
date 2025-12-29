#!/usr/bin/env python3
import os
import subprocess
import re
import sys

# --- CONFIGURATION ---
MAKEFILE_TARGET = "keccak_core_heavy_tb"
VCD_DIR = "failures"
LOG_FILE = "regression.log"

# 1. Determine the Project Root
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)

def run_simulation(test_id=None):
    cmd = ["make", f"run_{MAKEFILE_TARGET}"]

    if test_id is not None:
        cmd = ["make", "run_heavy_fail", f"TEST_ID={test_id}"]

    result = subprocess.run(
        cmd,
        cwd=PROJECT_ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True
    )
    return result.stdout

def main():
    fail_dir_abs = os.path.join(PROJECT_ROOT, VCD_DIR)
    if not os.path.exists(fail_dir_abs):
        os.makedirs(fail_dir_abs)

    print(f"[-] Starting Full Regression (No Waves)...")
    log = run_simulation(test_id=None)

    # Save Log
    log_path = os.path.join(PROJECT_ROOT, LOG_FILE)
    with open(log_path, "w") as f:
        f.write(log)
    print(f"[-] Full simulation log saved to: {LOG_FILE}")

    # --- UPDATED REGEX ---
    # Captures ID from "Test_18_SHAKE" OR "ID:18"
    # Logic: Look for "FAIL" or "FATAL", then grab digits after "Test_" or "ID:"
    fail_pattern = re.compile(r"(?:FAIL|FATAL).*?(?:Test_|ID:)(\d+)")
    # ---------------------

    failed_ids = set()
    for line in log.splitlines():
        match = fail_pattern.search(line)
        if match:
            fid = int(match.group(1))
            failed_ids.add(fid)
            # Optional: Print found failure to console immediately
            # print(f"    Found Failure: Vector ID {fid}")

    if not failed_ids:
        print("[+] All tests passed! No VCDs generated.")
        for line in log.splitlines():
            if "Loaded" in line and "vectors" in line:
                print(f"    Verified: {line.strip()}")
        sys.exit(0)

    print(f"[-] {len(failed_ids)} failures detected. Generating VCDs...")

    for fid in failed_ids:
        print(f"    ... Re-simulating ID {fid} ...")
        run_simulation(test_id=fid)

        src_vcd = os.path.join(PROJECT_ROOT, f"{MAKEFILE_TARGET}.vcd")
        dst_vcd = os.path.join(fail_dir_abs, f"fail_id_{fid}.vcd")

        if os.path.exists(src_vcd):
            os.replace(src_vcd, dst_vcd)
            print(f"    Saved wave: {dst_vcd}")
        else:
            print(f"    Error: VCD not generated for ID {fid}")

if __name__ == "__main__":
    main()
