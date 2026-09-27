-- Flight Counter 2 harness: runs the REAL core.lua against a fake file
-- system (with injectable glitches), a fake model, fake switch and a fake
-- clock. Run with: python3 harness/run.py

local failures, checks = 0, 0
local function check(label, cond, detail)
  checks = checks + 1
  if cond then print("OK   " .. label)
  else failures = failures + 1; print("FAIL " .. label .. (detail and (" -- " .. tostring(detail)) or "")) end
end

-- ---------------------------------------------------------------- fake world

local realDate = os.date
local BASE = os.time({ year = 2026, month = 9, day = 26, hour = 12, min = 0, sec = 0 })
local clock = BASE
local function tick(s) clock = clock + s end

local FS, DIRS = {}, {}
local glitch = {}           -- pattern -> { mode = "open"|"short"|"append"|"stat", left = n }

local function dirOf(p) return p:match("^(.*)/[^/]*$") end
local function glitchFor(p, mode)
  for pat, g in pairs(glitch) do
    if g.mode == mode and p:find(pat, 1, true) and g.left > 0 then g.left = g.left - 1 return true end
  end
  return false
end

local function handle(p, mode)
  local buf = (mode == "w") and "" or (FS[p] or "")
  local pos = 1
  local short = (mode == "r") and glitchFor(p, "short")
  local h = {}
  function h:write(v) buf = buf .. tostring(v) end
  function h:read(n)
    if type(n) ~= "number" then error("bad argument #1 to 'read'") end
    local limit = short and math.floor(#buf / 2) or #buf
    if pos > limit then return nil end
    local chunk = string.sub(buf, pos, math.min(limit, pos + n - 1))
    pos = pos + #chunk
    return chunk
  end
  function h:close() if mode ~= "r" then FS[p] = buf end end
  return h
end

io.open = function(p, mode)
  mode = mode or "r"
  if mode == "r" then
    if glitchFor(p, "open") then return nil, "I/O error" end
    if FS[p] == nil then return nil, p .. ": No such file or directory" end
    return handle(p, "r")
  end
  if mode == "a" and glitchFor(p, "append") then return nil, "I/O error" end
  if not DIRS[dirOf(p)] then return nil, p .. ": No such file or directory" end
  return handle(p, mode)
end
os.stat = function(p)
  if glitchFor(p, "stat") then return nil, "I/O error" end
  if FS[p] then return { mode = 0, size = #FS[p] } end
  if DIRS[p] or DIRS[(p:gsub("/$", ""))] then return { mode = 16, size = 4096 } end
  return nil, p .. ": No such file or directory"
end
os.mkdir = function(p)
  if DIRS[p] then return nil, "File exists" end
  DIRS[p] = true
  return true
end
os.remove = function(p) FS[p] = nil return true end
os.rename = function(a, b)
  if FS[a] == nil then return nil, "missing" end
  FS[b] = FS[a]; FS[a] = nil
  return true
end
local realTime = os.time
os.time = function(t) if t then return realTime(t) end return clock end

local MODEL = { name = "Extra 330SC", path = "extra 330sc.bin", ids = { 0, 1 } }
model = {
  name = function() return MODEL.name end,
  path = function() return MODEL.path end,
  id = function() return MODEL.ids end,
}
local function putModelFile(file) FS["/models/" .. file] = "FRSK" end
local function dropModelFile(file) FS["/models/" .. file] = nil end

local SW = { on = false }
local switch = { state = function() return SW.on end }

local function reset()
  FS, DIRS, glitch = {}, {}, {}
  DIRS["SCRIPTS:"] = true
  DIRS["/models"] = true
  DIRS["SCRIPTS:/FlightCount/Files"] = true
  clock = BASE
  MODEL.name, MODEL.path, MODEL.ids = "Extra 330SC", "extra 330sc.bin", { 0, 1 }
  putModelFile(MODEL.path)
  SW.on = false
end

local function loadCore()
  local chunk = assert(loadfile("core.lua"))
  return chunk()
end

local function boot()
  local core = loadCore()
  core.init()
  core.service()
  return core
end

local CFG = { switch = switch, delay = 0, onePerCycle = false }
-- Settings are the model's (core.cfg); a test "cfg" is copied into it.
local function poll(core, inst, cfg, t)
  local c = core.cfg()
  c.switch, c.delay, c.onePerCycle = cfg.switch, cfg.delay or 0, cfg.onePerCycle
  return core.poll(t)
end
local function flight(core, inst, cfg)
  cfg = cfg or CFG
  SW.on = true
  poll(core, inst, cfg, clock)
  local delay = cfg.delay or 0
  for _ = 1, delay do tick(1); poll(core, inst, cfg, clock) end
  tick(1); SW.on = false; poll(core, inst, cfg, clock)
  tick(30)
end
local function armed(core)
  local inst = core.counter()
  SW.on = false
  poll(core, inst, CFG, clock)
  return inst
end

local LOG1 = "SCRIPTS:/FlightCountData/M1.csv"
local IDX = "SCRIPTS:/FlightCountData/models.csv"

-- ================================================================ tests

-- 1 fresh model
reset()
local core = boot()
local v = core.view(clock)
check("fresh model: data folder created", DIRS["SCRIPTS:/FlightCountData"] == true)
check("fresh model: bound to M1", core.S.key == "M1", core.S.key)
check("fresh model: totals 0, ready", v.ready and v.lifetime == 0 and v.today == 0, v.error)
check("fresh model: index lists it", (FS[IDX] or ""):find("M1,extra 330sc.bin,0|1,Extra 330SC", 1, true) ~= nil, FS[IDX])
check("fresh model: logging starts today", v.startDate == "2026-09-26", v.startDate)
check("fresh model: year tile says Since 9/26", v.yearLabel == "Since 9/26", v.yearLabel)
check("fresh model: 11 untracked months + this one", v.months[11].n == nil and v.months[12].n == 0)

-- 2 counting basics
local inst = armed(core)
flight(core, inst)
v = core.view(clock)
check("one flight logged", v.lifetime == 1 and v.today == 1 and v.month == 1 and v.year == 1, v.lifetime)
check("flight written to M1.csv", (FS[LOG1] or ""):find(",f,1,", 1, true) ~= nil)
check("just-logged pill shows 1 right after", core.view(core.S.just.at + 1).just == 1)
check("just-logged pill gone after 5 s", core.view(core.S.just.at + 6).just == nil)
flight(core, inst)
check("second flight after off/on", core.view(clock).lifetime == 2)

-- 3 held on at power-up does not count
reset(); core = boot()
SW.on = true
inst = core.counter()
for _ = 1, 5 do poll(core, inst, CFG, clock); tick(1) end
check("switch on at power-up: nothing logged", core.view(clock).lifetime == 0)
SW.on = false; poll(core, inst, CFG, clock)
SW.on = true; poll(core, inst, CFG, clock)
check("after it is seen off, it counts", core.view(clock).lifetime == 1)

-- 4 delay: early release, then full delay
reset(); core = boot()
local DCFG = { switch = switch, delay = 5, onePerCycle = false }
inst = armed(core)
SW.on = true; poll(core, inst, DCFG, clock)
tick(2); poll(core, inst, DCFG, clock)
check("delay: counting state with progress", inst.state == "counting" and inst.left == 3, inst.state)
tick(1); SW.on = false; poll(core, inst, DCFG, clock)
check("delay: released early, nothing logged", core.view(clock).lifetime == 0)
flight(core, inst, DCFG)
check("delay: held long enough, logged", core.view(clock).lifetime == 1)

-- 5 one per power cycle
reset(); core = boot()
local PCFG = { switch = switch, delay = 0, onePerCycle = true }
inst = armed(core)
flight(core, inst, PCFG); flight(core, inst, PCFG)
check("one per power cycle: second activation ignored", core.view(clock).lifetime == 1)
check("one per power cycle: state 'counted'", inst.state == "counted", inst.state)
core = boot()   -- power cycle
inst = armed(core)
flight(core, inst, PCFG)
check("one per power cycle: counts again after reboot", core.view(clock).lifetime == 2)

-- 6 two widgets on one model log once
reset(); core = boot()
local a, b = armed(core), armed(core)
SW.on = true; poll(core, a, CFG, clock); poll(core, b, CFG, clock)
tick(1); SW.on = false; poll(core, a, CFG, clock); poll(core, b, CFG, clock)
check("two widgets, one activation: one flight", core.view(clock).lifetime == 1)

-- 7 THE v1 BUG: log exists but cannot be read at boot
reset(); core = boot(); inst = armed(core)
for _ = 1, 5 do flight(core, inst) end
local before5 = FS[LOG1]
glitch["M1.csv"] = { mode = "open", left = 3 }
core = loadCore(); core.init()
v = core.view(clock)
check("read failure at boot: NOT shown as 0", not v.ready and v.lifetime == nil and v.error ~= nil, v.lifetime)
inst = armed(core)
flight(core, inst)
check("read failure: new flight still appended", FS[LOG1] ~= before5 and #FS[LOG1] > #before5)
check("read failure: history untouched", FS[LOG1]:sub(1, #before5) == before5)
for _ = 1, 4 do tick(1); core.service() end
v = core.view(clock)
check("read failure: retry recovers all 6", v.ready and v.lifetime == 6, v.lifetime)

-- 8 short read (partial content) is an error, not a smaller count
reset(); core = boot(); inst = armed(core)
for _ = 1, 8 do flight(core, inst) end
glitch["M1.csv"] = { mode = "short", left = 1 }
core = loadCore(); core.init()
check("short read at boot: error, not a partial count", not core.view(clock).ready)
tick(1); core.service()
check("short read: retry gets all 8", core.view(clock).lifetime == 8, core.view(clock).lifetime)

-- 9 append failure queues the flight and writes it later
reset(); core = boot(); inst = armed(core)
glitch["M1.csv"] = { mode = "append", left = 2 }
flight(core, inst)
check("append failed: flight still counted on screen", core.view(clock).lifetime == 1)
check("append failed: one row pending", #core.S.pending == 1)
tick(1); core.service(); tick(1); core.service()
check("append failed: written on retry", #core.S.pending == 0 and (FS[LOG1] or ""):find(",f,1,", 1, true) ~= nil)
core = boot()
check("append failed: survives reboot", core.view(clock).lifetime == 1)

-- 10 index unreadable: never fork a new model key
reset(); core = boot(); inst = armed(core); flight(core, inst)
glitch["models.csv"] = { mode = "open", left = 2 }
core = loadCore(); core.init()
check("index unreadable: not bound, no new key", core.S.key == nil and not (FS[IDX] or ""):find("M2", 1, true))
tick(1); core.service(); tick(1); core.service()
check("index unreadable: retry binds M1 with its flight", core.S.key == "M1" and core.view(clock).lifetime == 1)

-- 11 rename on the radio (live): file renamed with the model
reset(); core = boot(); inst = armed(core)
for _ = 1, 3 do flight(core, inst) end
dropModelFile("extra 330sc.bin"); MODEL.name, MODEL.path = "Extra Blue", "extra blue.bin"; putModelFile(MODEL.path)
core.checkModel()
check("live rename: same key, counts kept", core.S.key == "M1" and core.view(clock).lifetime == 3)
check("live rename: index has new name + file", FS[IDX]:find("M1,extra blue.bin,0|1,Extra Blue", 1, true) ~= nil, FS[IDX])
core = boot()
check("live rename: still M1 after reboot", core.S.key == "M1" and core.view(clock).lifetime == 3)

-- 12 rename where the old file disappears a moment later
reset(); core = boot(); inst = armed(core); flight(core, inst)
MODEL.name, MODEL.path = "Extra Red", "extra red.bin"; putModelFile(MODEL.path)
core.checkModel()
check("slow rename: waits instead of switching", core.S.key == "M1")
tick(1); dropModelFile("extra 330sc.bin"); core.checkModel()
check("slow rename: adopted once the old file is gone", core.S.key == "M1" and core.S.name == "Extra Red")

-- 13 clone (1.6: same receiver ID, same name, new file; original still there)
reset(); core = boot(); inst = armed(core)
for _ = 1, 4 do flight(core, inst) end
MODEL.path = "model01.bin"; putModelFile(MODEL.path)          -- clone loaded, name unchanged
core = boot()
check("clone at boot: new key, starts at 0", core.S.key == "M2" and core.view(clock).lifetime == 0, core.S.key)
MODEL.path = "extra 330sc.bin"
core = boot()
check("original after clone: still M1 with 4", core.S.key == "M1" and core.view(clock).lifetime == 4)

-- 14 model switch while running
reset(); core = boot(); inst = armed(core); flight(core, inst)
MODEL.name, MODEL.path = "Jet", "jet.bin"; putModelFile(MODEL.path)
core.checkModel(); tick(1); core.checkModel(); tick(1); core.checkModel(); tick(1); core.checkModel()
check("model switch: new key after settle", core.S.key == "M2" and core.view(clock).lifetime == 0, core.S.key)
MODEL.name, MODEL.path = "Extra 330SC", "extra 330sc.bin"
for _ = 1, 4 do core.checkModel(); tick(1) end
check("model switch back: M1 with its flight", core.S.key == "M1" and core.view(clock).lifetime == 1)

-- 15 v1 pre-fill (read only) and claimed once per name
reset()
FS["SCRIPTS:/FlightCount/Files/Extra 330SC-Lifetime.txt"] = "227     "
FS["SCRIPTS:/FlightCount/Files/Extra 330SC-Preset.txt"] = "23 "
local v1copy = FS["SCRIPTS:/FlightCount/Files/Extra 330SC-Lifetime.txt"]
core = boot()
v = core.view(clock)
check("v1 pre-fill: before = lifetime + preset = 250", v.before == 250 and v.lifetime == 250 and v.beforeV1, v.before)
check("v1 pre-fill: notice shown", v.note ~= nil and v.note:find("250", 1, true) ~= nil, v.note)
check("v1 pre-fill: v1 files untouched", FS["SCRIPTS:/FlightCount/Files/Extra 330SC-Lifetime.txt"] == v1copy)
check("v1 pre-fill: never on the chart", v.months[12].n == 0 and v.today == 0)
MODEL.path = "model01.bin"; putModelFile(MODEL.path)
core = boot()
check("v1 pre-fill: a clone with the same name gets none", core.view(clock).before == 0)

-- 16 v1 zeroed by the old bug: no pre-fill, no notice
reset()
FS["SCRIPTS:/FlightCount/Files/Extra 330SC-Lifetime.txt"] = "0"
core = boot()
check("v1 total 0: no pre-fill", core.view(clock).before == 0 and core.view(clock).note == nil)

-- 17 flights before, undo, erase
reset(); core = boot(); inst = armed(core)
core.setBefore(150)
for _ = 1, 3 do flight(core, inst) end
v = core.view(clock)
check("before 150 + 3 logged", v.lifetime == 153 and v.logged == 3 and v.before == 150)
core.setBefore(160)
check("before changed: latest wins", core.view(clock).lifetime == 163)
core.undo()
v = core.view(clock)
check("undo: one fewer, today too", v.lifetime == 162 and v.today == 2)
core = boot()
check("undo/before survive reboot", core.view(clock).lifetime == 162)
core.erase()
v = core.view(clock)
check("erase: everything 0", v.lifetime == 0 and v.before == 0 and v.today == 0)
core = boot()
check("erase survives reboot, history still in file", core.view(clock).lifetime == 0 and FS[LOG1]:find(",f,1,", 1, true) ~= nil)

-- 18 dates: day rollover, months, year label
reset(); core = boot(); inst = armed(core)
flight(core, inst); flight(core, inst)
clock = os.time({ year = 2026, month = 9, day = 27, hour = 9 })
v = core.view(clock)
check("next day: today 0, month keeps 2", v.today == 0 and v.month == 2 and v.lifetime == 2)
clock = os.time({ year = 2026, month = 10, day = 3, hour = 9 }); flight(core, inst)
clock = os.time({ year = 2027, month = 1, day = 5, hour = 9 }); flight(core, inst)
v = core.view(clock)
check("Jan 2027: year tile plain 2027", v.yearLabel == "2027", v.yearLabel)
check("Jan 2027: year counts only 2027", v.year == 1, v.year)
check("chart: Sep 2 Oct 1 Nov 0 Dec 0 Jan 1", v.months[8].n == 2 and v.months[9].n == 1 and v.months[10].n == 0 and v.months[12].n == 1,
  v.months[8].n)
check("chart: months before logging are untracked", v.months[7].n == nil)

-- 19 no trigger switch + settings shared by every widget on the model
reset(); core = boot()
inst = poll(core, nil, { switch = nil }, clock)
check("no switch: state noswitch", inst.state == "noswitch", inst.state)
check("counting state is shared by all widgets", core.counter() == core.counter())
-- boot adoption: never-configured widget ignored, newest saved copy wins
core = loadCore()
core.adoptCfg({ switch = nil, delay = nil, at = nil })
check("never-configured widget adopts nothing", core.cfg().switch == nil)
local swA, swB = { state = function() return false end }, { state = function() return false end }
core.adoptCfg({ switch = swA, delay = 3, at = 100 })
core.adoptCfg({ switch = swB, delay = 9, at = 50 })
check("older saved copy does not override a newer one", core.cfg().switch == swA and core.cfg().delay == 3)
core.adoptCfg({ switch = swB, delay = 9, at = 200 })
check("newer saved copy wins", core.cfg().switch == swB and core.cfg().delay == 9)
core = loadCore()
core.adoptCfg({ switch = swA, delay = 1 })   -- v2.0 test build: switch saved, no timestamp
check("copy without timestamp is adopted when nothing else is", core.cfg().switch == swA)
core.adoptCfg({ switch = swB, delay = 2, at = 5 })
check("any timestamped copy beats one without", core.cfg().switch == swB)
local stamped = core.stampCfg(999)
check("closing settings stamps the shared copy", stamped.at == 999 and core.cfg().at == 999)
-- settings follow a live rename
reset(); core = boot(); core.init()
core.cfg().switch, core.cfg().delay = swA, 4
dropModelFile("extra 330sc.bin"); MODEL.name, MODEL.path = "Extra Blue", "extra blue.bin"; putModelFile(MODEL.path)
core.checkModel()
check("settings follow a live rename", core.cfg().switch == swA and core.cfg().delay == 4)

-- 20 models folder unknown: never adopt, a new file starts fresh
reset(); core = boot(); inst = armed(core); flight(core, inst)
DIRS["/models"] = nil
for k in pairs(FS) do if k:find("^/models/") then FS[k] = nil end end
MODEL.path = "extra renamed.bin"
core = boot()
check("models folder unknown: new file = new model", core.S.key == "M2")

print(string.format("\n%d checks, %d failed", checks, failures))
if failures > 0 then error(failures .. " TEST(S) FAILED") end
print("ALL TESTS PASSED")
