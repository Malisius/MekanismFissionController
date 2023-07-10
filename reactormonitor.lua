local mon
local monx, mony
local t
local modem
local borderMargin = 0
local currentRF = 30000
local maxRF = 500000
local currentBurnRate = 2
local maxBurnRate = 40
local currentTemp = 300
local maxTemp = 1000
local currentFuel = 100
local maxFuel = 134
local args = { ... }

--returns the side that a given peripheral type is connected to
local function getPeripheral(name)
    for i, v in pairs(peripheral.getNames()) do
        if (peripheral.getType(v) == name) then
            return v
        end
    end
    return ""
end

--Draw a single point
local function drawPoint(x, y, color)
    local ix, iy = mon.getCursorPos()
    mon.setCursorPos(x, y)
    mon.setBackgroundColor(color)
    mon.write(" ")
    mon.setBackgroundColor(colors.black)
    mon.setCursorPos(ix, iy)
end

--Draw a box with no fill
local function drawBox(size, xoff, yoff, color)
    local x, y = mon.getCursorPos()
    mon.setBackgroundColor(color)
    for i = 0, size[1] - 1 do
        mon.setCursorPos(xoff + i + 1, yoff + 1)
        mon.write(" ")
        mon.setCursorPos(xoff + i + 1, yoff + size[2])
        mon.write(" ")
    end
    for i = 0, size[2] - 1 do
        mon.setCursorPos(xoff + 1, yoff + i + 1)
        mon.write(" ")
        mon.setCursorPos(xoff + size[1], yoff + i + 1)
        mon.write(" ")
    end
    mon.setCursorPos(x, y)
    mon.setBackgroundColor(colors.black)
end

--Draw a filled box
local function drawFilledBox(size, xoff, yoff, colorOut, colorIn)
    local horizLine = ""
    for i = 2, size[1] - 1 do
        horizLine = horizLine .. " "
    end
    drawBox(size, xoff, yoff, colorOut)
    local x, y = mon.getCursorPos()
    mon.setBackgroundColor(colorIn)
    for i = 2, size[2] - 1 do
        mon.setCursorPos(xoff + 2, yoff + i)
        mon.write(horizLine)
    end
    mon.setBackgroundColor(colors.black)
    mon.setCursorPos(x, y)
end

--Draw a border around the screen with an optional margin
local function drawBorder(margin, color)
    size = { monx - (margin * 2), mony - (margin * 2) }
    drawBox(size, margin, margin, color)
end

--Draws text on the screen
local function drawText(text, x1, y1, backColor, textColor)
    if (monSide ~= nil) then
        local x, y = mon.getCursorPos()
        mon.setCursorPos(x1, y1)
        mon.setBackgroundColor(backColor)
        mon.setTextColor(textColor)
        mon.write(text)
        mon.setTextColor(colors.white)
        mon.setBackgroundColor(colors.black)
        mon.setCursorPos(x, y)
    end
end

--Resets the monitor
local function resetMon()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    mon.setCursorPos(1, 1)
end

--Convert string to array
local function strToArray(str)
    t = {}
    for i = 1, string.len(str) do
        t[i] = (string.sub(str, i, i))
    end
end

--Format numerical rf value to string with suffix
local function format(num)
    if (num >= 1000000000) then
        return string.format("%1.3f G", num / 1000000000)
    elseif (num >= 1000000) then
        return string.format("%1.3f M", num / 1000000)
    elseif (num >= 1000) then
        return string.format("%1.3f K", num / 1000)
    elseif (num >= 1) then
        return string.format("%1.3f ", num)
    elseif (num >= .001) then
        return string.format("%1.3f m", num * 1000)
    elseif (num >= .000001) then
        return string.format("%1.3f u", num * 1000000)
    else
        return string.format("%1.3f ", 0)
    end
end

--Initialize program
local function initialize()
    --Grab command line args
    --First arg will be borderMargin
    borderMargin = args[1] or borderMargin

    print('Searching for monitor...')
    monSide = getPeripheral('monitor')
    if (monSide ~= "") then
        mon = peripheral.wrap(monSide)
        print('Found monitor, switching output')
        mon.setTextScale(0.5)
    else
        monSide = 'term'
        mon = term
    end
    monx, mony = mon.getSize()
    resetMon()
    drawBorder(borderMargin, colors.green)

    --Load the api, or grab it from pastebin if we don't have it
    if pcall(os.loadAPI('/touchpoint.lua')) then
        print('Already have touchpoint api')
    else
        print('Downloading touchpoint api...')
        os.run({}, "pastebin get pFHeia96 touchpoint.lua")
        os.loadAPI("/touchpoint.lua")
    end
    t = touchpoint.new(monSide)
    t:add("Toggle Reactor", nil, borderMargin + 3, mony - borderMargin - 4, (monx / 2) - 1, mony - borderMargin - 2,
        colors.red, colors.lime)
    t:add("-1 Max Burn Rate", nil, borderMargin + 3 + math.floor(monx / 2), mony - borderMargin - 2,
        monx - borderMargin - 2, mony - borderMargin - 2, colors.blue, colors.lime)
    t:add("+1 Max Burn Rate", nil, borderMargin + 3 + math.floor(monx / 2), mony - borderMargin - 4,
        monx - borderMargin - 2, mony - borderMargin - 4, colors.blue, colors.lime)
    t:draw()

    modem = peripheral.find('modem')
    if modem then
        modem.open(123)
    end
end

initialize()

while true do
    local event, p1, p2, p3, p4, p5 = t:handleEvents(os.pullEvent())

    if event == 'button_click' then
        if (p1 == "+1 Max Burn Rate") then
            t:flash(p1)
        end
        if (p1 == "-1 Max Burn Rate") then
            t:flash(p1)
        end
        if (p1 == "Toggle Reactor") then
            t:toggleButton(p1)
        end
    end
    if event == 'modem_message' then

    end

    --Redraw current reactor/turbine/matrix status
    barLength = monx - 4 - (borderMargin * 2)

    mon.setCursorPos(3 + borderMargin, 3 + borderMargin)
    mon.setTextColor(colors.white)
    mon.setBackgroundColor(colors.black)
    mon.write('Reactor Status: Awaiting Signal')

    mon.setCursorPos(3 + borderMargin, 5 + borderMargin)
    mon.write('Stored Power: ' .. format(currentRF) .. '/' .. format(maxRF))
    for i = 1, barLength, 1 do
        if (currentRF / maxRF) * barLength >= i then
            mon.setBackgroundColor(colors.lime)
        else
            mon.setBackgroundColor(colors.blue)
        end
        mon.setCursorPos(2 + borderMargin + i, 6 + borderMargin)
        mon.write(" ")
    end

    mon.setTextColor(colors.white)
    mon.setBackgroundColor(colors.black)
    mon.setCursorPos(3 + borderMargin, 8 + borderMargin)
    mon.write('Stored Fuel: ' .. string.format(currentFuel) .. ' mb')
    for i = 1, barLength, 1 do
        if (currentFuel / maxFuel) * barLength >= i then
            mon.setBackgroundColor(colors.lime)
        else
            mon.setBackgroundColor(colors.blue)
        end
        mon.setCursorPos(2 + borderMargin + i, 9 + borderMargin)
        mon.write(" ")

        mon.setTextColor(colors.white)
        mon.setBackgroundColor(colors.black)
        mon.setCursorPos(3 + borderMargin, 11 + borderMargin)
        mon.write('Current Temperature: ' .. string.format(currentTemp) .. ' F')
        for i = 1, barLength, 1 do
            if (currentTemp / maxTemp) * barLength >= i then
                mon.setBackgroundColor(colors.lime)
            else
                mon.setBackgroundColor(colors.blue)
            end
            mon.setCursorPos(2 + borderMargin + i, 12 + borderMargin)
            mon.write(" ")
        end
    end
end
