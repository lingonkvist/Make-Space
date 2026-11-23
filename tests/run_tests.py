#!/usr/bin/env python3
"""Run the MakeSpace Lua tests via lupa (Lua 5.1 from Python).

    python3 -I tests/run_tests.py            all specs
    python3 -I tests/run_tests.py verdict    only specs whose name contains "verdict"

A spec that cannot load counts as a failure.
"""

import os
import sys
import time
from pathlib import Path

try:
    from lupa.lua51 import LuaRuntime
except ImportError:
    from lupa import LuaRuntime


def main(filters):
    project_root = Path(__file__).resolve().parent.parent
    os.chdir(project_root)

    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute((project_root / "tests" / "mini_test.lua").read_text())

    specs = sorted(project_root.glob("tests/*_spec.lua"))
    if filters:
        specs = [s for s in specs if any(f in s.name for f in filters)]
        if not specs:
            print("No spec matches", " ".join(filters))
            return 1

    load_errors = 0
    for spec in specs:
        lua.globals().mini_test_begin(spec.name)
        started = time.perf_counter()
        passed_before, failed_before = lua.globals().mini_test_counts()
        try:
            lua.execute(spec.read_text())
        except Exception as e:
            load_errors += 1
            print(f"  ERROR loading {spec.name}: {e}")
        passed, failed = lua.globals().mini_test_counts()
        print(f"{spec.name}: {passed - passed_before + failed - failed_before} tests, "
              f"{time.perf_counter() - started:.1f}s")

    failed = lua.eval("mini_test_report()")
    return 1 if (failed and failed > 0) or load_errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
