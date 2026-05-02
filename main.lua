--- Flights widget 2.0.1

--[[
How to install and set up flights2.0.1 

 !!!!!!!!!!!!!!!!!!!! BEFORE STARTING THIS INSTALL, BACK EVERYTHING UP !!!!!!!!!!!!!!!!!!!!!
                !!!!!!!!!!!!!!!!!!!!! DO IT NOW !!!!!!!!!!!!!!!!!!!!!!!!!!!!
                    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

Disclaimer: By installing this lua script, you agree that the author will not be responsible for any damages or injuries; monetary or other losses; and that the author does not guarantee or imply that the lua script will work on your equipment. The lua script is provided “as is," and you use it at your own risk. The author makes no warranties as to performance, merchantability, fitness for a particular purpose, or any other warranties whether expressed or implied.

--------------------------------------------------------------------------------------------------------------------


1. Copy the Flights 2_01 folder to the scripts folder of your transmitter. Everything needed to run Flights 2.0.1 is included in this folder.

2. Touch Configure Screens, and then touch Change Widget in the widget location that will be used for Flights 2.0.1.lua. 

3. In the Change Widget menu, scroll to and select, Flights 2.0.1. Configure Widget will be highlighted. Touch this area (or press enter). 

4.  Title
    This turns the widget title ON/OFF.

5. Trigger Switch
   This switch advances the flight count when activated. Any physical or logical switch can be used. For electric aircraft, I prefer to use the arming switch for this purpose. On wet powered aircraft or gliders, I have used the gear up switch, an altitude of 20 feet above the ground, throttle above idle, etc.
   
6. Trigger Delay
   This allows the Trigger Switch to be activated for a short periods time (the value of Trigger Delay) without triggering the flight counter. 
   NOTE: The display will blink red/green during the delay period. 
   
7. Announce Switch
   This switch will play the current number of flights when activated. 

8. Preset
   If the aircraft already has several flights, you can enter this number into the Preset area. 
   NOTE: To reset the flights count and preset to 0; first, turn transmitter off and then back on. Set Preset to -1. Turn the transmitter off and then back on.

9. Play Sounds
    If this selection is ON, the Flights Widget will announce the number of flights when the count is advanced, or when the Announce Switch is activated.

10. Border
    If this selection is ON, a border will be drawn around the widget area.

Note: Flights 2.0.1 can only be triggered one time for each session. The transmitter must be turned off and back on before another flight will be counted. This prevents false counts being triggered.

--]]

local translations = {en="Flights 2.0.1", fr="Vols 2.0.1"}

local function name(widget)
    local locale = system.getLocale()
    return translations[locale] or translations["en"]
end

local function create()
    return {value=0, triggerswitch=nil, announceswitch=nil, announceswitchdone = 0, switchactive = 0, tally = 0, preset = 0, newPreset = 0, soundmode=false, announceit = 1, teser1 = system.getSource({category=CATEGORY_SWITCH_POSITION, member=23}), teser2 =system.getSource({category=CATEGORY_SWITCH_POSITION, member=26}), teser3 = system.getSource({category=CATEGORY_SWITCH_POSITION, member=29}), announced = 0, modelName = "nil", ini = true, radio = "", muteatStart = true, newFlight = nil, border = false, tallydelayStart = 0, tallyDelay = 0, triggerOn = false, color = lcd.RGB(0x00, 0xFC, 0x00), newColor = lcd.RGB(0x00, 0x00, 0x00), color1=lcd.RGB(0xE8, 0x5C, 0x00), color2 =lcd.RGB(0x00, 0xFC, 0x00)}
end

local function announcenumberofflights(widget)
  if not widget.muteatStart then
    if widget.soundmode then
      if widget.newFlight then
        system.playFile("/scripts/Flights 2_01/sounds/fltnum.wav")
        system.playNumber(widget.preset + widget.tally)
      else
        system.playNumber(widget.preset + widget.tally)
        system.playFile("/scripts/Flights 2_01/sounds/Flghts.wav")
      end
    end
  else
    widget.muteatStart = false
  end
end

local function paint(widget)
  if lcd.isVisible() then
    local w, h = lcd.getWindowSize()

    -- Define positions
    if h < 50 then
        lcd.font(FONT_XS)
    elseif h < 80 then
        lcd.font(FONT_S)
    elseif h > 170 then
        lcd.font(FONT_XL)
    else
        lcd.font(FONT_STD)
    end
    
    if widget.radio == "14" then
      lcd.font(FONT_XS)
    end

    local text_w, text_h = lcd.getTextSize("")
    local box_top, box_height = text_h, h - text_h - 4
    local box_left, box_width = 4, w - 8
 
    if lcd.darkMode() then
      lcd.color(WHITE)
    else
      lcd.color(COLOR_BLACK)
    end

    local border_w, border_h = lcd.getWindowSize("")
    if widget.border then
      lcd.drawRectangle(0,0,border_w,border_h)
    end

    -- display number of flights
    lcd.drawText(box_left + box_width / 2, border_h / 6, widget.modelName, CENTERED)
    lcd.font(FONT_STD)
    
    if widget.triggerswitch ~= nil and widget.triggerswitch:state() and widget.switchactive == 0 then
 --   if widget.switchactive == 0 then
      lcd.color(widget.color)
  --    system.playTone(1500,50)
      else if lcd.darkMode() then
        lcd.color(WHITE)
      else
        lcd.color(COLOR_BLACK)
      end
    end
      
    lcd.drawText(box_left + box_width / 2, (border_h / 6) * 3, math.floor(widget.preset + widget.tally).." Flights", CENTERED)
  end
--  system.playTone(1500,50)
end

function toggle(y, C1, C2)
  
  -- Flip back and forth every y seconds
			if os.clock() % (y*2) < y then
       color=C1
      else
       color=C2
      end
      return color;
   
end

local function wakeup(widget)
  if widget.ini then
    widget.ini = false
 --   system.playTone(1500,50)
 
 widget.modelName = model.name()
 
 local board = system.getVersion().board
    if string.find(board,"10") then
      widget.radio = "10"
    end
    if string.find(board,"12") then
      widget.radio = "12"
    end
    if string.find(board,"14") then
      widget.radio = "14"
    end
    if string.find(board,"20") then
      widget.radio = "20"
    end
    if string.find(board,"18") then
      widget.radio = "18"
    end
    if string.find(board,"TWXLITE") then
      widget.radio = "TWXLITE"
    end
    if string.find(board,"XE") then
      widget.radio = "XE"
    end
 
    file = io.open("/scripts/Flights 2_01/Files/" .. widget.modelName .. "-Preset.txt", "a") 
    file:write(" ")
    file:close()
    
    file = io.open("/scripts/Flights 2_01/Files/" .. widget.modelName .. "-Preset.txt", "r")
    local ft = file:read("*line")
    file:close()
    
    if ft == " " then
     file = io.open("/scripts/Flights 2_01/Files/" .. widget.modelName .. "-Preset.txt", "w") 
     file:write(0)
     file:close()
    else
      widget.preset = ft
      widget.newPreset = ft
   --   system.playTone(1500,50)
    end
    
    file = io.open("/scripts/Flights 2_01/Files/" .. widget.modelName .. "-Tally.txt", "a") 
    file:write(" ")
    file:close()
    
    file = io.open("/scripts/Flights 2_01/Files/" .. widget.modelName .. "-Tally.txt", "r")
    ft = file:read("*line")
    file:close()
    
    if ft == " " then
     file = io.open("/scripts/Flights 2_01/Files/" .. widget.modelName .. "-Tally.txt", "w") 
     file:write(0)
     file:close()
    else
      widget.tally = ft
  --    system.playTone(1000,50)
    end
    
  end
  
  -- for testing
  if widget.teser1:state() and widget.teser2:state() and widget.teser3:state() then
    if widget.switchactive == 1 then
      system.playTone(1000,50)
      widget.switchactive = 0
    end
  end
  
  if widget.announceswitch ~= nil and widget.announceswitch:state() then
    if widget.announceswitchdone == 0 then
      if widget.soundmode then
    --    system.playNumber(widget.preset + widget.tally)
        widget.newFlight = false
        announcenumberofflights(widget)
      end
      widget.announceswitchdone=1
    end
  else
    widget.announceswitchdone = 0
  end
  
  if widget.triggerswitch ~= nil and widget.triggerswitch:state() and widget.switchactive == 0 then
    
    widget.newColor = toggle(.5,widget.color1, widget.color2 )
    if widget.color ~= widget.newColor then
      widget.color = widget.newColor
 --   system.playTone(2000,50)
      lcd.invalidate()
    end 
    
 --  lcd.invalidate()
    widget.triggerOn = true
 --   system.playTone(1500,50)
  else
    if widget.triggerOn then
      widget.triggerOn = false
      lcd.invalidate()
 --     system.playTone(1500,50)
    end
  end
  
  if widget.triggerswitch ~= nil and not widget.triggerswitch:state() then
    if widget.announced == 0 and (widget.soundmode) then
      widget.announced = 1
    end
    widget.tallydelayStart = 0
  else
    if widget.tallydelayStart == 0 then
      widget.tallydelayStart = math.floor(os.clock())
    end
    if widget.switchactive == 0 and math.floor(os.clock()) >= widget.tallydelayStart + widget.tallyDelay then
   --   system.playTone(1000,50)
      widget.announced = 0
      if widget.switchactive == 0 then
        widget.tally = widget.tally + 1
        widget.announceit = 1
        widget.switchactive = 1
        file = io.open("/scripts/Flights 2_01/Files/" .. widget.modelName .. "-Tally.txt", "w") 
        file:write(widget.tally)
        file:close()
       lcd.invalidate()
      end
    end
  end
  if widget.announceit == 1 then
    if (widget.soundmode) then
    widget.newFlight = true
      announcenumberofflights(widget)
    end
    widget.announceit = 0
  end
  if widget.preset ~= widget.newPreset then
    widget.preset = widget.newPreset
    file = io.open("/scripts/Flights 2_01/Files/" .. widget.modelName .. "-Preset.txt", "w") 
    file:write(widget.preset)
    file:close()
  end
  
  if widget.newPreset == -1 then
    system.playTone(1500,50)
      widget.tally = 0
      widget.preset = 0
      widget.newPreset = 0
      
     file = io.open("/scripts/Flights 2_01/Files/" .. widget.modelName .. "-Preset.txt", "w") 
     file:write(0)
     file:close()
      
     file = io.open("/scripts/Flights 2_01/Files/" .. widget.modelName .. "-Tally.txt", "w") 
     file:write(0)
     file:close()
      
    end
  
end

local function configure(widget)
    
    -- Trigger switch position
    line = form.addLine("Trigger Switch")
    form.addSwitchField(line, form.getFieldSlots(line)[0], function() return widget.triggerswitch end, function(value) widget.triggerswitch = value end)
    
    -- trigger delay enter
    line = form.addLine("Trigger Delay")
    form.addNumberField(line, nil,0, 1000, function() return widget.tallyDelay end, function(value) widget.tallyDelay = value end)
    
        -- announce switch position
    line = form.addLine("Announce Switch")
    form.addSwitchField(line, form.getFieldSlots(line)[0], function() return widget.announceswitch end, function(value) widget.announceswitch = value end)
    
    -- preset enter
    line = form.addLine("Preset")
    form.addNumberField(line, nil,-1, 5120, function() return widget.newPreset end, function(value) widget.newPreset = value end)
    
    line = form.addLine("Play Sounds")
    form.addBooleanField(line, form.getFieldSlots(line)[0], function() return widget.soundmode end, function(value) widget.soundmode = value end)
    
    line = form.addLine("Border")
    form.addBooleanField(line, form.getFieldSlots(line)[0], function() return widget.border end, function(value) widget.border = value end)

end

local function read(widget)
        widget.triggerswitch = storage.read("triggerswitch")
        widget.soundmode = storage.read("soundmode")
        widget.announceswitch = storage.read("announceswitch")
        widget.border = storage.read("border")
        widget.tallyDelay = storage.read("tallyDelay")
end

local function write(widget)
        storage.write("triggerswitch",widget.triggerswitch)
        storage.write("soundmode",widget.soundmode)
        storage.write("announceswitch",widget.announceswitch)
        storage.write("border",widget.border)
        storage.write("tallyDelay",widget.tallyDelay)
end

local function init()
    system.registerWidget({key="flgts20", name=name, create=create, paint=paint, wakeup=wakeup, configure=configure, read=read, write=write, persistent=true})
end

return {init=init}
