-- Renders Flight Counter 2's REAL paint calls to SVG (harness/out/*.svg) for
-- every layout and state. The lcd mock records primitives; font metrics are
-- the X20RS 1.6.7 simulator's, so this checks composition, not exact pixels.
-- Also executes main.lua (register + create/read/wakeup/paint/configure/
-- write) and the settings form against a form mock.

local OUT = ...

-- real 1.6.7 X20RS codes (FC Fonts log) and measured "8" sizes
FONT_XS, FONT_XS_BOLD, FONT_S, FONT_S_BOLD = 1280, 1536, 1792, 2048
FONT_STD, FONT_BOLD, FONT_L, FONT_L_BOLD, FONT_XL, FONT_XXL = 0, 256, 2304, 2560, 2816, 3072
DOTTED, SOLID = 85, 255
local FONT_H = { [1280] = 15, [1536] = 16, [1792] = 18, [2048] = 18, [0] = 25, [256] = 25,
                 [2304] = 27, [2560] = 27, [2816] = 37, [3072] = 49 }
local FONT_W = { [1280] = 0.53, [1536] = 0.50, [1792] = 0.50, [2048] = 0.50, [0] = 0.48, [256] = 0.52,
                 [2304] = 0.52, [2560] = 0.56, [2816] = 0.51, [3072] = 0.49 }
local BOLD = { [1536] = true, [2048] = true, [256] = true, [2560] = true }

-- ---------------------------------------------------------------- fake world
local realTime = os.time
local clock = realTime({ year = 2026, month = 9, day = 26, hour = 14, min = 20 })
os.time = function(t) if t then return realTime(t) end return clock end

local REAL_OPEN = io.open
local FS, DIRS = {}, { ["SCRIPTS:"] = true, ["/models"] = true }
local function dirOf(p) return p:match("^(.*)/[^/]*$") end
local function handle(p, mode)
  local buf, pos = (mode == "w") and "" or (FS[p] or ""), 1
  return {
    write = function(_, v) buf = buf .. tostring(v) end,
    read = function(_, n) if pos > #buf then return nil end local c = buf:sub(pos, pos + n - 1); pos = pos + #c; return c end,
    close = function() if mode ~= "r" then FS[p] = buf end end,
  }
end
io.open = function(p, mode)
  mode = mode or "r"
  if mode == "r" then if FS[p] == nil then return nil end return handle(p, "r") end
  if not DIRS[dirOf(p)] then return nil end
  return handle(p, mode)
end
os.stat = function(p) if FS[p] then return { size = #FS[p] } end if DIRS[p] then return { size = 0 } end return nil end
os.mkdir = function(p) DIRS[p] = true return true end
os.remove = function(p) FS[p] = nil return true end
os.rename = function(a, b) FS[b] = FS[a]; FS[a] = nil; return true end

local MODEL = { name = "Extra 330SC", path = "extra 330sc.bin" }
model = { name = function() return MODEL.name end, path = function() return MODEL.path end,
          id = function() return { 0, 1 } end }
FS["/models/extra 330sc.bin"] = "FRSK"

local SW = { on = false }
local SWITCH = { state = function() return SW.on end, name = function() return "SF" .. "\226\134\147" end }

-- ---------------------------------------------------------------- lcd mock
local DARK = true
local curFont, curCol, ops, CW, CH, curPen = 1792, "#000", {}, 784, 314, 255
local function hex(c) return string.format("#%02x%02x%02x", c[1], c[2], c[3]) end
local function esc(t) return (tostring(t):gsub("&", "&amp;"):gsub("<", "&lt;")) end
lcd = {
  RGB = function(r, g, b) return { r, g, b } end,
  color = function(c) curCol = hex(c) end,
  font = function(f) assert(FONT_H[f], "unknown font") curFont = f end,
  darkMode = function() return DARK end,
  invalidate = function() end,
  getWindowSize = function() return CW, CH end,
  getTextSize = function(t) return #tostring(t) * FONT_H[curFont] * FONT_W[curFont], FONT_H[curFont] end,
  drawText = function(x, y, t)
    ops[#ops + 1] = string.format('<text x="%d" y="%d" font-size="%d" fill="%s" font-weight="%s">%s</text>',
      x, y + math.floor(FONT_H[curFont] * 0.78), math.floor(FONT_H[curFont] * 0.82), curCol,
      BOLD[curFont] and "700" or "400", esc(t))
  end,
  drawFilledRectangle = function(x, y, w, h)
    ops[#ops + 1] = string.format('<rect x="%d" y="%d" width="%d" height="%d" fill="%s"/>', x, y, w, h, curCol)
  end,
  drawRectangle = function(x, y, w, h)
    ops[#ops + 1] = string.format('<rect x="%d" y="%d" width="%d" height="%d" fill="none" stroke="%s"/>', x, y, w, h, curCol)
  end,
  drawLine = function(a, b, c, d)
    ops[#ops + 1] = string.format('<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="%s"%s/>', a, b, c, d, curCol,
      curPen == DOTTED and ' stroke-dasharray="2 3"' or '')
  end,
  pen = function(v) curPen = v end,
  drawFilledCircle = function(x, y, r)
    -- Ethos fills a (2r+1) px disc; r + 0.5 reproduces that footprint
    ops[#ops + 1] = string.format('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s"/>', x + 0.5, y + 0.5, r + 0.5, curCol)
  end,
}

-- storage + form mocks, recording the settings page
local STORE = {}
storage = { read = function(k) return STORE[k] end, write = function(k, v) STORE[k] = v end }
local FORM = {}
local function field(kind, a) FORM[#FORM + 1] = kind .. " " .. tostring(a or "") return { suffix = function() end } end
form = {
  addLine = function(t) FORM[#FORM + 1] = "line  " .. t return {} end,
  addSwitchField = function(_, _, get) return field("switch", get()) end,
  addNumberField = function(_, _, lo, hi, get) return field("number", get()) end,
  addBooleanField = function(_, _, get) return field("bool", get()) end,
  addChoiceField = function(_, _, opts, get)
    local names = {}
    for _, o in ipairs(opts) do names[#names + 1] = o[1] end
    return field("choice", table.concat(names, " | ") .. " = " .. tostring(get()))
  end,
  addStaticText = function(_, _, t) return field("text", t) end,
}
local REG
system = { registerWidget = function(t) REG = t end, getVersion = function() return { board = "X20RS" } end }

-- ---------------------------------------------------------------- load real code
local main = assert(loadfile("main.lua"))()
main.init()
assert(REG and REG.key == "flcnt20", "widget not registered")

-- ---------------------------------------------------------------- scenarios
local DATA = "SCRIPTS:/FlightCountData/"
local function row(t, kind, n, extra)
  return table.concat({ tostring(t), os.date("%Y-%m-%d", t), kind, tostring(n), extra or "" }, ",") .. "\n"
end

local function writeLog(rows)
  DIRS["SCRIPTS:/FlightCountData"] = true
  FS[DATA .. "models.csv"] = "# idx\nM1,extra 330sc.bin,0|1,Extra 330SC,2025-10-02,\n"
  FS[DATA .. "M1.csv"] = table.concat(rows)
end

local function monthsOfFlying(counts, today)
  -- counts oldest..newest over the 12 months ending September 2026
  local rows = { row(realTime({ year = 2025, month = 10, day = 1, hour = 9 }), "id", 0, "Extra 330SC | extra 330sc.bin") }
  for i, n in ipairs(counts) do
    local mm, yy = 9 + i, 2025
    if mm > 12 then mm = mm - 12; yy = 2026 end
    for k = 1, n do
      local day = (mm == 9 and yy == 2026) and ((k > n - today) and 26 or (1 + k)) or (1 + k % 27)
      rows[#rows + 1] = row(realTime({ year = yy, month = mm, day = day, hour = 10, min = k }), "f", 1)
    end
  end
  return rows
end

local W, CORE   -- current widget instance, its core

local function freshBoot()
  local m = assert(loadfile("main.lua"))()
  m.init()
  CORE = m.core
  W = REG.create()
  REG.read(W)
end

local shots = {}
local function shot(name, w, h, note)
  CW, CH = w, h
  ops = {}
  REG.wakeup(W)
  REG.paint(W)
  local bg = DARK and "#2c2c2c" or "#dcdcdc"   -- Ethos's own screen colour behind the widget
  local f = assert(REAL_OPEN(OUT .. "/" .. name .. ".svg", "w"))
  f:write(string.format('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d" font-family="Roboto,Helvetica,Arial,sans-serif"><rect width="%d" height="%d" fill="%s"/>\n',
    w, h, w, h, w, h, bg))
  f:write(table.concat(ops, "\n")); f:write("\n</svg>\n"); f:close()
  shots[#shots + 1] = { name = name, w = w, h = h, note = note or "" }
end

-- A: long-time user, trigger set, idle
writeLog(monthsOfFlying({ 4, 2, 0, 1, 6, 11, 18, 22, 25, 19, 23, 12 }, 3))
STORE = { switch = SWITCH, delay = 5, onePerCycle = false, border = false }
freshBoot()
SW.on = false; REG.wakeup(W)
shot("full_idle_night", 784, 314, "Full page, idle, night")
shot("wide_idle_night", 784, 152, "Full width half height")
shot("half_idle_night", 388, 152, "Half page, idle")
shot("small_idle_night", 256, 95, "Small (estimated size)")
shot("tiny_idle_night", 190, 56, "Tiny (estimated size)")
DARK = false
shot("full_idle_day", 784, 314, "Full page, day")
shot("half_idle_day", 388, 152, "Half page, day")
DARK = true

-- B: counting (5 s delay, 2 s in)
SW.on = true; REG.wakeup(W); clock = clock + 2
shot("full_counting", 784, 314, "Full page, counting 3 s left")
shot("half_counting", 388, 152, "Half page, counting")
shot("small_counting", 256, 95, "Small, counting")
-- C: just logged
clock = clock + 3; REG.wakeup(W)
shot("half_just", 388, 152, "Half page, just logged")
SW.on = false; clock = clock + 10; REG.wakeup(W)

-- D: one per power cycle, already counted
CORE.cfg().onePerCycle = true
REG.wakeup(W)
shot("half_counted", 388, 152, "Half page, counted this power-up")
CORE.cfg().onePerCycle = false

-- E: no trigger switch
CORE.cfg().switch = nil
shot("half_noswitch", 388, 152, "Half page, no trigger switch")
shot("small_noswitch", 256, 95, "Small, no trigger switch")
CORE.cfg().switch = SWITCH

-- F: unreadable log (the v1 wipe case): dashes
local saved = FS[DATA .. "M1.csv"]
local realOpen = io.open
io.open = function(p, mode) if p:find("M1.csv", 1, true) and (mode or "r") == "r" then return nil end return realOpen(p, mode) end
freshBoot()
shot("half_error", 388, 152, "Half page, flight log unreadable")
shot("full_error", 784, 314, "Full page, flight log unreadable")
io.open = realOpen

-- G: fresh install with 150 known flights, install day
FS[DATA .. "M1.csv"] = nil; FS[DATA .. "models.csv"] = nil
clock = realTime({ year = 2026, month = 9, day = 26, hour = 14 })
freshBoot()
W.pending.before = 150
REG.write(W)
shot("full_known_day1", 784, 314, "Known count: install day (150 before)")
shot("half_known_day1", 388, 152, "Known count: install day, half")

-- H: four months later
for m = 1, 5 do
  local n = ({ 5, 14, 9, 3, 2 })[m]
  local mm, yy = 8 + m, 2026
  if mm > 12 then mm = mm - 12; yy = 2027 end
  for k = 1, n do
    FS[DATA .. "M1.csv"] = FS[DATA .. "M1.csv"] .. row(realTime({ year = yy, month = mm, day = (mm == 1) and 5 or (1 + k), hour = 10, min = k }), "f", 1)
  end
end
clock = realTime({ year = 2027, month = 1, day = 5, hour = 11, min = 30 })
freshBoot()
shot("full_known_later", 784, 314, "Known count: four months later")
shot("wide_known_later", 784, 152, "Known count: wide")
shot("half_known_later", 388, 152, "Known count: half")

-- I: v1 pre-fill notice
FS[DATA .. "M1.csv"] = nil; FS[DATA .. "models.csv"] = nil
FS["SCRIPTS:/FlightCount/Files/Extra 330SC-Lifetime.txt"] = "227   "
FS["SCRIPTS:/FlightCount/Files/Extra 330SC-Preset.txt"] = "23"
clock = realTime({ year = 2026, month = 9, day = 26, hour = 14 })
freshBoot()
shot("half_v1_note", 388, 152, "First boot next to v1: pre-filled 250")

-- settings page for this state
FORM = {}
REG.configure(W)
local f = assert(REAL_OPEN(OUT .. "/settings.txt", "w"))
f:write(table.concat(FORM, "\n")); f:close()

-- index page
local html = { '<meta charset="utf-8"><title>Flight Counter 2 renders</title><body style="background:#e9ecf1;font:14px Helvetica;padding:20px">' }
for _, s in ipairs(shots) do
  html[#html + 1] = string.format('<div style="display:inline-block;margin:0 18px 22px 0;vertical-align:top"><div>%s</div><img src="%s.svg" width="%d" height="%d"></div>',
    s.note, s.name, s.w, s.h)
end
html[#html + 1] = '<h3>Settings page (form mock)</h3><pre>' .. esc(table.concat(FORM, "\n")) .. '</pre>'
local idx = assert(REAL_OPEN(OUT .. "/index.html", "w"))
idx:write(table.concat(html, "\n")); idx:close()
print("rendered " .. #shots .. " screens to " .. OUT)
