--- Aerovibes Flight Counter 1.0

local translations = {en="Aerovibes Flight Counter 1.0", fr="Aerovibes Flight Counter 1.0"}

local function name()
    local locale = system.getLocale()
    return translations[locale] or translations["en"]
end

local function getTodayKey()
    local d = os.date("*t")
    return string.format("%04d-%02d-%02d", d.year, d.month, d.day)
end

local function trim(s)
    if s == nil then
        return ""
    end
    return (tostring(s):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function getPath(widget, suffix)
    return "/scripts/FlightCount_1_0/Files/" .. widget.modelName .. "-" .. suffix .. ".txt"
end

local function ensureNumberFile(path, defaultValue)
    local file = io.open(path, "a")
    if file then
        file:write(" ")
        file:close()
    end

    file = io.open(path, "r")
    if not file then
        return defaultValue
    end

    local value = file:read("*line")
    file:close()

    value = trim(value)
    if value == "" then
        file = io.open(path, "w")
        if file then
            file:write(defaultValue)
            file:close()
        end
        return defaultValue
    end

    local n = tonumber(value)
    if n == nil then
        return defaultValue
    end

    return n
end

local function ensureTextFile(path, defaultValue)
    local file = io.open(path, "r")
    if not file then
        file = io.open(path, "w")
        if file then
            file:write(defaultValue)
            file:close()
        end
        return tostring(defaultValue)
    end

    local value = file:read("*line")
    file:close()

    value = trim(value)
    if value == "" then
        file = io.open(path, "w")
        if file then
            file:write(defaultValue)
            file:close()
        end
        return tostring(defaultValue)
    end

    return value
end

local function writeFile(path, value)
    local file = io.open(path, "w")
    if file then
        file:write(value)
        file:close()
    end
end

local function toggle(interval, c1, c2)
    if os.clock() % (interval * 2) < interval then
        return c1
    else
        return c2
    end
end

local function create()
    return {
        triggerswitch = nil,
        switchactive = 0,
        tallydelayStart = 0,
        tallyDelay = 0,
        today = 0,
        lifetime = 0,
        preset = 0,
        newPreset = 0,
        resetOnReboot = false,
        modelName = "nil",
        ini = true,
        border = false,
        todayKey = "",
        powerCycleCounted = false,
        triggerOn = false,
        color = lcd.RGB(0x00, 0xFC, 0x00),
        newColor = lcd.RGB(0x00, 0x00, 0x00),
        color1 = lcd.RGB(0xE8, 0x5C, 0x00),
        color2 = lcd.RGB(0x00, 0xFC, 0x00)
    }
end

local function loadFiles(widget)
    widget.preset = ensureNumberFile(getPath(widget, "Preset"), 0)
    widget.newPreset = widget.preset
    widget.lifetime = ensureNumberFile(getPath(widget, "Lifetime"), 0)
    widget.today = ensureNumberFile(getPath(widget, "Today"), 0)
    widget.resetOnReboot = ensureNumberFile(getPath(widget, "ResetOnReboot"), 0) == 1

    local currentKey = getTodayKey()
    widget.todayKey = ensureTextFile(getPath(widget, "TodayDate"), currentKey)

    if widget.todayKey ~= currentKey then
        widget.today = 0
        widget.todayKey = currentKey
        writeFile(getPath(widget, "Today"), 0)
        writeFile(getPath(widget, "TodayDate"), widget.todayKey)
    end
end

local function saveCounts(widget)
    writeFile(getPath(widget, "Lifetime"), widget.lifetime)
    writeFile(getPath(widget, "Today"), widget.today)
    writeFile(getPath(widget, "TodayDate"), widget.todayKey)
end

local function resetAllData(widget)
    widget.today = 0
    widget.lifetime = 0
    widget.preset = 0
    widget.newPreset = 0
    widget.todayKey = getTodayKey()
    widget.powerCycleCounted = false

    writeFile(getPath(widget, "Preset"), 0)
    writeFile(getPath(widget, "Lifetime"), 0)
    writeFile(getPath(widget, "Today"), 0)
    writeFile(getPath(widget, "TodayDate"), widget.todayKey)
end

local function checkDateChange(widget)
    local currentKey = getTodayKey()
    if widget.todayKey ~= currentKey then
        widget.todayKey = currentKey
        widget.today = 0
        writeFile(getPath(widget, "Today"), 0)
        writeFile(getPath(widget, "TodayDate"), widget.todayKey)
        lcd.invalidate()
    end
end

local function setDefaultTextColor()
    if lcd.darkMode() then
        lcd.color(WHITE)
    else
        lcd.color(COLOR_BLACK)
    end
end

local function paint(widget)
    if lcd.isVisible() then
        local w, h = lcd.getWindowSize()
        local totalLifetime = widget.preset + widget.lifetime

        setDefaultTextColor()

        if widget.border then
            lcd.drawRectangle(0, 0, w, h)
        end

        if widget.triggerswitch ~= nil and widget.triggerswitch:state() and not widget.powerCycleCounted and widget.tallyDelay > 0 and widget.switchactive == 0 then
            lcd.color(widget.color)
        else
            setDefaultTextColor()
        end

        if h < 90 then
            lcd.font(FONT_S)
            lcd.drawText(w / 2, h * 0.28, "Today: " .. math.floor(widget.today), CENTERED)
            lcd.drawText(w / 2, h * 0.58, "Lifetime: " .. math.floor(totalLifetime), CENTERED)
        elseif h < 170 then
            lcd.font(FONT_STD)
            lcd.drawText(w / 2, h * 0.32, "Today: " .. math.floor(widget.today), CENTERED)
            lcd.drawText(w / 2, h * 0.62, "Lifetime: " .. math.floor(totalLifetime), CENTERED)
        else
            lcd.font(FONT_XL)
            lcd.drawText(w / 2, h * 0.30, "Today: " .. math.floor(widget.today), CENTERED)
            lcd.drawText(w / 2, h * 0.60, "Lifetime: " .. math.floor(totalLifetime), CENTERED)
        end
    end
end

local function wakeup(widget)
    if widget.ini then
        widget.ini = false
        widget.modelName = model.name()
        loadFiles(widget)

        if widget.resetOnReboot then
            resetAllData(widget)
            widget.resetOnReboot = false
            writeFile(getPath(widget, "ResetOnReboot"), 0)
        end

        lcd.invalidate()
    end

    checkDateChange(widget)

    if widget.triggerswitch ~= nil and widget.triggerswitch:state() and not widget.powerCycleCounted and widget.switchactive == 0 then
        widget.newColor = toggle(0.5, widget.color1, widget.color2)
        if widget.color ~= widget.newColor then
            widget.color = widget.newColor
            lcd.invalidate()
        end
        widget.triggerOn = true
    else
        if widget.triggerOn then
            widget.triggerOn = false
            lcd.invalidate()
        end
    end

    if not widget.powerCycleCounted and widget.triggerswitch ~= nil and widget.triggerswitch:state() then
        if widget.tallydelayStart == 0 then
            widget.tallydelayStart = math.floor(os.clock())
        end
        if math.floor(os.clock()) >= widget.tallydelayStart + widget.tallyDelay then
            widget.today = widget.today + 1
            widget.lifetime = widget.lifetime + 1
            widget.switchactive = 1
            widget.powerCycleCounted = true
            saveCounts(widget)
            lcd.invalidate()
        end
    elseif widget.triggerswitch == nil or not widget.triggerswitch:state() then
        widget.tallydelayStart = 0
    end

    if widget.newPreset ~= widget.preset then
        widget.preset = widget.newPreset
        writeFile(getPath(widget, "Preset"), widget.preset)
        lcd.invalidate()
    end
end

local function configure(widget)
    local line

    line = form.addLine("Trigger Switch")
    form.addSwitchField(line, form.getFieldSlots(line)[0],
        function() return widget.triggerswitch end,
        function(value) widget.triggerswitch = value end)

    line = form.addLine("Trigger Delay")
    form.addNumberField(line, nil, 0, 1000,
        function() return widget.tallyDelay end,
        function(value) widget.tallyDelay = value end)

    line = form.addLine("Starting Lifetime Count")
    form.addNumberField(line, nil, 0, 5120,
        function() return widget.newPreset end,
        function(value) widget.newPreset = value end)

    line = form.addLine("Reset all data on reboot")
    form.addBooleanField(line, form.getFieldSlots(line)[0],
        function() return widget.resetOnReboot end,
        function(value)
            widget.resetOnReboot = value
            writeFile(getPath(widget, "ResetOnReboot"), value and 1 or 0)
        end)

    line = form.addLine("Border")
    form.addBooleanField(line, form.getFieldSlots(line)[0],
        function() return widget.border end,
        function(value) widget.border = value end)
end

local function read(widget)
    widget.triggerswitch = storage.read("triggerswitch")
    widget.border = storage.read("border")
    widget.tallyDelay = storage.read("tallyDelay")
end

local function write(widget)
    storage.write("triggerswitch", widget.triggerswitch)
    storage.write("border", widget.border)
    storage.write("tallyDelay", widget.tallyDelay)
end

local function init()
    system.registerWidget({
        key = "flcnt10",
        name = name(),
        create = create,
        paint = paint,
        wakeup = wakeup,
        configure = configure,
        read = read,
        write = write,
        persistent = true
    })
end

return {init = init}
