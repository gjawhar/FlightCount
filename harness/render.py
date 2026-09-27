"""Renders every Flight Counter 2 layout/state to harness/out/*.svg + index.html.

    python3 harness/render.py
    (serve harness/out over http to view; the Browser pane can't screenshot file://)
"""
import os
import sys

import lupa

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "harness", "out")
os.makedirs(OUT, exist_ok=True)
os.chdir(os.path.join(ROOT, "FlightCount2"))
lua = lupa.LuaRuntime(unpack_returned_tuples=True)
src = open(os.path.join(ROOT, "harness", "render.lua"), encoding="utf-8").read()
try:
    lua.eval('function(s, out) return assert(load(s, "render.lua"))(out) end')(src, OUT)
except lupa.LuaError as e:
    print(e)
    sys.exit(1)
