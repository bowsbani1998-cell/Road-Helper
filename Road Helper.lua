script_name("Road Helper")
script_author("Bows")
script_version("1.0")

local imgui = require "mimgui"
local encoding = require "encoding"
encoding.default = "CP1251"
local u8 = encoding.UTF8
local new = imgui.new

local sizeX, sizeY = getScreenResolution()
if not sizeX or sizeX <= 0 then sizeX, sizeY = 1280, 720 end
local S = math.max(1.0, math.min(sizeY / 540, 2.0))

local logPath = getWorkingDirectory() .. "/RoadHelper_log.txt"
local cfgPath = getWorkingDirectory() .. "/RoadHelper_config.ini"
local logOn = true

local function log(msg)
    if not logOn then return end
    pcall(function()
        local f = io.open(logPath, "a")
        if f then
            f:write(os.date("[%H:%M:%S] ") .. tostring(msg) .. "\n")
            f:close()
        end
    end)
end

local function clearLog()
    pcall(function()
        local f = io.open(logPath, "w")
        if f then
            f:write(os.date("[%H:%M:%S] === start ===\n"))
            f:close()
        end
    end)
end

local ui = { open = false, tab = 1 }

local autoClick   = new.bool(true)
local autoTool    = new.bool(false)
local autoCaptcha = new.bool(true)
local autoRepairs = new.bool(true)
local autoFlip    = new.bool(true)
local flipDelay   = new.float(0.75)

local showCtrl  = new.bool(true)
local showRep   = new.bool(true)
local showStats = new.bool(true)

local ctrlX = new.int(20)
local ctrlY = new.int(math.floor(sizeY / 2 - 30))
local ctrlW = new.int(180)
local ctrlH = new.int(48)

local repX = new.int(20)
local repY = new.int(math.floor(sizeY / 2 + 40))
local repW = new.int(180)
local repH = new.int(48)

local statW = new.int(240)
local statH = new.int(150)

local visTime   = new.bool(true)
local visMoney  = new.bool(true)
local visFrame  = new.bool(true)
local visChests = new.bool(true)
local visTotal  = new.bool(true)

local casePrice = new.int(5000000)

local working = false
local clicker = false
local t0 = 0
local lastMoney = -1

local hold, drag = 0, false
local dox, doy = 0, 0
local rhold, rdrag = 0, false
local rox, roy = 0, 0
local HOLD = 0.35
local TAP = 45

local flipT, flipped = nil, false
local repairsAt = 0

local st = { clicks = 0, money = 0, frame = 0, chests = 0 }

local dirty = false
local savedAt = 0

local function V2(x, y) return imgui.ImVec2(x, y) end
local function V4(r, g, b, a) return imgui.ImVec4(r, g, b, a) end
local COL = 0xFFFFFFFF

local function fmtTime(sec)
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = sec % 60
    if h > 0 then return string.format("%02d:%02d:%02d", h, m, s) end
    return string.format("%02d:%02d", m, s)
end

local function fmtMoney(n)
    local s = tostring(math.floor(n or 0))
    while true do
        local k
        s, k = string.gsub(s, "^(-?%d+)(%d%d%d)", "%1.%2")
        if k == 0 then break end
    end
    return "$" .. s
end

local function workSec()
    if working and t0 > 0 then return os.time() - t0 end
    return 0
end

local function totalMoney()
    return st.money + (st.frame * casePrice[0])
end

local function mark()
    dirty = true
end

local function openRepairs()
    local now = os.clock()
    if now < repairsAt then return end
    repairsAt = now + 5.0
    sampSendChat("/repairs")
    log("repairs")
end

local function qmul(a, b, c, d, w, x, y, z)
    return a * w - b * x - c * y - d * z,
           a * x + b * w + c * z - d * y,
           a * y - b * z + c * w + d * x,
           a * z + b * y - c * x + d * w
end

local function qrot(x, y, z, a, b, c, d)
    local a1, b1, c1, d1 = qmul(a, b, c, d, 0, x, y, z)
    local _, b2, c2, d2 = qmul(a1, b1, c1, d1, a, -b, -c, -d)
    return b2, c2, d2
end

local function upside()
    if not isCharInAnyCar(PLAYER_PED) then return false end
    local ok, r = pcall(function()
        local car = storeCarCharIsInNoSave(PLAYER_PED)
        if getVehicleQuaternion then
            local x, y, z, w = getVehicleQuaternion(car)
            if x and y and z and w then
                local _, _, vz = qrot(0, 0, 1, w, x, y, z)
                return vz < 0
            end
        end
        if isCarUpsidedown then return isCarUpsidedown(car) end
        return false
    end)
    return ok and r == true
end

local function saveCfg()
    pcall(function()
        local f = io.open(cfgPath, "w")
        if not f then return end
        local function b(v) return v and "1" or "0" end
        f:write("ctrlX=" .. ctrlX[0] .. "\n")
        f:write("ctrlY=" .. ctrlY[0] .. "\n")
        f:write("ctrlW=" .. ctrlW[0] .. "\n")
        f:write("ctrlH=" .. ctrlH[0] .. "\n")
        f:write("repX=" .. repX[0] .. "\n")
        f:write("repY=" .. repY[0] .. "\n")
        f:write("repW=" .. repW[0] .. "\n")
        f:write("repH=" .. repH[0] .. "\n")
        f:write("statW=" .. statW[0] .. "\n")
        f:write("statH=" .. statH[0] .. "\n")
        f:write("showCtrl=" .. b(showCtrl[0]) .. "\n")
        f:write("showRep=" .. b(showRep[0]) .. "\n")
        f:write("showStats=" .. b(showStats[0]) .. "\n")
        f:write("visTime=" .. b(visTime[0]) .. "\n")
        f:write("visMoney=" .. b(visMoney[0]) .. "\n")
        f:write("visFrame=" .. b(visFrame[0]) .. "\n")
        f:write("visChests=" .. b(visChests[0]) .. "\n")
        f:write("visTotal=" .. b(visTotal[0]) .. "\n")
        f:write("autoClick=" .. b(autoClick[0]) .. "\n")
        f:write("autoTool=" .. b(autoTool[0]) .. "\n")
        f:write("autoCaptcha=" .. b(autoCaptcha[0]) .. "\n")
        f:write("autoRepairs=" .. b(autoRepairs[0]) .. "\n")
        f:write("autoFlip=" .. b(autoFlip[0]) .. "\n")
        f:write("flipDelay=" .. tostring(flipDelay[0]) .. "\n")
        f:write("casePrice=" .. casePrice[0] .. "\n")
        f:write("money=" .. st.money .. "\n")
        f:write("frame=" .. st.frame .. "\n")
        f:write("chests=" .. st.chests .. "\n")
        f:write("clicks=" .. st.clicks .. "\n")
        f:close()
        dirty = false
        savedAt = os.clock()
        log("cfg")
    end)
end

local function loadCfg()
    pcall(function()
        local f = io.open(cfgPath, "r")
        if not f then
            log("cfg miss")
            return
        end
        for line in f:lines() do
            local k, v = line:match("^([%w_]+)=(.+)$")
            if k and v then
                v = v:gsub("%s+$", "")
                local n = tonumber(v)
                local on = (v == "1")
                if k == "ctrlX" and n then ctrlX[0] = n
                elseif k == "ctrlY" and n then ctrlY[0] = n
                elseif k == "ctrlW" and n then ctrlW[0] = n
                elseif k == "ctrlH" and n then ctrlH[0] = n
                elseif k == "repX" and n then repX[0] = n
                elseif k == "repY" and n then repY[0] = n
                elseif k == "repW" and n then repW[0] = n
                elseif k == "repH" and n then repH[0] = n
                elseif k == "statW" and n then statW[0] = n
                elseif k == "statH" and n then statH[0] = n
                elseif k == "showCtrl" then showCtrl[0] = on
                elseif k == "showRep" then showRep[0] = on
                elseif k == "showStats" then showStats[0] = on
                elseif k == "visTime" then visTime[0] = on
                elseif k == "visMoney" then visMoney[0] = on
                elseif k == "visFrame" then visFrame[0] = on
                elseif k == "visChests" then visChests[0] = on
                elseif k == "visTotal" then visTotal[0] = on
                elseif k == "autoClick" then autoClick[0] = on
                elseif k == "autoTool" then autoTool[0] = on
                elseif k == "autoCaptcha" then autoCaptcha[0] = on
                elseif k == "autoRepairs" then autoRepairs[0] = on
                elseif k == "autoFlip" then autoFlip[0] = on
                elseif k == "flipDelay" and n then flipDelay[0] = math.max(0.1, math.min(3, n))
                elseif k == "casePrice" and n then casePrice[0] = n
                elseif k == "money" and n then st.money = n
                elseif k == "frame" and n then st.frame = n
                elseif k == "chests" and n then st.chests = n
                elseif k == "clicks" and n then st.clicks = n
                elseif k == "stat_money" and n then st.money = n
                elseif k == "stat_frame" and n then st.frame = n
                elseif k == "stat_chests" and n then st.chests = n
                elseif k == "stat_clicks" and n then st.clicks = n
                elseif k == "case_price" and n then casePrice[0] = n
                elseif k == "ctrl_pos_x" and n then ctrlX[0] = n
                elseif k == "ctrl_pos_y" and n then ctrlY[0] = n
                elseif k == "ctrl_width" and n then ctrlW[0] = n
                elseif k == "ctrl_height" and n then ctrlH[0] = n
                elseif k == "rep_pos_x" and n then repX[0] = n
                elseif k == "rep_pos_y" and n then repY[0] = n
                elseif k == "rep_width" and n then repW[0] = n
                elseif k == "rep_height" and n then repH[0] = n
                elseif k == "stats_width" and n then statW[0] = n
                elseif k == "stats_height" and n then statH[0] = n
                elseif k == "show_control" then showCtrl[0] = on
                elseif k == "show_repairs" then showRep[0] = on
                elseif k == "show_stats" then showStats[0] = on
                elseif k == "show_stat_time" then visTime[0] = on
                elseif k == "show_stat_money" then visMoney[0] = on
                elseif k == "show_stat_frame" then visFrame[0] = on
                elseif k == "show_stat_chests" then visChests[0] = on
                elseif k == "show_stat_total" then visTotal[0] = on
                elseif k == "auto_clicker" then autoClick[0] = on
                elseif k == "auto_tool" then autoTool[0] = on
                elseif k == "auto_captcha" then autoCaptcha[0] = on
                elseif k == "auto_open_repairs" then autoRepairs[0] = on
                elseif k == "auto_flip" then autoFlip[0] = on
                elseif k == "flip_delay" and n then flipDelay[0] = math.max(0.1, math.min(3, n))
                end
            end
        end
        f:close()
        log("cfg ok")
    end)
end

local function toggleMenu()
    ui.open = not ui.open
end

local function setWork(on)
    working = on
    if on then
        t0 = os.time()
        lastMoney = -1
        log("start")
        sampAddChatMessage("{00FF00}[Road Helper] Запущен", -1)
    else
        log("stop")
        clicker = false
        saveCfg()
        sampAddChatMessage("{FF5555}[Road Helper] Остановлен", -1)
    end
end

function sendCef(str)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 18)
    raknetBitStreamWriteInt16(bs, #str)
    raknetBitStreamWriteString(bs, str)
    raknetBitStreamWriteInt32(bs, 0)
    raknetSendBitStream(bs)
    raknetDeleteBitStream(bs)
end

function sendClickIface(iid, id, sub, json)
    json = json or ""
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 63)
    raknetBitStreamWriteInt8(bs, iid)
    raknetBitStreamWriteInt32(bs, id or 0)
    raknetBitStreamWriteInt32(bs, sub or 0)
    raknetBitStreamWriteInt32(bs, #json)
    raknetBitStreamWriteString(bs, json)
    if raknetSendBitStreamEx then
        raknetSendBitStreamEx(bs, 1, 10, 1)
    else
        raknetSendBitStream(bs)
    end
    raknetDeleteBitStream(bs)
end

function sendLoaded(iid, on)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 66)
    raknetBitStreamWriteInt8(bs, iid)
    raknetBitStreamWriteBool(bs, on and true or false)
    if raknetSendBitStreamEx then
        raknetSendBitStreamEx(bs, 1, 10, 1)
    else
        raknetSendBitStream(bs)
    end
    raknetDeleteBitStream(bs)
end

function tap()
    sendClickIface(25, 0, 0, "")
    sendCef("clickMinigame")
    st.clicks = st.clicks + 1
    if st.clicks % 10 == 1 then log("tap " .. st.clicks) end
end

function onReceivePacket(id, bs)
    if id ~= 220 then return end
    raknetBitStreamIgnoreBits(bs, 8)
    local p = raknetBitStreamReadInt8(bs)

    if p == 17 then
        raknetBitStreamIgnoreBits(bs, 32)
        local len = raknetBitStreamReadInt16(bs)
        local enc = raknetBitStreamReadInt8(bs)
        local cmd
        if enc == 0 then
            cmd = raknetBitStreamReadString(bs, len)
        else
            cmd = raknetBitStreamDecodeString(bs, len + enc)
        end
        cmd = tostring(cmd or "")
        local low = string.lower(cmd)

        if string.find(low, "click", 1, true) or string.find(low, "find", 1, true)
            or string.find(low, "game", 1, true) or string.find(low, "captcha", 1, true)
            or string.find(low, "minigame", 1, true) or string.find(low, "setactiveview", 1, true)
            or string.find(low, "progress", 1, true) then
            log("cef " .. cmd)
        end

        if string.find(cmd, "Clicker", 1, true)
            or string.find(cmd, "clicker.setProgress", 1, true)
            or string.find(cmd, "clickMinigame", 1, true) then
            if not clicker then log("clicker on") end
            clicker = true
        end

        if string.find(cmd, "event.setActiveView", 1, true) and string.find(cmd, "null", 1, true) then
            if clicker then log("clicker off") end
            clicker = false
        end

        if autoCaptcha[0] and working then
            if string.find(cmd, "FindGame", 1, true) or string.find(cmd, "findGame", 1, true) then
                log("findgame")
                lua_thread.create(function()
                    wait(150)
                    for i = 1, 6 do
                        sendCef("findGame.Success")
                        wait(180)
                    end
                    sendCef("findGame.finish")
                end)
            end
        end

    elseif p == 84 then
        local iid = raknetBitStreamReadInt8(bs)
        local sub = raknetBitStreamReadInt8(bs)
        log("i84 " .. tostring(iid) .. " " .. tostring(sub))
        if iid == 25 and not clicker then
            clicker = true
            log("clicker on")
        end

    elseif p == 62 then
        local iid = raknetBitStreamReadInt8(bs)
        local on = raknetBitStreamReadBool(bs)
        log("i62 " .. tostring(iid) .. " " .. tostring(on))

        if iid == 25 then
            if on then
                clicker = true
                log("clicker on")
            else
                clicker = false
                log("clicker off")
                mark()
            end
        end

        if iid == 81 and on and autoCaptcha[0] and working then
            log("cap on")
            lua_thread.create(function()
                wait(120)
                sendLoaded(81, true)
                for cell = 0, 24 do
                    sendClickIface(81, cell, 0, "")
                    wait(40)
                end
                for i = 1, 8 do
                    sendClickIface(81, 0, 0, "")
                    wait(60)
                end
                log("cap done")
            end)
        end
        if iid == 81 and not on then log("cap off") end
    end
end

local function addChests(clean, low)
    if string.find(low, "frame", 1, true) then return end
    if not (string.find(low, "ларц", 1, true) or string.find(low, "ящик", 1, true)) then return end
    if not (string.find(low, "добавлен", 1, true) or string.find(low, "storage", 1, true) or string.find(low, "хранилищ", 1, true)) then
        return
    end
    local n = tonumber(clean:match("%((%d+)%s*шт")) or 1
    if n < 1 then n = 1 end
    if n > 50 then n = 50 end
    st.chests = st.chests + n
    mark()
    log("chest +" .. n .. " =" .. st.chests)
end

function onServerMessage(color, text)
    if not text then return end
    local clean = tostring(text):gsub("{%x%x%x%x%x%x}", "")
    local low = string.lower(clean)

    if string.find(low, "frame", 1, true) then
        if string.find(low, "добавлен", 1, true)
            or string.find(low, "получили", 1, true)
            or string.find(low, "storage", 1, true)
            or string.find(low, "выпал", 1, true)
            or string.find(low, "получен", 1, true)
        then
            local n = tonumber(clean:match("%((%d+)%s*шт")) or 1
            if n < 1 then n = 1 end
            st.frame = st.frame + n
            mark()
            log("frame +" .. n .. " =" .. st.frame)
            sampAddChatMessage("{00BFFF}[Road Helper] Frame +" .. n .. " (" .. st.frame .. ")", -1)
        end
    else
        addChests(clean, low)
    end

    if string.find(low, "/repairs", 1, true)
        or string.find(low, "новые ямы", 1, true)
        or string.find(low, "образовались новые", 1, true)
    then
        log("pits")
        if autoRepairs[0] then
            lua_thread.create(function()
                wait(300)
                openRepairs()
            end)
        end
    end
end

local function drawDigger(dl, x, y, s)
    local function ln(x1, y1, x2, y2)
        dl:AddLine(V2(x1, y1), V2(x2, y2), COL, math.max(2.2, s * 0.07))
    end
    dl:AddCircleFilled(V2(x + s * 0.38, y + s * 0.13), s * 0.09, COL, 16)
    ln(x + s * 0.36, y + s * 0.22, x + s * 0.30, y + s * 0.46)
    ln(x + s * 0.34, y + s * 0.28, x + s * 0.16, y + s * 0.40)
    ln(x + s * 0.34, y + s * 0.30, x + s * 0.58, y + s * 0.52)
    ln(x + s * 0.30, y + s * 0.46, x + s * 0.14, y + s * 0.70)
    ln(x + s * 0.30, y + s * 0.46, x + s * 0.48, y + s * 0.68)
    ln(x + s * 0.54, y + s * 0.48, x + s * 0.86, y + s * 0.74)
    dl:AddTriangleFilled(
        V2(x + s * 0.70, y + s * 0.62),
        V2(x + s * 0.96, y + s * 0.74),
        V2(x + s * 0.74, y + s * 0.90),
        COL
    )
end

imgui.OnFrame(function() return ui.open end, function(self)
    self.HideCursor = false
    local W = math.min(sizeX * 0.9, 680 * S)
    local H = math.min(sizeY * 0.92, 600 * S)

    imgui.SetNextWindowPos(V2(sizeX / 2, sizeY / 2), imgui.Cond.FirstUseEver, V2(0.5, 0.5))
    imgui.SetNextWindowSize(V2(W, H), imgui.Cond.FirstUseEver)

    imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, 12 * S)
    imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 8 * S)
    imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, 6 * S)
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, V2(12 * S, 12 * S))
    imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, V2(8 * S, 8 * S))

    imgui.PushStyleColor(imgui.Col.WindowBg, V4(0.12, 0.08, 0.05, 0.97))
    imgui.PushStyleColor(imgui.Col.ChildBg, V4(0.15, 0.10, 0.07, 1.00))
    imgui.PushStyleColor(imgui.Col.Button, V4(0.45, 0.28, 0.12, 1.00))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, V4(0.55, 0.35, 0.15, 1.00))
    imgui.PushStyleColor(imgui.Col.ButtonActive, V4(0.65, 0.42, 0.18, 1.00))
    imgui.PushStyleColor(imgui.Col.FrameBg, V4(0.20, 0.14, 0.09, 1.00))
    imgui.PushStyleColor(imgui.Col.CheckMark, V4(0.95, 0.70, 0.25, 1.00))
    imgui.PushStyleColor(imgui.Col.SliderGrab, V4(0.85, 0.55, 0.20, 1.00))
    imgui.PushStyleColor(imgui.Col.Text, V4(0.95, 0.90, 0.80, 1.00))
    imgui.PushStyleColor(imgui.Col.TextDisabled, V4(0.55, 0.50, 0.40, 1.00))
    imgui.PushStyleColor(imgui.Col.Border, V4(0.35, 0.25, 0.15, 0.60))
    imgui.PushStyleColor(imgui.Col.TitleBg, V4(0.18, 0.12, 0.07, 1.00))
    imgui.PushStyleColor(imgui.Col.TitleBgActive, V4(0.22, 0.15, 0.09, 1.00))

    imgui.Begin(u8"Ремонтник Дорог | Helper", nil, imgui.WindowFlags.NoCollapse)

    imgui.BeginChild("##side", V2(150 * S, 0), true)
    local side = imgui.GetWindowDrawList()
    local sp = imgui.GetCursorScreenPos()
    local sw = imgui.GetWindowWidth()
    local icon = 42 * S
    drawDigger(side, sp.x + sw - icon - 8 * S, sp.y, icon)
    imgui.Dummy(V2(0, icon + 4 * S))

    local tabs = {
        {u8"Главная", 1},
        {u8"Настройки", 2},
        {u8"Кнопки", 3},
        {u8"Статистика", 4},
        {u8"Автор", 5}
    }
    for _, tab in ipairs(tabs) do
        local sel = (ui.tab == tab[2])
        if sel then imgui.PushStyleColor(imgui.Col.Button, V4(0.55, 0.35, 0.15, 1.0)) end
        if imgui.Button(tab[1], V2(-1, 34 * S)) then ui.tab = tab[2] end
        if sel then imgui.PopStyleColor() end
        imgui.Spacing()
    end
    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()
    if imgui.Button(u8"Закрыть", V2(-1, 34 * S)) then
        ui.open = false
        saveCfg()
    end
    imgui.EndChild()
    imgui.SameLine()
    imgui.BeginChild("##body", V2(0, 0), true)

    if ui.tab == 1 then
        imgui.TextColored(V4(0.95, 0.75, 0.30, 1), u8"Управление")
        imgui.Separator()
        imgui.Spacing()
        if working then
            imgui.TextColored(V4(0.3, 0.9, 0.4, 1), u8"Статус: РАБОТАЕТ")
        else
            imgui.TextColored(V4(0.9, 0.3, 0.3, 1), u8"Статус: ОСТАНОВЛЕН")
        end
        imgui.Spacing()
        if working then
            if imgui.Button(u8"ОСТАНОВИТЬ", V2(180 * S, 42 * S)) then setWork(false) end
        else
            if imgui.Button(u8"СТАРТ", V2(180 * S, 42 * S)) then setWork(true) end
        end
        imgui.Spacing()
        if imgui.Button(u8"Места ремонта", V2(180 * S, 36 * S)) then
            repairsAt = 0
            openRepairs()
        end

    elseif ui.tab == 2 then
        imgui.TextColored(V4(0.95, 0.75, 0.30, 1), u8"Настройки")
        imgui.Separator()
        imgui.Spacing()
        if imgui.Checkbox(u8"Автокликер", autoClick) then mark() end
        imgui.Spacing()
        if imgui.Checkbox(u8"Авто-капча", autoCaptcha) then mark() end
        imgui.Spacing()
        if imgui.Checkbox(u8"Авто-инструмент", autoTool) then mark() end
        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()
        imgui.TextColored(V4(0.95, 0.75, 0.30, 1), u8"Новые ямы")
        if imgui.Checkbox(u8"Авто /repairs", autoRepairs) then mark() end
        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()
        imgui.TextColored(V4(0.95, 0.75, 0.30, 1), u8"AutoFlip")
        if imgui.Checkbox(u8"Включить AutoFlip", autoFlip) then
            mark()
            flipT, flipped = nil, false
        end
        imgui.Text(u8"Задержка (сек):")
        if imgui.SliderFloat("##fd", flipDelay, 0.1, 3.0, "%.2f") then mark() end
        imgui.Spacing()
        if imgui.Button(u8"Сохранить", V2(160 * S, 32 * S)) then
            saveCfg()
            sampAddChatMessage("{00BFFF}[Road Helper] Сохранено", -1)
        end

    elseif ui.tab == 3 then
        imgui.TextColored(V4(0.95, 0.75, 0.30, 1), u8"Кнопки на экране")
        imgui.Separator()
        imgui.Spacing()
        imgui.TextColored(V4(0.95, 0.75, 0.30, 1), u8"Старт / Стоп")
        if imgui.Checkbox(u8"Показывать Старт/Стоп", showCtrl) then mark() end
        if showCtrl[0] then
            imgui.Text(u8"X")
            if imgui.SliderInt("##cpx", ctrlX, 0, sizeX - 50) then mark() end
            imgui.Text(u8"Y")
            if imgui.SliderInt("##cpy", ctrlY, 0, sizeY - 50) then mark() end
            imgui.Text(u8"Ширина")
            if imgui.SliderInt("##cw", ctrlW, 100, 300) then mark() end
            imgui.Text(u8"Высота")
            if imgui.SliderInt("##ch", ctrlH, 36, 80) then mark() end
            imgui.TextDisabled(u8"Зажми 0.4 сек и двигай")
        end
        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()
        imgui.TextColored(V4(0.95, 0.75, 0.30, 1), u8"Места ремонта")
        if imgui.Checkbox(u8"Показывать МЕСТА", showRep) then mark() end
        if showRep[0] then
            imgui.Text(u8"X")
            if imgui.SliderInt("##rpx", repX, 0, sizeX - 50) then mark() end
            imgui.Text(u8"Y")
            if imgui.SliderInt("##rpy", repY, 0, sizeY - 50) then mark() end
            imgui.Text(u8"Ширина")
            if imgui.SliderInt("##rw", repW, 100, 300) then mark() end
            imgui.Text(u8"Высота")
            if imgui.SliderInt("##rh", repH, 36, 80) then mark() end
        end
        imgui.Spacing()
        if imgui.Button(u8"Сохранить кнопки", V2(180 * S, 32 * S)) then
            saveCfg()
            sampAddChatMessage("{00BFFF}[Road Helper] Кнопки сохранены", -1)
        end

    elseif ui.tab == 4 then
        imgui.TextColored(V4(0.95, 0.75, 0.30, 1), u8"Статистика")
        imgui.Separator()
        imgui.Spacing()
        if imgui.Checkbox(u8"Окно статистики", showStats) then mark() end
        if showStats[0] then
            imgui.Text(u8"Ширина")
            if imgui.SliderInt("##sw", statW, 180, 360) then mark() end
            imgui.Text(u8"Высота")
            if imgui.SliderInt("##sh", statH, 100, 300) then mark() end
            if imgui.Checkbox(u8"Время", visTime) then mark() end
            if imgui.Checkbox(u8"Деньги", visMoney) then mark() end
            if imgui.Checkbox(u8"Frame", visFrame) then mark() end
            if imgui.Checkbox(u8"Ларцы", visChests) then mark() end
            if imgui.Checkbox(u8"ИТОГО", visTotal) then mark() end
        end
        imgui.Spacing()
        imgui.Text(u8"Цена Frame ($):")
        imgui.PushItemWidth(180 * S)
        if imgui.InputInt("##cp", casePrice, 100000, 1000000) then mark() end
        imgui.PopItemWidth()
        imgui.Spacing()
        imgui.Text(u8"Время: " .. fmtTime(workSec()))
        imgui.Text(u8"Система: " .. fmtMoney(st.money))
        imgui.Text(u8"Frame: " .. st.frame)
        imgui.Text(u8"Ларцы: " .. st.chests)
        imgui.TextColored(V4(0.3, 0.95, 0.45, 1), u8"ИТОГО: " .. fmtMoney(totalMoney()))
        imgui.Spacing()
        if imgui.Button(u8"Сбросить статистику", V2(180 * S, 30 * S)) then
            st.clicks, st.money, st.frame, st.chests = 0, 0, 0, 0
            lastMoney = -1
            t0 = working and os.time() or 0
            saveCfg()
            log("reset")
        end

    elseif ui.tab == 5 then
        imgui.TextColored(V4(0.95, 0.75, 0.30, 1), u8"Автор")
        imgui.Separator()
        imgui.Spacing()
        imgui.Text(u8"Скрипт: Road Helper")
        imgui.Text(u8"Версия: 1.0")
        imgui.Text(u8"Автор: Bows")
        imgui.Text(u8"Платформа: NeomLoader")
    end

    imgui.EndChild()
    imgui.End()
    imgui.PopStyleColor(13)
    imgui.PopStyleVar(5)
end)

imgui.OnFrame(function() return showCtrl[0] end, function(self)
    self.HideCursor = false
    local W, H = ctrlW[0], ctrlH[0]
    local io = imgui.GetIO()
    if drag then
        if imgui.IsMouseDown(0) then
            ctrlX[0] = math.floor(io.MousePos.x - dox)
            ctrlY[0] = math.floor(io.MousePos.y - doy)
            if ctrlX[0] < 0 then ctrlX[0] = 0 end
            if ctrlY[0] < 0 then ctrlY[0] = 0 end
            if ctrlX[0] > sizeX - W then ctrlX[0] = sizeX - W end
            if ctrlY[0] > sizeY - H then ctrlY[0] = sizeY - H end
        else
            drag = false
            hold = 0
            mark()
            saveCfg()
        end
    end
    imgui.SetNextWindowPos(V2(ctrlX[0], ctrlY[0]), imgui.Cond.Always)
    imgui.SetNextWindowSize(V2(W, H), imgui.Cond.Always)
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, H / 2)
    imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, H / 2 - 2)
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowBorderSize, 0)
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, V2(0, 0))
    imgui.PushStyleVarVec2(imgui.StyleVar.FramePadding, V2(0, 0))
    if working then
        imgui.PushStyleColor(imgui.Col.WindowBg, V4(0.12, 0.45, 0.22, 0.95))
        imgui.PushStyleColor(imgui.Col.Button, V4(0.15, 0.55, 0.28, 0.0))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, V4(0.18, 0.65, 0.32, 0.3))
        imgui.PushStyleColor(imgui.Col.ButtonActive, V4(0.20, 0.70, 0.35, 0.5))
    else
        imgui.PushStyleColor(imgui.Col.WindowBg, V4(0.45, 0.12, 0.15, 0.95))
        imgui.PushStyleColor(imgui.Col.Button, V4(0.55, 0.15, 0.18, 0.0))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, V4(0.65, 0.18, 0.22, 0.3))
        imgui.PushStyleColor(imgui.Col.ButtonActive, V4(0.70, 0.20, 0.25, 0.5))
    end
    imgui.PushStyleColor(imgui.Col.Text, V4(1, 1, 1, 1))
    local flags = imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoResize
    imgui.Begin("##ctl", nil, flags)
    local label = working and u8"СТОП" or u8"СТАРТ"
    local hit = imgui.Button(label, V2(W, H))
    if imgui.IsItemActive() and not drag then
        hold = hold + io.DeltaTime
        if hold >= HOLD then
            drag = true
            dox = io.MousePos.x - ctrlX[0]
            doy = io.MousePos.y - ctrlY[0]
        end
    elseif not imgui.IsItemActive() and not drag then
        hold = 0
    end
    if hit and not drag and hold < HOLD then setWork(not working) end
    imgui.End()
    imgui.PopStyleColor(5)
    imgui.PopStyleVar(5)
end)

imgui.OnFrame(function() return showRep[0] end, function(self)
    self.HideCursor = false
    local W, H = repW[0], repH[0]
    local io = imgui.GetIO()
    if rdrag then
        if imgui.IsMouseDown(0) then
            repX[0] = math.floor(io.MousePos.x - rox)
            repY[0] = math.floor(io.MousePos.y - roy)
            if repX[0] < 0 then repX[0] = 0 end
            if repY[0] < 0 then repY[0] = 0 end
            if repX[0] > sizeX - W then repX[0] = sizeX - W end
            if repY[0] > sizeY - H then repY[0] = sizeY - H end
        else
            rdrag = false
            rhold = 0
            mark()
            saveCfg()
        end
    end
    imgui.SetNextWindowPos(V2(repX[0], repY[0]), imgui.Cond.Always)
    imgui.SetNextWindowSize(V2(W, H), imgui.Cond.Always)
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, H / 2)
    imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, H / 2 - 2)
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowBorderSize, 0)
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, V2(0, 0))
    imgui.PushStyleVarVec2(imgui.StyleVar.FramePadding, V2(0, 0))
    imgui.PushStyleColor(imgui.Col.WindowBg, V4(0.15, 0.35, 0.55, 0.95))
    imgui.PushStyleColor(imgui.Col.Button, V4(0.18, 0.40, 0.60, 0.0))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, V4(0.22, 0.48, 0.70, 0.3))
    imgui.PushStyleColor(imgui.Col.ButtonActive, V4(0.25, 0.55, 0.80, 0.5))
    imgui.PushStyleColor(imgui.Col.Text, V4(1, 1, 1, 1))
    local flags = imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoResize
    imgui.Begin("##rep", nil, flags)
    local hit = imgui.Button(u8"МЕСТА", V2(W, H))
    if imgui.IsItemActive() and not rdrag then
        rhold = rhold + io.DeltaTime
        if rhold >= HOLD then
            rdrag = true
            rox = io.MousePos.x - repX[0]
            roy = io.MousePos.y - repY[0]
        end
    elseif not imgui.IsItemActive() and not rdrag then
        rhold = 0
    end
    if hit and not rdrag and rhold < HOLD then
        repairsAt = 0
        openRepairs()
    end
    imgui.End()
    imgui.PopStyleColor(5)
    imgui.PopStyleVar(5)
end)

imgui.OnFrame(function() return showStats[0] end, function(self)
    self.HideCursor = false
    local W, H = statW[0], statH[0]
    imgui.SetNextWindowSize(V2(W, H), imgui.Cond.Always)
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, 10 * S)
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowBorderSize, 0)
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, V2(12 * S, 10 * S))
    imgui.PushStyleColor(imgui.Col.WindowBg, V4(0.10, 0.07, 0.05, 0.94))
    imgui.PushStyleColor(imgui.Col.Text, V4(0.95, 0.90, 0.80, 1.00))
    imgui.PushStyleColor(imgui.Col.TitleBg, V4(0.18, 0.12, 0.07, 1.00))
    imgui.PushStyleColor(imgui.Col.TitleBgActive, V4(0.22, 0.15, 0.09, 1.00))
    local flags = imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoResize
    imgui.Begin(u8"Статистика", nil, flags)
    if visTime[0] then
        local c = working and V4(0.3, 0.95, 0.45, 1) or V4(0.95, 0.75, 0.30, 1)
        imgui.TextColored(c, u8"Время: " .. fmtTime(workSec()))
    end
    if visMoney[0] then imgui.Text(u8"Система: " .. fmtMoney(st.money)) end
    if visFrame[0] then
        imgui.Text(u8"Frame: " .. st.frame .. u8" (" .. fmtMoney(st.frame * casePrice[0]) .. ")")
    end
    if visChests[0] then imgui.Text(u8"Ларцы: " .. st.chests) end
    if visTotal[0] then
        imgui.Separator()
        imgui.TextColored(V4(0.3, 0.95, 0.45, 1), u8"ИТОГО: " .. fmtMoney(totalMoney()))
    end
    imgui.End()
    imgui.PopStyleColor(4)
    imgui.PopStyleVar(3)
end)

function main()
    while not isSampAvailable() do wait(100) end
    clearLog()
    loadCfg()
    log("load 1.0")
    sampRegisterChatCommand("rh", toggleMenu)
    sampAddChatMessage("{00BFFF}[Road Helper] Загружен. /rh | v1.0", -1)

    local moneyAt = 0
    while true do
        wait(0)

        if working and autoClick[0] and clicker then
            tap()
            wait(TAP)
        end

        if working then
            local now = os.clock()
            if now - moneyAt >= 0.25 then
                moneyAt = now
                local ok, money = pcall(getPlayerMoney, PLAYER_PED)
                if ok and money then
                    if lastMoney == -1 then
                        lastMoney = money
                    elseif money > lastMoney then
                        local d = money - lastMoney
                        if d > 0 and d < 50000000 then
                            st.money = st.money + d
                            mark()
                            log("money +" .. d)
                        end
                        lastMoney = money
                    else
                        lastMoney = money
                    end
                end
            end
        end

        if autoFlip[0] then
            if upside() then
                if not flipT then flipT = os.clock() end
                if not flipped and (os.clock() - flipT) >= flipDelay[0] then
                    flipped = true
                    sampSendChat("/domkrat")
                    log("flip")
                end
            else
                flipT, flipped = nil, false
            end
        end

        if dirty and (os.clock() - savedAt) > 3 then saveCfg() end
    end
end

function onScriptTerminate(scr, quit)
    if scr == thisScript() then saveCfg() end
end