-- Flight Counter 2 settings (screen setup > tap the widget > its settings).
-- Counting settings belong to this widget and are saved by Ethos through
-- read()/write(). The model's own data (flights before, undo, erase) is
-- chosen here but applied only when the page closes (main.lua write()), so
-- scrolling a number never writes a line per step and Undo/Erase take two
-- deliberate actions: pick the option, then leave Settings.

local core, screen = ...
local config = {}

local function line(text) return form.addLine(text) end

local function choice(ln, options, get, set)
  return form.addChoiceField(ln, nil, options, get, set)
end

function config.build(widget)
  local cfg, pend = core.cfg(), widget.pending
  local v = core.view()

  line("Same on every widget of this model")
  line("Counting")
  local ln = line("Trigger switch")
  form.addSwitchField(ln, nil, function() return cfg.switch end, function(val) cfg.switch = val end)

  ln = line("Trigger delay")
  local f = form.addNumberField(ln, nil, 0, 1000, function() return cfg.delay end, function(val) cfg.delay = val end)
  pcall(function() f:suffix("s") end)

  ln = line("One count per power cycle")
  form.addBooleanField(ln, nil, function() return cfg.onePerCycle end, function(val) cfg.onePerCycle = val end)

  if v.ready then
    ln = line("Flights before Flight Counter")
    form.addNumberField(ln, nil, 0, 99999,
      function() return pend.before or v.before end,
      function(val) pend.before = val end)
  end

  line("Display")
  ln = line("Border")
  form.addBooleanField(ln, nil, function() return cfg.border end, function(val) cfg.border = val end)

  ln = line(v.name or "This model")
  form.addStaticText(ln, nil, v.ready and (v.lifetime .. " flights") or "")
  if not v.ready then
    ln = line("Flight log")
    form.addStaticText(ln, nil, "not readable yet (" .. tostring(v.error or "loading") .. ")")
  else
    local last = core.lastFlight()
    ln = line("Undo last flight")
    if last then
      local label = "Undo flight " .. v.lifetime .. " (" .. screen.shortDate(last.date) .. " "
        .. screen.clockText(last.ts) .. ")"
      choice(ln, { { "No", 0 }, { label, 1 } },
        function() return pend.undo and 1 or 0 end,
        function(val) pend.undo = (val == 1) end)
    else
      form.addStaticText(ln, nil, "no logged flights")
    end
    ln = line("Erase this model's flights")
    choice(ln, { { "No", 0 }, { "Erase all " .. v.lifetime .. " flights", 1 } },
      function() return pend.erase and 1 or 0 end,
      function(val) pend.erase = (val == 1) end)
    ln = line("Undo and Erase happen when you leave Settings")
  end

  ln = line("Version")
  form.addStaticText(ln, nil, "Flight Counter " .. core.VERSION)
end

-- Called from write(): applies what was picked on the page, then clears it.
function config.apply(widget)
  local pend = widget.pending
  if pend.erase then
    core.erase()
  else
    if pend.undo then core.undo() end
    if pend.before ~= nil then core.setBefore(pend.before) end
  end
  widget.pending = {}
end

return config
