-- Flight Counter 2 -- counts flights from a switch or logic switch you choose,
-- keeps one line per flight, and shows today, lifetime and monthly history.
-- A separate install from v1 (new folder, new widget key); v1 is never
-- touched, only read once to pre-fill "flights before".
-- Every entry point is pcall-wrapped so a failure shows as text instead of
-- silently stopping the counting.

local core   = assert(loadfile("core.lua"))()
local draw   = assert(loadfile("draw.lua"))(core)
local screen = assert(loadfile("screen.lua"))(core, draw)
local config = assert(loadfile("config.lua"))(core, screen)

local lastError = nil

local function create()
  local ok, err = pcall(core.init)
  if not ok then lastError = "init: " .. tostring(err) end
  return { pending = {}, lastInvalidate = 0, lastState = nil }
end

local function wakeup(widget)
  local ok, err = pcall(function()
    core.init()
    core.service()
    core.checkModel()
    core.poll()
  end)
  if not ok then lastError = "wakeup: " .. tostring(err) end
  -- Repaint once a second, and at once when the state changes.
  local now = os.time()
  local key = tostring(core.counter().state) .. tostring(core.S.version) .. tostring(core.ready())
  if now ~= widget.lastInvalidate or key ~= widget.lastState then
    widget.lastInvalidate, widget.lastState = now, key
    lcd.invalidate()
  end
end

local function paint(widget)
  local w, h = lcd.getWindowSize()
  local ok, err = pcall(screen.paint, w, h, core.counter(), core.cfg())
  if not ok then lastError = "paint: " .. tostring(err) end
  if lastError then
    lcd.color(lcd.RGB(255, 93, 93))
    pcall(lcd.font, FONT_XS)
    lcd.drawText(4, h - 16, string.sub("Flight Counter error " .. lastError, 1, 120))
  end
end

local function configure(widget)
  local ok, err = pcall(config.build, widget)
  if not ok then lastError = "configure: " .. tostring(err) end
end

-- Settings are the model's, shared by every Flight Counter 2 widget on it
-- (core.cfg). Each widget still saves a copy through Ethos; the newest copy
-- found at power-up wins.
local function read(widget)
  pcall(core.adoptCfg, {
    switch = storage.read("switch"),
    delay = storage.read("delay"),
    onePerCycle = storage.read("onePerCycle"),
    border = storage.read("border"),
    at = storage.read("cfgAt"),
  })
end

local function write(widget)
  local cfg = core.stampCfg()
  storage.write("switch", cfg.switch)
  storage.write("delay", cfg.delay)
  storage.write("onePerCycle", cfg.onePerCycle)
  storage.write("border", cfg.border)
  storage.write("cfgAt", cfg.at)
  local ok, err = pcall(config.apply, widget)
  if not ok then lastError = "settings: " .. tostring(err) end
end

local function init()
  system.registerWidget({
    key = "flcnt20",
    name = "Flight Counter 2",
    create = create,
    wakeup = wakeup,
    paint = paint,
    configure = configure,
    read = read,
    write = write,
    persistent = true,
    title = false,          -- no Ethos title strip: the widget shows the model name itself
  })
end

return { init = init, core = core }   -- core exposed for the test harness only
