-- Flight Counter 2 layouts. One paint per slot size, all reading core.view().
-- Sizes measured on the X20RS 1.6.7 simulator: full page 784x294, full width
-- half height 784x132, half page 388x132. Smaller cells get the compact
-- layouts.

local core, draw = ...
local screen = {}

local function shortDate(date)            -- "2026-09-26" -> "9/26/26"
  if not date or #date < 10 then return "" end
  return tonumber(date:sub(6, 7)) .. "/" .. tonumber(date:sub(9, 10)) .. "/" .. date:sub(3, 4)
end
screen.shortDate = shortDate

function screen.clockText(ts)
  local h = tonumber(os.date("%H", ts))
  local m = os.date("%M", ts)
  local suffix = h >= 12 and "PM" or "AM"
  h = h % 12
  if h == 0 then h = 12 end
  return h .. ":" .. m .. " " .. suffix
end

local function lastFlightText(v, now)
  if not v.lastTs then return "No flights logged yet" end
  local d = os.date("%Y-%m-%d", v.lastTs)
  if d == os.date("%Y-%m-%d", now) then return "Last flight today " .. screen.clockText(v.lastTs) end
  return "Last flight " .. shortDate(d) .. " " .. screen.clockText(v.lastTs)
end
screen.lastFlightText = lastFlightText

local function switchName(cfg)
  if not cfg.switch then return nil end
  local ok, n = pcall(function() return cfg.switch:name() end)
  if ok and type(n) == "string" and n ~= "" then return n end
  return "switch"
end

-- The one message the bottom line shows, most important first.
-- Returns kind, text, extra (progress for "counting").
function screen.status(v, inst, cfg)
  if v.error then return "bad", "Can't read flight log - retrying" end
  if not v.ready then return "sub", "Loading..." end
  if inst.state == "noswitch" then return "warn", "No trigger switch - set one in widget settings", "No trigger switch" end
  if inst.state == "counting" then return "counting", "Counting " .. (inst.left or 0) .. " s", inst.progress end
  if v.just then return "just", "Flight " .. v.just .. " logged" end
  if v.note then return "note", v.note end
  if v.pending and v.pending > 0 then
    return "warn", v.pending .. (v.pending == 1 and " flight" or " flights") .. " not saved yet - retrying"
  end
  if inst.state == "counted" then return "sub", "Counted - power-cycle to count again", "Counted this power-up" end
  local sw = switchName(cfg) or "?"
  return "idle", "Trigger " .. sw .. " - " .. (cfg.delay or 0) .. " s delay"
end

local function statusLine(x, y, w, v, inst, cfg, p, size)
  local kind, text, extra = screen.status(v, inst, cfg)
  -- a shorter wording when the long one would be cut off
  if type(extra) == "string" then
    draw.font(size or "s")
    if draw.size(text) > w then text = extra end
  end
  if kind == "counting" then
    local tw = draw.text(x, y, text, p.warn, size or "s")
    local bx = x + tw + 12
    local _, th = draw.size(text)
    draw.bar(bx, y + math.floor(th / 2) - 4, math.max(20, x + w - bx), 8, extra, p.warn, p.tile)
  elseif kind == "just" then
    draw.pill(x, y - 3, text, p.acc, p.accInk, "sb")
  elseif kind == "note" then
    draw.font("xsb")
    draw.pill(x, y - 3, draw.fit(text, w - 24), p.info, p.infoInk, "xsb")
  else
    local col = (kind == "bad" and p.bad) or (kind == "warn" and p.warn) or p.sub
    draw.text(x, y, text, col, size or "s", w)
  end
  return kind
end

local function num(v, field) if not v.ready then return nil end return v[field] end

-- Today is the hero: accent once there is something to celebrate.
function screen.todayColor(v, p)
  if not v.ready then return p.sub end
  return (v.today or 0) > 0 and p.acc or p.text
end

-- ---------------------------------------------------------------- full page

local function paintFull(w, h, v, inst, cfg, p, now)
  local left = 18
  draw.text(left, 6, v.name, p.text, "lb", 290)
  draw.textRight(w - 14, 10, v.ready and lastFlightText(v, now) or "", p.sub, "s")

  -- Two tile rows fill the height between the header and the status line.
  local note = (v.ready and v.before and v.before > 0) and ("incl. " .. v.before .. " earlier") or nil
  local top, gap, bottom = 42, 10, h - 40
  local r1 = math.floor((bottom - top - gap) * 0.55)
  local r2 = (bottom - top - gap) - r1
  draw.tile(left, top, 128, r1, "Today", num(v, "today"), p,
    { sizes = { "xxl", "xl", "lb" }, color = screen.todayColor(v, p), bold = true })
  local second = { "lb", "b", "std" }
  draw.tile(left + 138, top, 156, r1, "Lifetime", num(v, "lifetime"), p, { note = note, sizes = second })
  draw.tile(left, top + r1 + gap, 128, r2, v.monthLabel or "Month", num(v, "month"), p, { sizes = second })
  draw.tile(left + 138, top + r1 + gap, 156, r2, v.yearLabel or "Year", num(v, "year"), p, { sizes = second })

  statusLine(left, h - 30, 290, v, inst, cfg, p, "s")

  if v.ready then
    draw.chart(322, 42, w - 336, h - 46, v, p, {
      title = true, values = true, letters = true, range = true, avg = true,
      earlier = (v.before and v.before > 0) and (v.before .. " earlier") or nil,
      started = "logging started " .. shortDate(v.startDate),
    })
  end
end

-- ---------------------------------------------------------------- full width, short

local function paintWide(w, h, v, inst, cfg, p, now)
  draw.tile(8, 8, 124, h - 16, "Today", num(v, "today"), p,
    { sizes = { "xxl", "xl", "lb" }, color = screen.todayColor(v, p), bold = true })
  local lx = 146
  local lifeLabel = (v.ready and v.before and v.before > 0) and ("Lifetime, " .. v.before .. " earlier") or "Lifetime"
  draw.label(lx, 10, lifeLabel, p)
  draw.number(lx, 28, num(v, "lifetime"), { "lb", "b" }, 214, p.text)
  local kind = screen.status(v, inst, cfg)
  if kind == "idle" or kind == "sub" then
    if v.ready then
      draw.text(lx, h - 30, (v.monthLabel or "") .. " " .. v.month .. "    " .. (v.yearLabel or "") .. " " .. v.year, p.sub, "sb", 214)
    end
  else
    statusLine(lx, h - 30, 214, v, inst, cfg, p, "s")
  end
  if v.ready then
    draw.chart(372, 6, w - 384, h - 10, v, p, { values = true, letters = true,
      earlier = (v.before and v.before > 0) and (v.before .. " earlier") or nil })
  end
end

-- ---------------------------------------------------------------- half page

local function paintHalf(w, h, v, inst, cfg, p, now)
  draw.tile(8, 6, 132, 90, "Today", num(v, "today"), p,
    { sizes = { "xxl", "xl", "lb" }, color = screen.todayColor(v, p), bold = true })
  local rx = 152
  draw.text(rx, 4, v.name, p.sub, "sb", w - rx - 8)
  local lifeLabel = (v.ready and v.before and v.before > 0) and ("Lifetime, " .. v.before .. " earlier") or "Lifetime"
  draw.label(rx, 26, lifeLabel, p)
  draw.number(rx, 42, num(v, "lifetime"), { "lb", "b" }, w - rx - 10, p.text)
  if v.ready then
    draw.text(rx, 78, (v.monthLabel or "") .. " " .. v.month .. "    " .. (v.yearLabel or "") .. " " .. v.year, p.sub, "s", w - rx - 8)
  end
  local kind = screen.status(v, inst, cfg)
  if kind == "idle" and v.ready then
    draw.chart(10, h - 30, w - 20, 26, v, p, {
      earlier = (v.before and v.before > 0) and (v.before .. " earlier") or nil })
  else
    statusLine(10, h - 28, w - 20, v, inst, cfg, p, "s")
  end
end

-- ---------------------------------------------------------------- small / tiny

local function paintSmall(w, h, v, inst, cfg, p)
  local split = math.floor(w * 0.45)
  draw.number(10, 4, num(v, "today"), { "xxl", "xl", "lb" }, split - 16, screen.todayColor(v, p), true)
  draw.label(12, h - 24, "Today", p)
  draw.rect(split, 10, 1, h - 20, p.grid)
  draw.number(split + 12, 16, num(v, "lifetime"), { "lb", "b", "std" }, w - split - 20, p.text)
  local kind = screen.status(v, inst, cfg)
  if kind == "warn" and inst.state == "noswitch" then
    draw.text(split + 12, h - 24, "NO TRIGGER", p.warn, "xsb")
  elseif kind == "bad" then
    draw.text(split + 12, h - 24, "READ ERROR", p.bad, "xsb")
  else
    draw.label(split + 12, h - 24, "Lifetime", p)
  end
  if kind == "counting" then
    draw.bar(6, h - 7, w - 12, 5, inst.progress or 0, p.warn, p.tile)
  elseif kind == "just" then
    draw.bar(6, h - 7, w - 12, 5, 1, p.acc, p.tile)
  end
end

local function paintTiny(w, h, v, inst, cfg, p)
  local split = math.floor(w * 0.42)
  draw.label(8, 2, "Today", p)
  draw.number(8, 16, num(v, "today"), { "xl", "lb", "std" }, split - 12, screen.todayColor(v, p), true)
  draw.label(split, 2, "Lifetime", p)
  draw.number(split, 18, num(v, "lifetime"), { "lb", "std", "s" }, w - split - 6, p.text)
  local kind = screen.status(v, inst, cfg)
  if kind == "counting" then draw.bar(4, h - 5, w - 8, 4, inst.progress or 0, p.warn, p.tile) end
end

-- ---------------------------------------------------------------- entry

function screen.layout(w, h)
  if w >= 600 and h >= 220 then return "full" end
  if w >= 600 then return "wide" end
  if w >= 300 and h >= 100 then return "half" end
  if w >= 170 and h >= 70 then return "small" end
  return "tiny"
end

local PAINT = { full = paintFull, wide = paintWide, half = paintHalf, small = paintSmall, tiny = paintTiny }

function screen.paint(w, h, inst, cfg, now)
  now = now or os.time()
  local p = draw.palette()
  local v = core.view(now)
  draw.rect(0, 0, w, h, p.bg)
  PAINT[screen.layout(w, h)](w, h, v, inst, cfg, p, now)
  if cfg.border then
    lcd.color(p.grid)
    lcd.drawRectangle(0, 0, w, h)
  end
end

return screen
