#!/usr/bin/env python3
"""Expose a small, redacted set of compiler failures as public check annotations."""
import re
import sys

path, title = sys.argv[1:3]
patterns = re.compile(r"(?i)(error:|failed|assertion|xctassert)")
count = 0
with open(path, encoding="utf-8", errors="replace") as log:
    for line in log:
        line = line.strip()
        if not line or not patterns.search(line):
            continue
        safe = line.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
        print(f"::error title={title}::{safe}", flush=True)
        count += 1
        if count == 6:
            break
if count == 0:
    print(f"::error title={title}::No compiler or test failure line found; inspect the step output.", flush=True)
