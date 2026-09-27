-- FC Fonts: shows every built-in Ethos font (regular + bold) at real size,
-- rounded shapes, and logs every lcd.* function + font constant to
-- SCRIPTS:/FCFonts/lcd.txt. Put it on a FULL PAGE.

local FONTS = { "FONT_XS", "FONT_XS_BOLD", "FONT_S", "FONT_S_BOLD", "FONT_STD", "FONT_BOLD",
                "FONT_L", "FONT_L_BOLD", "FONT_XL", "FONT_XL_BOLD", "FONT_XXL", "FONT_XXL_BOLD", "FONT_XXXL" }
local logged = false

local function logOnce()
  if logged then return end
  logged = true
  local names = {}
  for k, v in pairs(lcd) do names[#names + 1] = k .. "(" .. type(v) .. ")" end
  table.sort(names)
  local fonts = {}
  for _, n in ipairs(FONTS) do fonts[#fonts + 1] = n .. "=" .. tostring(rawget(_G, n)) end
  local consts = {}
  for k, v in pairs(_G) do
    if type(k) == "string" and (k:find("^FONT_") or k:find("^COLOR_") or k:find("ALIGN") or k:find("^SOLID")
        or k:find("^DOTTED") or k:find("^DASH") or k:find("^CENTERED") or k:find("^RIGHT") or k:find("^LEFT")) then
      consts[#consts + 1] = k .. "=" .. tostring(v)
    end
  end
  table.sort(consts)
  local f = io.open("lcd.txt", "w")
  if f then
    f:write("lcd: " .. table.concat(names, " ") .. "\n\n")
    f:write("fonts: " .. table.concat(fonts, " ") .. "\n\n")
    f:write("constants: " .. table.concat(consts, " ") .. "\n")
    f:close()
  end
end

local function roundRect(x, y, w, h, r)
  if lcd.drawFilledCircle then
    lcd.drawFilledRectangle(x + r, y, w - 2 * r, h)
    lcd.drawFilledRectangle(x, y + r, w, h - 2 * r)
    lcd.drawFilledCircle(x + r, y + r, r)
    lcd.drawFilledCircle(x + w - r - 1, y + r, r)
    lcd.drawFilledCircle(x + r, y + h - r - 1, r)
    lcd.drawFilledCircle(x + w - r - 1, y + h - r - 1, r)
  else
    lcd.drawFilledRectangle(x, y, w, h)
  end
end

local function paint()
  pcall(logOnce)
  local dark = lcd.darkMode and lcd.darkMode()
  local ink = dark and lcd.RGB(242, 244, 248) or lcd.RGB(20, 24, 32)
  local sub = dark and lcd.RGB(143, 152, 168) or lcd.RGB(107, 115, 131)
  local green = lcd.RGB(60, 207, 110)
  local tile = dark and lcd.RGB(44, 51, 64) or lcd.RGB(232, 236, 242)

  -- left column: the small and medium fonts, regular then bold
  local y = 2
  for i = 1, 8 do
    local n = FONTS[i]
    local f = rawget(_G, n)
    if f and pcall(lcd.font, f) then
      lcd.color(sub)
      lcd.drawText(4, y, string.sub(n, 6))
      lcd.color(ink)
      lcd.drawText(92, y, "Today 3  Lifetime 252")
      local _, h = lcd.getTextSize("8")
      y = y + math.floor(h) + 1
    end
  end

  -- right column: the big fonts, as they would show the hero numbers
  local x = 420
  y = 2
  for i = 9, #FONTS do
    local n = FONTS[i]
    local f = rawget(_G, n)
    if f and pcall(lcd.font, f) then
      lcd.color(sub)
      pcall(lcd.font, FONT_XS)
      lcd.drawText(x, y + 4, string.sub(n, 6))
      pcall(lcd.font, f)
      lcd.color(green)
      lcd.drawText(x + 70, y, "2")
      lcd.color(ink)
      lcd.drawText(x + 110, y, "252")
      local _, h = lcd.getTextSize("8")
      y = y + math.floor(h)
    end
  end

  -- shapes: square tile vs rounded tile vs rounded pill vs circle
  local sy = 214
  lcd.color(tile)
  lcd.drawFilledRectangle(4, sy, 120, 70)
  roundRect(134, sy, 120, 70, 10)
  lcd.color(green)
  roundRect(264, sy + 20, 150, 30, 15)
  if lcd.drawFilledCircle then lcd.drawFilledCircle(450, sy + 35, 30) end
  if lcd.drawCircle then lcd.color(ink) lcd.drawCircle(530, sy + 35, 30) end
  lcd.color(ink)
  pcall(lcd.font, FONT_S)
  lcd.drawText(10, sy + 4, "square tile")
  lcd.drawText(140, sy + 4, "rounded tile")
  lcd.color(lcd.RGB(13, 26, 18))
  lcd.drawText(284, sy + 26, "Flight 252 logged")
  lcd.color(sub)
  lcd.drawText(580, sy + 26, "circles: AA?")
end

local function init()
  system.registerWidget({ key = "fcfonts", name = "FC Fonts", create = function() return {} end,
                          paint = paint, wakeup = function() end })
end

return { init = init }
