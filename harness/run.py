"""Runs harness/test.lua against FlightCount2/core.lua with a real Lua (lupa).

    pip3 install lupa
    python3 harness/run.py
"""
import os
import sys

import lupa

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.join(ROOT, "FlightCount2"))
lua = lupa.LuaRuntime(unpack_returned_tuples=True)
test = open(os.path.join(ROOT, "harness", "test.lua"), encoding="utf-8").read()
try:
    lua.execute(test)
except lupa.LuaError as e:
    print(e)
    sys.exit(1)
