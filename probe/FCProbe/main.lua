-- FCProbe: measures what Flight Counter 2.0 depends on, on this Ethos build.
-- Writes SCRIPTS:/FCProbe/log.txt and draws the key facts on screen.
-- Drop it into several widget slot sizes; every new size is logged once.

local LOG_CANDIDATES = { "log.txt", "/scripts/FCProbe/log.txt", "SCRIPTS:/FCProbe/log.txt" }
local logPath = nil
local lines = {}
local sizesSeen = {}
local fontsDone = false

local function s(v)
  if type(v) == "table" then
    local parts = {}
    for k, x in pairs(v) do parts[#parts + 1] = tostring(k) .. "=" .. tostring(x) end
    table.sort(parts)
    return "{" .. table.concat(parts, ",") .. "}"
  end
  return tostring(v)
end

local function append(text)
  lines[#lines + 1] = text
  if #lines > 14 then table.remove(lines, 1) end
  local paths = logPath and { logPath } or LOG_CANDIDATES
  for i = 1, #paths do
    local ok, f = pcall(io.open, paths[i], "a")
    if ok and f then
      f:write(text .. "\n")
      f:close()
      logPath = paths[i]
      return
    end
  end
end

local function try(label, fn)
  local ok, a, b = pcall(fn)
  append(label .. " ok=" .. tostring(ok) .. " -> " .. s(a) .. (b ~= nil and (" | " .. s(b)) or ""))
end

local function writeRead(path)
  local f = io.open(path, "w")
  if not f then return "open-w failed" end
  f:write("x\n")
  f:close()
  local r = io.open(path, "r")
  if not r then return "open-r failed" end
  local c = r:read(10)
  r:close()
  return "wrote+read '" .. tostring(c):gsub("\n", "\\n") .. "'"
end

local function bootProbe()
  append("==== boot " .. os.date("%Y-%m-%d %H:%M:%S"))
  try("getVersion", function() return system.getVersion() end)
  try("model.name", function() return model.name() end)
  try("model.path", function() return model.path() end)
  try("model.id", function() return model.id() end)
  try("os.mkdir type", function() return type(os.mkdir) end)
  try("os.stat type", function() return type(os.stat) end)
  try("os.rename type", function() return type(os.rename) end)
  try("os.remove type", function() return type(os.remove) end)
  try("mkdir SCRIPTS:/FCProbe/Files", function() return os.mkdir("SCRIPTS:/FCProbe/Files") end)
  try("write SCRIPTS:/FCProbe/Files/t.txt", function() return writeRead("SCRIPTS:/FCProbe/Files/t.txt") end)
  try("mkdir /scripts/FCProbe/Files2", function() return os.mkdir("/scripts/FCProbe/Files2") end)
  try("write /scripts/FCProbe/Files2/t.txt", function() return writeRead("/scripts/FCProbe/Files2/t.txt") end)
  try("write Files3/t.txt (no dir)", function() return writeRead("Files3/t.txt") end)
  try("stat SCRIPTS:/FCProbe/Files", function() return os.stat("SCRIPTS:/FCProbe/Files") end)
  try("stat model file", function() return os.stat(model.path()) end)
  local mp = model.path()
  local cands = { mp, "/models/" .. mp, "RADIO:/models/" .. mp, "SD:/models/" .. mp, "/" .. mp,
                  "../../models/" .. mp, "/radio/models/" .. mp, "MODELS:/" .. mp, "MODELS:" .. mp }
  for i = 1, #cands do
    try("open-r " .. cands[i], function()
      local f = io.open(cands[i], "r")
      if f then f:close() return "EXISTS" end
      return "no"
    end)
    try("stat " .. cands[i], function() return os.stat(cands[i]) end)
  end
  try("stat missing /models/zz_nope.bin", function() return os.stat("/models/zz_nope.bin") end)
  try("open-r missing RADIO:/models/zz_nope.bin", function()
    local f = io.open("RADIO:/models/zz_nope.bin", "r")
    if f then f:close() return "EXISTS" end
    return "no"
  end)
  try("lcd.darkMode", function() return lcd.darkMode() end)
  try("os.date *t", function() return os.date("*t") end)
  try("log path used", function() return logPath end)
end

local FONTS = { "FONT_XS", "FONT_S", "FONT_STD", "FONT_M", "FONT_L", "FONT_XL", "FONT_XXL", "FONT_XXXL",
                "FONT_BOLD", "FONT_XS_BOLD", "FONT_S_BOLD", "FONT_L_BOLD", "FONT_XL_BOLD", "FONT_XXL_BOLD" }

local function fontProbe()
  local out = {}
  for i = 1, #FONTS do
    local f = _G[FONTS[i]]
    if f ~= nil then
      local ok = pcall(lcd.font, f)
      local ok2, w, h = pcall(lcd.getTextSize, "8")
      out[#out + 1] = FONTS[i] .. "=" .. (ok and ok2 and (tostring(w) .. "x" .. tostring(h)) or "err")
    else
      out[#out + 1] = FONTS[i] .. "=nil"
    end
  end
  append("fonts " .. table.concat(out, " "))
end

local function create()
  return { booted = false }
end

local function wakeup(w)
  if not w.booted then
    w.booted = true
    pcall(bootProbe)
  end
  lcd.invalidate()
end

local function paint(w)
  local ok, width, height = pcall(lcd.getWindowSize)
  if ok then
    local key = tostring(width) .. "x" .. tostring(height)
    if not sizesSeen[key] then
      sizesSeen[key] = true
      append("slot " .. key)
    end
  end
  if not fontsDone then
    fontsDone = true
    pcall(fontProbe)
  end
  pcall(function()
    lcd.color(lcd.darkMode() and WHITE or BLACK)
    lcd.font(FONT_S)
    lcd.drawText(4, 2, "FCProbe " .. tostring(width) .. "x" .. tostring(height))
    local y = 24
    for i = math.max(1, #lines - 8), #lines do
      lcd.drawText(4, y, string.sub(lines[i], 1, 90))
      y = y + 20
    end
  end)
end

local function init()
  system.registerWidget({ key = "fcprobe", name = "FC Probe", create = create, wakeup = wakeup, paint = paint })
end

return { init = init }
