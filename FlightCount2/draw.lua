-- Flight Counter 2 rendering helpers. Every lcd.* call lives here.
-- Built-in Ethos fonts only (simple beats pixel-perfect); rounded shapes are
-- made from lcd.drawFilledCircle, which Ethos draws with smooth edges.
-- Colours follow the radio's own light/dark theme (lcd.darkMode()).

local core = ...
local draw = {}

local C = lcd.RGB

function draw.palette()
  local dark = true
  if lcd.darkMode then
    local ok, d = pcall(lcd.darkMode)
    if ok then dark = d and true or false end
  end
  if dark then
    return { bg = C(27, 31, 38), text = C(242, 244, 248), sub = C(143, 152, 168), dim = C(79, 88, 104), tile = C(43, 50, 62),
             bar = C(64, 76, 94), acc = C(60, 207, 110), accInk = C(13, 26, 18), warn = C(240, 160, 44),
             bad = C(255, 93, 93), grid = C(58, 66, 80), info = C(52, 80, 107), infoInk = C(232, 241, 255) }
  end
  return { bg = C(255, 255, 255), text = C(20, 24, 32), sub = C(107, 115, 131), dim = C(185, 192, 204), tile = C(236, 239, 244),
           bar = C(190, 198, 211), acc = C(31, 157, 79), accInk = C(255, 255, 255), warn = C(217, 130, 11),
           bad = C(214, 58, 58), grid = C(210, 216, 225), info = C(52, 80, 107), infoInk = C(255, 255, 255) }
end

-- ---------------------------------------------------------------- fonts

-- 1.6.7 X20RS ("8" w x h): XS 8x15 S 9x18 STD 12x25 L 14x27 XL 19x37 XXL 24x49.
-- Bold exists for XS, S, STD and L only. Missing names fall back down the list.
local SIZES = {
  xxl = { "FONT_XXL", "FONT_XL" },
  xl  = { "FONT_XL", "FONT_L_BOLD" },
  lb  = { "FONT_L_BOLD", "FONT_L", "FONT_STD" },
  l   = { "FONT_L", "FONT_STD" },
  b   = { "FONT_BOLD", "FONT_STD" },
  std = { "FONT_STD", "FONT_S" },
  sb  = { "FONT_S_BOLD", "FONT_S" },
  s   = { "FONT_S" },
  xsb = { "FONT_XS_BOLD", "FONT_XS", "FONT_S" },
  xs  = { "FONT_XS", "FONT_S" },
}
function draw.font(size)
  local list = SIZES[size] or SIZES.s
  for i = 1, #list do
    local f = rawget(_G, list[i])
    if f ~= nil and pcall(lcd.font, f) then return end
  end
  pcall(lcd.font, FONT_S)
end

function draw.size(text)
  local w, h = lcd.getTextSize(tostring(text))
  return w or 0, h or 0
end

function draw.fit(text, maxW)
  text = tostring(text)
  if draw.size(text) <= maxW then return text end
  for i = #text - 1, 1, -1 do
    local cut = string.sub(text, 1, i)
    if draw.size(cut .. "..") <= maxW then return cut .. ".." end
  end
  return ""
end

function draw.text(x, y, text, color, size, maxW)
  if size then draw.font(size) end
  if color then lcd.color(color) end
  text = tostring(text)
  if maxW then text = draw.fit(text, maxW) end
  lcd.drawText(math.floor(x), math.floor(y), text)
  return draw.size(text)
end

function draw.textRight(xr, y, text, color, size)
  if size then draw.font(size) end
  if color then lcd.color(color) end
  local w = draw.size(text)
  lcd.drawText(math.floor(xr - w), math.floor(y), tostring(text))
end

function draw.textCenter(xc, y, text, color, size)
  if size then draw.font(size) end
  if color then lcd.color(color) end
  local w = draw.size(text)
  lcd.drawText(math.floor(xc - w / 2), math.floor(y), tostring(text))
end

function draw.label(x, y, text, p)
  return draw.text(x, y, string.upper(text), p.sub, "xs")
end

-- The first size in `sizes` whose width fits maxW; "--" while unreadable.
-- bold = true draws it twice one pixel apart: Ethos has no bold XL/XXL.
function draw.number(x, y, value, sizes, maxW, color, bold)
  local text = value == nil and "--" or tostring(value)
  for i = 1, #sizes do
    draw.font(sizes[i])
    local w = draw.size(text)
    if w + (bold and 1 or 0) <= maxW or i == #sizes then
      if bold then draw.text(x + 1, y, text, color) end
      local tw, th = draw.text(x, y, text, color)
      return tw + (bold and 1 or 0), th
    end
  end
end

-- ---------------------------------------------------------------- shapes

function draw.rect(x, y, w, h, color)
  lcd.color(color)
  lcd.drawFilledRectangle(math.floor(x), math.floor(y), math.max(0, math.floor(w)), math.max(0, math.floor(h)))
end

-- Filled rectangle with rounded corners (radius r). Falls back to square
-- corners if this firmware has no filled circles.
function draw.round(x, y, w, h, r, color)
  x, y, w, h = math.floor(x), math.floor(y), math.floor(w), math.floor(h)
  if w <= 0 or h <= 0 then return end
  r = math.floor(math.min(r, w / 2, h / 2))
  lcd.color(color)
  if r < 2 or not lcd.drawFilledCircle then
    lcd.drawFilledRectangle(x, y, w, h)
    return
  end
  -- Ethos draws a radius-c circle 2c+1 px wide, so corner circles use
  -- c = r - 1 centred r - 1 in from each edge: they end exactly on the
  -- straight edges instead of poking 1 px past them.
  local c = r - 1
  lcd.drawFilledRectangle(x + r, y, w - 2 * r, h)
  lcd.drawFilledRectangle(x, y + r, w, h - 2 * r)
  lcd.drawFilledCircle(x + c, y + c, c)
  lcd.drawFilledCircle(x + w - 1 - c, y + c, c)
  lcd.drawFilledCircle(x + c, y + h - 1 - c, c)
  lcd.drawFilledCircle(x + w - 1 - c, y + h - 1 - c, c)
end

function draw.dotted(x0, y0, x1, y1, color)
  lcd.color(color)
  local ok = lcd.pen and rawget(_G, "DOTTED") and pcall(lcd.pen, DOTTED)
  if ok then
    lcd.drawLine(math.floor(x0), math.floor(y0), math.floor(x1), math.floor(y1))
    pcall(lcd.pen, SOLID)
    return
  end
  -- no pen styles: short dashes by hand
  local len = math.max(math.abs(x1 - x0), math.abs(y1 - y0))
  if len <= 0 then return end
  for s = 0, len, 6 do
    local e = math.min(s + 2, len)
    local fx, fy = x0 + (x1 - x0) * s / len, y0 + (y1 - y0) * s / len
    local tx, ty = x0 + (x1 - x0) * e / len, y0 + (y1 - y0) * e / len
    lcd.drawLine(math.floor(fx), math.floor(fy), math.floor(tx), math.floor(ty))
  end
end

-- ---------------------------------------------------------------- pieces

function draw.pill(x, y, text, bg, ink, size)
  draw.font(size or "sb")
  local w, h = draw.size(text)
  local ph = h + 6
  local pw = w + ph
  draw.round(x, y, pw, ph, ph / 2, bg)
  draw.text(x + ph / 2, y + 3, text, ink, size or "sb")
  return pw, ph
end

function draw.bar(x, y, w, h, frac, fg, bg)
  draw.round(x, y, w, h, h / 2, bg)
  local fw = math.floor(w * math.max(0, math.min(1, frac or 0)))
  if fw > 0 then draw.round(x, y, math.max(fw, h), h, h / 2, fg) end
end

-- Rounded tile: small label on top, number centred in the space below it,
-- optional note line at the bottom.
function draw.tile(x, y, w, h, label, value, p, opts)
  opts = opts or {}
  draw.round(x, y, w, h, 8, p.tile)
  local pad = 10
  local _, lh = draw.label(x + pad, y + 6, label, p)
  local sizes = opts.sizes or { "xl", "lb", "std" }
  local text = value == nil and "--" or tostring(value)
  local nh = 0
  for i = 1, #sizes do
    draw.font(sizes[i])
    local tw, th = draw.size(text)
    if tw + 1 <= w - 2 * pad or i == #sizes then nh = th break end
  end
  local areaTop = y + 6 + lh
  local areaBottom = y + h - (opts.note and 22 or 6)
  local ny = areaTop + math.max(0, math.floor((areaBottom - areaTop - nh) / 2))
  draw.number(x + pad, ny, value, sizes, w - 2 * pad, opts.color or p.text, opts.bold)
  if opts.note then draw.text(x + pad, y + h - 20, opts.note, p.sub, "xs", w - 2 * pad) end
end

local MONTH_LETTERS = { "J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D" }
local MONTH_NAMES = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
draw.MONTH_NAMES = MONTH_NAMES

-- 12-month bars with rounded tops. opts: title, values, letters, range, avg,
-- earlier ("150 earlier"), started ("logging started 9/26/26").
function draw.chart(x, y, w, h, v, p, opts)
  opts = opts or {}
  local months = v.months
  local n = #months
  local top = y
  if opts.title then
    draw.label(x, y, "Flights per month", p)
    top = y + 20
  end
  local bottomPad = (opts.letters and 18 or 0) + (opts.range and 16 or 0)
  local base = y + h - bottomPad - 1
  local valueRoom = opts.values and 18 or 0
  local maxBar = base - top - valueRoom
  local slot = w / n
  local bw = math.max(4, math.floor(slot * 0.66))
  local peak = 1
  for _, mo in ipairs(months) do if mo.n and mo.n > peak then peak = mo.n end end

  local firstTracked = nil
  for i, mo in ipairs(months) do
    if mo.n ~= nil and not firstTracked then firstTracked = i end
  end

  -- Average line only once all 12 months are logged; a partial year would
  -- put it among the start-line labels.
  if opts.avg and firstTracked == 1 and v.avg and v.avg > 0 and maxBar > 40 then
    local ay = math.floor(base - v.avg / peak * maxBar)
    draw.dotted(x, ay, x + w, ay, p.grid)
    draw.text(x + 2, ay - 16, "avg " .. math.floor(v.avg + 0.5), p.sub, "xs")
  end

  local radius = math.max(2, math.floor(bw / 5))
  for i, mo in ipairs(months) do
    local bx = math.floor(x + (i - 1) * slot + (slot - bw) / 2)
    local current = (i == n)
    if mo.n ~= nil then
      local col = current and p.acc or p.bar
      if mo.n == 0 then
        draw.rect(bx, base - 2, bw, 2, col)
      else
        local bh = math.max(3, math.floor(mo.n / peak * maxBar + 0.5))
        if bh < radius * 3 then
          draw.rect(bx, base - bh, bw, bh, col)                    -- too short to round nicely
        else
          draw.round(bx, base - bh, bw, bh, radius, col)
          draw.rect(bx, base - radius, bw, radius, col)          -- square foot on the baseline
        end
        if opts.values then
          draw.textCenter(bx + bw / 2, base - bh - 17, tostring(mo.n), current and p.acc or p.text, "xsb")
        end
      end
    end
    if opts.letters then
      local col = current and p.acc or ((mo.n == nil) and p.dim or p.sub)
      draw.textCenter(bx + bw / 2, base + 3, MONTH_LETTERS[mo.month], col, "xs")
    end
  end
  draw.rect(x, base, w, 2, p.grid)

  -- Months before logging began: a dotted start line, and the blank area
  -- says how many undated flights it stands for.
  if firstTracked and firstTracked > 1 then
    local lx = math.floor(x + (firstTracked - 1) * slot)
    draw.dotted(lx, top, lx, base, p.sub)
    local blankW = lx - x - 8
    if opts.earlier and v.before and v.before > 0 then
      if maxBar >= 60 then
        draw.font("b")
        if draw.size(opts.earlier) <= blankW then
          local cx, cy = x + (lx - x) / 2, top + maxBar / 2
          draw.textCenter(cx, cy - 14, opts.earlier, p.sub, "b")
          if opts.started then
            draw.font("xs")
            if draw.size(opts.started) <= blankW then draw.textCenter(cx, cy + 12, opts.started, p.sub, "xs") end
          end
        end
      else
        draw.font("xs")
        local tw = draw.size(opts.earlier)
        if tw <= blankW then draw.text(lx - 6 - tw, base - 17, opts.earlier, p.sub, "xs") end
      end
    elseif opts.started and maxBar >= 60 then
      draw.font("xs")
      local tw = draw.size(opts.started)
      if tw <= blankW then draw.text(lx - 6 - tw, top, opts.started, p.sub, "xs") end
    end
  end

  if opts.range then
    local first, last = months[1], months[n]
    draw.text(x, y + h - 15, MONTH_NAMES[first.month] .. " " .. first.year, p.sub, "xs")
    draw.textRight(x + w, y + h - 15, MONTH_NAMES[last.month] .. " " .. last.year, p.sub, "xs")
  end
end

return draw
