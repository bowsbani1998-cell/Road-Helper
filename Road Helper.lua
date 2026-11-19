script_name("Road Helper")
script_author("Bows")
script_version("1.1")

local VER = "1.1"
local note = { on = false, t = 0, msg = "" }

local imgui = require "mimgui"
local encoding = require "encoding"
encoding.default = "CP1251"
local u8 = encoding.UTF8
local new = imgui.new

local sizeX, sizeY = getScreenResolution()
if not sizeX or sizeX <= 0 then sizeX, sizeY = 1280, 720 end
local S = math.max(1.0, math.min(sizeY / 540, 2.0))

local cfgPath = getWorkingDirectory() .. "/RoadHelper_config.ini"

-- Внутренние диагностические вызовы оставлены совместимыми, но файл лога не создаётся.
local function log(_) end

local ui = { open = false, tab = 1 }
ui.settingsPage = 1 -- 1: кнопки, 2: интерфейс
ui.theme = 1
ui.touchScroll = { down = false, lastY = 0 }

-- Три цветовые схемы главного меню: исходная синяя, графитовая и фиолетовая.
RH_UI_THEMES = {
    {
        name = "NEON BLUE",
        window = {0.012, 0.022, 0.045, 0.99}, child = {0.020, 0.043, 0.080, 0.99},
        button = {0.035, 0.105, 0.190, 1.00}, hover = {0.045, 0.205, 0.355, 1.00}, active = {0.025, 0.310, 0.560, 1.00},
        frame = {0.030, 0.085, 0.145, 1.00}, accent = {0.12, 0.68, 1.00, 1.00}, grab = {0.05, 0.78, 0.92, 1.00},
        grabActive = {0.25, 0.94, 1.00, 1.00}, frameHover = {0.045, 0.19, 0.29, 1.00},
        text = {0.90, 0.95, 1.00, 1.00}, disabled = {0.43, 0.58, 0.73, 1.00}, border = {0.08, 0.30, 0.52, 0.85},
        title = {0.012, 0.035, 0.070, 1.00}, titleActive = {0.020, 0.070, 0.135, 1.00},
        card = {0.075, 0.125, 0.185, 1.0}, cardInner = {0.055, 0.105, 0.16, 1.0}
    },
    {
        name = "GRAPHITE",
        window = {0.035, 0.038, 0.045, 0.99}, child = {0.065, 0.070, 0.080, 0.99},
        button = {0.13, 0.14, 0.16, 1.00}, hover = {0.25, 0.20, 0.13, 1.00}, active = {0.42, 0.25, 0.10, 1.00},
        frame = {0.105, 0.11, 0.12, 1.00}, accent = {1.00, 0.62, 0.22, 1.00}, grab = {1.00, 0.58, 0.18, 1.00},
        grabActive = {1.00, 0.76, 0.38, 1.00}, frameHover = {0.20, 0.16, 0.11, 1.00},
        text = {0.96, 0.94, 0.90, 1.00}, disabled = {0.62, 0.60, 0.56, 1.00}, border = {0.48, 0.30, 0.15, 0.85},
        title = {0.045, 0.047, 0.052, 1.00}, titleActive = {0.10, 0.085, 0.065, 1.00},
        card = {0.115, 0.12, 0.13, 1.0}, cardInner = {0.085, 0.09, 0.10, 1.0}
    },
    {
        name = "PURPLE NIGHT",
        window = {0.025, 0.018, 0.055, 0.99}, child = {0.055, 0.035, 0.095, 0.99},
        button = {0.105, 0.055, 0.18, 1.00}, hover = {0.24, 0.10, 0.34, 1.00}, active = {0.36, 0.14, 0.52, 1.00},
        frame = {0.085, 0.045, 0.14, 1.00}, accent = {0.72, 0.42, 1.00, 1.00}, grab = {0.72, 0.42, 1.00, 1.00},
        grabActive = {0.88, 0.68, 1.00, 1.00}, frameHover = {0.18, 0.085, 0.27, 1.00},
        text = {0.95, 0.91, 1.00, 1.00}, disabled = {0.62, 0.54, 0.73, 1.00}, border = {0.34, 0.18, 0.52, 0.88},
        title = {0.035, 0.022, 0.070, 1.00}, titleActive = {0.075, 0.035, 0.13, 1.00},
        card = {0.105, 0.065, 0.16, 1.0}, cardInner = {0.075, 0.045, 0.12, 1.0}
    }
}
function RH_themeColor(c) return imgui.ImVec4(c[1], c[2], c[3], c[4]) end

local autoClick   = new.bool(true)
local autoTool    = new.bool(false)
local autoCaptcha = new.bool(true)
local autoRepairs = new.bool(true)
local autoFlip    = new.bool(true)
local autoLock    = new.bool(false)
local autoFill    = new.bool(false)
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

local statW = new.int(350)
local statH = new.int(280)

local visTime   = new.bool(true)
local visMoney  = new.bool(true)
local visFrame  = new.bool(true)
local visChests = new.bool(true)
local visTotal  = new.bool(true)

local casePrice = new.int(5000000)

local working = false
local clicker = false
local autoFillGeneration = 0
local gasState = { gasType = nil, maxGas = nil, currentGas = nil }

local function featureOn(flag)
    return working and flag ~= nil and flag[0] == true
end
local trunk = false
local t0 = 0
local elapsedWork = 0
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
local pendingLoot = nil

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
    local total = elapsedWork
    if working and t0 > 0 then total = total + (os.time() - t0) end
    return math.max(0, total)
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
        f:write("uiTheme=" .. ui.theme .. "\n")
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
        f:write("autoLock=" .. b(autoLock[0]) .. "\n")
        f:write("autoFill=" .. b(autoFill[0]) .. "\n")
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
                elseif k == "uiTheme" and n then ui.theme = math.max(1, math.min(3, math.floor(n)))
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
                elseif k == "autoLock" then autoLock[0] = on
                elseif k == "autoFill" then autoFill[0] = on
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
                elseif k == "auto_lock" then autoLock[0] = on
                elseif k == "auto_fill" then autoFill[0] = on
                elseif k == "flip_delay" and n then flipDelay[0] = math.max(0.1, math.min(3, n))
                end
            end
        end
        f:close()
        statW[0] = math.max(280, math.min(480, statW[0]))
        statH[0] = math.max(260, math.min(380, statH[0]))
        log("cfg ok")
    end)
end

local function toggleMenu()
    ui.open = not ui.open
end

local function setWork(on)
    if on then
        if working then return end
        working = true
        t0 = os.time()
        lastMoney = -1
        pendingLoot = nil
        log("start")
        trunk = false
        sampAddChatMessage("{00FF00}[Road Helper] Запущен", -1)
    else
        if not working then return end
        if t0 > 0 then elapsedWork = elapsedWork + math.max(0, os.time() - t0) end
        t0 = 0
        working = false
        log("stop")
        pendingLoot = nil
        clicker = false
        autoFillGeneration = autoFillGeneration + 1
        gasState = { gasType = nil, maxGas = nil, currentGas = nil }
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

-- Arizona gas-station frontend protocol (integrated AutoFill).
local GAS_INTERFACE_ID = 48

local function sendGasInterfaceState(interfaceId, state)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 66)
    raknetBitStreamWriteInt8(bs, interfaceId)
    raknetBitStreamWriteBool(bs, state and true or false)
    raknetSendBitStreamEx(bs, 1, 10, 1)
    raknetDeleteBitStream(bs)
end

local function sendGasFrontendClick(interfaceId, elementId, subId, json)
    json = json or ""
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 63)
    raknetBitStreamWriteInt8(bs, interfaceId)
    raknetBitStreamWriteInt32(bs, elementId)
    raknetBitStreamWriteInt32(bs, subId)
    raknetBitStreamWriteInt16(bs, #json)
    raknetBitStreamWriteString(bs, json)
    raknetSendBitStreamEx(bs, 1, 10, 1)
    raknetDeleteBitStream(bs)
end

local function sendGasInteraction()
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 63)
    raknetBitStreamWriteInt8(bs, 8)
    raknetBitStreamWriteInt32(bs, 7)
    raknetBitStreamWriteInt32(bs, -1)
    raknetBitStreamWriteInt16(bs, 0)
    raknetBitStreamWriteString(bs, "")
    raknetSendBitStreamEx(bs, 1, 7, 1)
    raknetDeleteBitStream(bs)
end

local function tryAutoFill(generation)
    if not featureOn(autoFill) or generation ~= autoFillGeneration then return end
    local gasType, maxGas, currentGas = gasState.gasType, gasState.maxGas, gasState.currentGas
    if not gasType or not maxGas or not currentGas then return end
    local amount = maxGas - currentGas
    if amount <= 0 then
        gasState = { gasType = nil, maxGas = nil, currentGas = nil }
        return
    end
    local json = string.format("%d,%d", tonumber(gasType.id) or 0, amount)
    sendGasFrontendClick(GAS_INTERFACE_ID, -1, 0, json)
    sampAddChatMessage("{00BFFF}[Road Helper] Автофулл: заправка запущена", -1)
    gasState = { gasType = nil, maxGas = nil, currentGas = nil }
end

local function handleGasFrontend(interfaceId, subId, payload)
    if not featureOn(autoFill) then return end
    if interfaceId == GAS_INTERFACE_ID then
        if subId == 0 then
            local ok, types = pcall(decodeJson, payload)
            if ok and type(types) == "table" then
                gasState.gasType = nil
                for _, item in ipairs(types) do
                    if tonumber(item.available) == 1 then
                        gasState.gasType = item
                        break
                    end
                end
            end
        elseif subId == 2 then
            gasState.maxGas = tonumber(payload)
        elseif subId == 3 then
            gasState.currentGas = tonumber(payload)
            local generation = autoFillGeneration
            lua_thread.create(function()
                wait(100)
                tryAutoFill(generation)
            end)
        end
    elseif interfaceId == 8 and subId == 15 then
        local ok, data = pcall(decodeJson, payload)
        if ok and type(data) == "table" then
            local title = tostring(data.title or "")
            local lowerTitle = string.lower(title)
            if string.find(title, "Заправ", 1, true)
                or string.find(lowerTitle, "заправ", 1, true)
                or string.find(lowerTitle, "gas", 1, true)
                or string.find(lowerTitle, "fuel", 1, true)
                or string.find(lowerTitle, "refuel", 1, true) then
                local generation = autoFillGeneration
                lua_thread.create(function()
                    wait(50)
                    if featureOn(autoFill) and generation == autoFillGeneration then
                        sendGasInteraction()
                    end
                end)
            end
        end
    end
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
        if #cmd > 220 then cmd = cmd:sub(1, 220) end
        if working or trunk then
            log("cef " .. cmd)
        end
        local low = string.lower(cmd)

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

        if featureOn(autoCaptcha) then
            if string.find(cmd, "FindGame", 1, true) or string.find(cmd, "findGame", 1, true) then
                log("findgame")
                lua_thread.create(function()
                    wait(150)
                    if not featureOn(autoCaptcha) then return end
                    for i = 1, 6 do
                        if not featureOn(autoCaptcha) then return end
                        sendCef("findGame.Success")
                        wait(180)
                    end
                    if featureOn(autoCaptcha) then sendCef("findGame.finish") end
                end)
            end
        end

    elseif p == 84 then
        local iid = raknetBitStreamReadInt8(bs)
        local sub = raknetBitStreamReadInt8(bs)
        local extra = ""
        if iid == 101 or trunk then
            pcall(function()
                extra = " x=" .. tostring(raknetBitStreamReadInt32(bs)) .. " y=" .. tostring(raknetBitStreamReadInt32(bs))
            end)
        end
        if iid ~= 8 and iid ~= 52 then
            log("i84 " .. tostring(iid) .. " " .. tostring(sub) .. extra)
        end
        if iid == 25 and not clicker then
            clicker = true
            log("clicker on")
        end

        -- Frontend payload for AutoFill: length, encoding flag, JSON/text body.
        local okPayload, payload = pcall(function()
            local len = raknetBitStreamReadInt16(bs)
            local encoded = raknetBitStreamReadInt8(bs)
            if not len or len < 0 or len > 32760 then return nil end
            if encoded ~= 0 then
                return raknetBitStreamDecodeString(bs, len + encoded)
            end
            return raknetBitStreamReadString(bs, len)
        end)
        if okPayload and payload then
            handleGasFrontend(iid, sub, tostring(payload))
        end

    elseif p == 62 then
        local iid = raknetBitStreamReadInt8(bs)
        local on = raknetBitStreamReadBool(bs)
        if iid ~= 8 and iid ~= 52 and iid ~= 87 and iid ~= 17 then
            log("i62 " .. tostring(iid) .. " " .. tostring(on))
        end
        if iid == 101 then
            trunk = on and true or false
            log(on and "TRUNK OPEN" or "TRUNK CLOSE")
        end
        if iid == GAS_INTERFACE_ID and featureOn(autoFill) then
            sendGasInterfaceState(iid, on)
            return false
        end

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

        if iid == 81 and on and featureOn(autoCaptcha) then
            log("cap on")
            lua_thread.create(function()
                wait(120)
                if not featureOn(autoCaptcha) then return end
                sendLoaded(81, true)
                for cell = 0, 24 do
                    if not featureOn(autoCaptcha) then return end
                    sendClickIface(81, cell, 0, "")
                    wait(40)
                end
                for i = 1, 8 do
                    if not featureOn(autoCaptcha) then return end
                    sendClickIface(81, 0, 0, "")
                    wait(60)
                end
                log("cap done")
            end)
        end
        if iid == 81 and not on then log("cap off") end
    elseif working or trunk then
        if p ~= 155 and p ~= 216 and p ~= 221 and p ~= 159 and p ~= 108 then
            log("p" .. tostring(p))
        end
    end
end

local function logBit(prefix, bs)
    local ok, err = pcall(function()
        raknetBitStreamIgnoreBits(bs, 8)
        local p = raknetBitStreamReadInt8(bs)
        if p == 17 then
            raknetBitStreamIgnoreBits(bs, 32)
            local len = raknetBitStreamReadInt16(bs)
            local enc = raknetBitStreamReadInt8(bs)
            local cmd
            if enc == 0 then cmd = raknetBitStreamReadString(bs, len)
            else cmd = raknetBitStreamDecodeString(bs, len + enc) end
            cmd = tostring(cmd or "")
            if #cmd > 220 then cmd = cmd:sub(1, 220) end
            log(prefix .. " cef " .. cmd)
        elseif p == 63 or p == 18 or p == 66 or p == 62 or p == 84 then
            local iid = raknetBitStreamReadInt8(bs)
            log(prefix .. " t" .. tostring(p) .. " id=" .. tostring(iid))
        else
            log(prefix .. " t" .. tostring(p))
        end
    end)
    if not ok then log(prefix .. " err") end
end

function onSendPacket(id, bs)
    if id ~= 220 then return end
    if not (working or trunk) then return end
    logBit("OUT", bs)
end

function onSendChat(text)
    log("say " .. tostring(text or ""))
end

local function has(s, a, b)
    if string.find(s, a, 1, true) then return true end
    if b and string.find(s, b, 1, true) then return true end
    return false
end

local function qty(s)
    local n = tonumber(tostring(s or ""):match("%((%d+)")) or 1
    if n < 1 then n = 1 end
    if n > 50 then n = 50 end
    return n
end

local function isFrameMsg(s)
    return string.find(s, "Frame", 1, true) or string.find(s, "frame", 1, true)
end

local function isStorageMsg(s)
    return string.find(s, "storage", 1, true)
        or string.find(s, "Storage", 1, true)
        or string.find(s, "/storage", 1, true)
end

local function hasQty(s)
    return string.find(s, "%(%d+") ~= nil
end

local function addFrame(n)
    st.frame = st.frame + n
    mark()
    log("frame +" .. tostring(n) .. " =" .. tostring(st.frame))
    sampAddChatMessage("{00BFFF}[Road Helper] Frame +" .. n .. " (" .. st.frame .. ")", -1)
end

local function addOther(n)
    st.chests = st.chests + n
    mark()
    log("chest +" .. tostring(n) .. " =" .. tostring(st.chests))
    sampAddChatMessage("{00BFFF}[Road Helper] Ларец +" .. n .. " (" .. st.chests .. ")", -1)
end

-- Только ASCII: storage / Frame / (N — не зависит от CP1251/UTF-8.
-- Если предмет и /storage на разных строках — ждём до 3 сек.
function onServerMessage(color, text)
    if not text then return end
    local clean = tostring(text):gsub("{%x%x%x%x%x%x}", "")

    -- Loot/statistics are active only between START and STOP.
    if working then
        if isStorageMsg(clean) and pendingLoot and (os.clock() - pendingLoot.t) <= 3 then
            if pendingLoot.isFrame then
                addFrame(pendingLoot.n)
            else
                addOther(pendingLoot.n)
            end
            pendingLoot = nil
        end

        if isFrameMsg(clean) then
            if isStorageMsg(clean) and hasQty(clean) then
                addFrame(qty(clean))
            elseif hasQty(clean) then
                pendingLoot = { n = qty(clean), t = os.clock(), isFrame = true }
            elseif isStorageMsg(clean) then
                addFrame(1)
            end
        elseif isStorageMsg(clean) and hasQty(clean) then
            addOther(qty(clean))
        elseif hasQty(clean) and not isFrameMsg(clean) and #clean >= 20 then
            local n = qty(clean)
            if n >= 1 and n <= 20 then
                pendingLoot = { n = n, t = os.clock(), isFrame = false }
            end
        end
    else
        pendingLoot = nil
    end

    local low = string.lower(clean)
    if string.find(low, "/repairs", 1, true)
        or string.find(clean, "новые ямы", 1, true)
        or string.find(clean, "Новые ямы", 1, true)
        or string.find(clean, "образовались новые", 1, true)
        or string.find(clean, "Образовались новые", 1, true)
    then
        log("pits")
        if featureOn(autoRepairs) then
            lua_thread.create(function()
                wait(300)
                if featureOn(autoRepairs) then openRepairs() end
            end)
        end
    end
end


local function drawDigger(dl, x, y, s)
    local function ln(x1, y1, x2, y2)
        dl:AddLine(V2(x1, y1), V2(x2, y2), COL, math.max(2.0, s * 0.07))
    end
    local cx = x + s * 0.50
    dl:AddCircleFilled(V2(cx - s * 0.06, y + s * 0.16), s * 0.09, COL, 16)
    ln(cx - s * 0.08, y + s * 0.26, cx - s * 0.14, y + s * 0.50)
    ln(cx - s * 0.10, y + s * 0.32, cx - s * 0.28, y + s * 0.42)
    ln(cx - s * 0.10, y + s * 0.34, cx + s * 0.08, y + s * 0.52)
    ln(cx - s * 0.14, y + s * 0.50, cx - s * 0.30, y + s * 0.74)
    ln(cx - s * 0.14, y + s * 0.50, cx + s * 0.02, y + s * 0.74)
    ln(cx + s * 0.04, y + s * 0.48, cx + s * 0.22, y + s * 0.70)
    dl:AddTriangleFilled(
        V2(cx + s * 0.10, y + s * 0.60),
        V2(cx + s * 0.28, y + s * 0.72),
        V2(cx + s * 0.12, y + s * 0.82),
        COL
    )
end


-- Встроенные иконки: при первом запуске скрипт сам создаёт папки и PNG-файлы.
local iconTextures = {}
local actionTextures = {}
local iconFiles = {
    home = "home.png", settings = "settings.png", buttons = "buttons.png",
    statistics = "statistics.png", author = "author.png"
}
local logoTexture = nil

local embeddedIcons = {
    logo = [=[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]=],
    start = [=[iVBORw0KGgoAAAANSUhEUgAAAIAAAACACAYAAADDPmHLAAACY0lEQVR4nO3d3U3DQBBF4QuiFnqjInqjGXiAASlYcWzv7M7P+QqwIs3R3cdIAAAAAAAAAAAAAAAAAODu7ePzc/Vv6OB59Q+4hwj8hQ5A+o6AEPyED8AQgY80AUisgYdUARgiGCdlABJrMEraAAwRXJM+AIkIrigRgMSTcFaZAAwRHFMuAIk1OKJkAIYI9pUOQGIN9pQPwBDBtjYBSKzBllYBGCL40zIAiQhM2wAkngSpeQCmcwQE8KPrGhDAjW4REMCGTmtAAHd0iIAAdlSPgAAeUPlJIIADKkZAAAdVWwMCOKlKBARwQYU1IIABMkdAAINkjYAABsr4JBCAg0wREICTLGtAAM6iR0AAE0ReAwKYKGIEBDBZtDUggEWiREAAC0WIgAAWW/0kEEAQqyIggEBWrAEBBDQzAgIIatYaEEBw3hEQQHDvr09Pnt9/8fw4zvM+vGEBApp1fIkFCGXm4Q0LEMSK40sswHKrDm9YgIVWH18igGUiHF/iCZguyuENCzBRtONLLMAUEQ9vWABnkY8vsQBuoh/esAAOshxfYgGGynR4wwIMkvH4EgEMkfX4Ek/AJZkPb1iAkyocX2IBDqtyeMMCHFDt+BIL8JCKhzcswI7Kx5cI4K7qx5d4AjZ1OLxhAW50Or7EAvzqdnjDAqjv8aXmC9D58KbtAnD8by0D4Ph/Wj0BHP6/NgvA8beVXwAOf1/pBeD4+0ouAId/XLkF4PjHlFkADn9OiQXg+OelD4DjX5P2CeDwY6RcAI4/TqoF4PDjpVkAju8j/AJw+KYi/J8OAAAAAAAAAAAAAAAAkM4XyV7/tjKms+UAAAAASUVORK5CYII=]=],
    stop = [=[iVBORw0KGgoAAAANSUhEUgAAAIAAAACACAYAAADDPmHLAAABWklEQVR4nO3W0XHCQAxAQUgx9EZF9EYzTgFJGOBDSvJ2GziP9Hz26QQAAAAAAAAAAAAAAMCfdN5+gOv9OLafYdvtcl7bw9rBFv/VRggf0weeTpb/k425jAdg+Y9Nz2c0AMt/zuScxgKw/NdMzWvlH4DfYyQAb/97JubmBogTQJwA4gQQJ4A4AcQJIE4AcQKIE0CcAOIEECeAOAHECSBOAHECiBNAnADiBBAngDgBxAkgTgBxAogTQJwA4gQQJ4A4AcQJIE4AcQKIE0CcAOIEECeAOAHECSBOAHECiBNAnADiBBAngDgBxAkgTgBxAogTQJwA4gQQJ4A4AcQJIE4AcQKIE0CcAOIEECeAOAHECSBOAHEjAdwu5/PEOf/NxNzcAHFjAbgFXjM1r9EbQATPmZzT+CdABI9Nz2flH0AE39uYy/oirvfj2H6GbV4IAAAAAAAAAAAAAADgHZ8khTSc+ZbTAgAAAABJRU5ErkJggg==]=],
    repairs = [=[iVBORw0KGgoAAAANSUhEUgAAAIAAAACACAYAAADDPmHLAAAFK0lEQVR4nO2dO47UUBBF7yASxBIIJiEhmhh2MBIJKyVBYgcQE5GQTDBLQIRDMHqSMfbz71XVrc+RCJCmu599T1XZ3W03UBRFURRFURRFURRFFm6sF6DFw5+np6OPuX11E37/hNzAM2HvJZoUYTZGMvQ1IsjgegMsQl/DqwwuF80U/BxvIrha7JXg3389/pjv92dfzY8ILhZ5JvgzgW9xRgh2EagXBxwLXyL0NY7IwCwB7cKAfeFrhr7GHhlYJaBclJfg53gUgWoxwHb4jMHP2RKBSYIX1guYEiF8YHudTKexNCb2doqX4JfodQOGTkDRAaKGD/TXz9AJzAWIHH6DWQLTFrS28VGCX2JtJFiNA7MOkDF8YH37rDqBiQBZw28wSWB+DFDYoi5A9upvsHQBVQEq/H9hkEDtyJMl/B8ft//m7ov8OqZYnhm8lH4BBvaEvvb32jJoo9IBrKr/aPA9pEWw6gJmAkiGPzL4OZIiLEkgLYD4CNA+qt0K//bdh83nePj5rfv8mmPh4c/Tk6QE4h1Aq/p7we8JfY2eDBIiaHcB0dNArepfC//23YdL4W89h+SomSK5H9XfCBpd/b3wR6IlgfZpcci3gkeHL/28lojNFo1Tv6Xq2xvS71//z/bXb/c9dum4YOTxgOYpoWoHYAn/KkuvM3IUaI6BMCNAuz1HGQciAkgf/c+rzSqM+etKnxVI7Fe1DsD6id+bz8//2NDaX+5GAEv1r72+1nsDo3AnQDGWEiA5wwWQfO+frf03pMbA0n4bfSBYHSA5Kb4R1OPxk/UKbKkOkJwSIDklQHJKgOSUAMlJLwDrZwFauBJg/qWL3hc2NZmvw9PFJK4EKMZTAiTHnQBsY8Bz+wcEBFj64uKVu25nRuMiEXcdABjbBR4/nf88wHv1A04FWEJ7FFiPnlG4FWCp2rRCkb4uQBORC0M07wegfX2AVvhaF4eIdADre+BKdQLrtu/+yiAJ1qpvdFhrz+e19TdcXxs4Jcr9AQDdawNFW7X2rWEA+TuEADb3C5IaqybfCfx+LyfC3Ze+BFdHg/Q9grSvoFLvAFOsu8ERrO4S1nDZAW5f3dxY3g+/hXZFBIaDvHA3iZpSdwq1/ZEp0xtFNlivHNbA+hfG3L8PUFxDRYAti7N+XGxd/QBRB8gmAcv2qglg/fmAN7T2l2oHqFHwDEPrb6iPgOwSMIUPEB0DTIkqAeN2mQhQxwPLWOwXsw6QbRSwtf6G6QjIIgFr+ADBMUD2cWC9/eYCAP2d4L0L9NZvHT5AIgAQUwL28AEiAQCenSIN03ZSCQCs7xxvXcDy10CPQCdADy8SeFknQCoAW5WMgnG7KAUA/I4CL62/QStAD1YJWNfVg1oA1qo5CvN2UAsA+BkF3lp/g16AHiwSsKzjDC4EYK+iNTys24UAAO8o8Nr6G24EAPgk8B4+4EyAHtoSWHeeUbgTgL262Nc3x50AgP0oiND6Gy4F6CEtQZTW33ArAFu1sa1nL24FAPRHQaTW33AtQI/REkRr/Q33AlhXn/XrX8W9AID8KIjY+hshBOhxVYKorb8RRgDtaoxQ/UAgAYDxoyBy62+EEqDHUQmit/5GOAGkqzNS9QMBBQCuj4IMrb8RUoAeWxJkaf2NsAKcudjUw8WcowkrADAutKjhA8EFAPYfD2Sa+1PCC9CjhZ5t7k9JIcDZKo5e/YDS7eJZOPLjFRnCB5J0gGKdVALsreos1Q8kEwDYDjdT+EBCAYp/SSnAvMrb/7NVf1EURZGavy/2zW8WN4WBAAAAAElFTkSuQmCC]=],
    author = [=[
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
]=],
    settings = [=[
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
]=],
    home = [=[
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
]=],
    statistics = [=[
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
]=],
    buttons = [=[
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
]=],
    start = [=[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]=],
    stop = [=[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]=],
    repairs = [=[iVBORw0KGgoAAAANSUhEUgAAAIAAAACACAYAAADDPmHLAAAFK0lEQVR4nO2dO47UUBBF7yASxBIIJiEhmhh2MBIJKyVBYgcQE5GQTDBLQIRDMHqSMfbz71XVrc+RCJCmu599T1XZ3W03UBRFURRFURRFURRFFm6sF6DFw5+np6OPuX11E37/hNzAM2HvJZoUYTZGMvQ1IsjgegMsQl/DqwwuF80U/BxvIrha7JXg3389/pjv92dfzY8ILhZ5JvgzgW9xRgh2EagXBxwLXyL0NY7IwCwB7cKAfeFrhr7GHhlYJaBclJfg53gUgWoxwHb4jMHP2RKBSYIX1guYEiF8YHudTKexNCb2doqX4JfodQOGTkDRAaKGD/TXz9AJzAWIHH6DWQLTFrS28VGCX2JtJFiNA7MOkDF8YH37rDqBiQBZw28wSWB+DFDYoi5A9upvsHQBVQEq/H9hkEDtyJMl/B8ft//m7ov8OqZYnhm8lH4BBvaEvvb32jJoo9IBrKr/aPA9pEWw6gJmAkiGPzL4OZIiLEkgLYD4CNA+qt0K//bdh83nePj5rfv8mmPh4c/Tk6QE4h1Aq/p7we8JfY2eDBIiaHcB0dNArepfC//23YdL4W89h+SomSK5H9XfCBpd/b3wR6IlgfZpcci3gkeHL/28lojNFo1Tv6Xq2xvS71//z/bXb/c9dum4YOTxgOYpoWoHYAn/KkuvM3IUaI6BMCNAuz1HGQciAkgf/c+rzSqM+etKnxVI7Fe1DsD6id+bz8//2NDaX+5GAEv1r72+1nsDo3AnQDGWEiA5wwWQfO+frf03pMbA0n4bfSBYHSA5Kb4R1OPxk/UKbKkOkJwSIDklQHJKgOSUAMlJLwDrZwFauBJg/qWL3hc2NZmvw9PFJK4EKMZTAiTHnQBsY8Bz+wcEBFj64uKVu25nRuMiEXcdABjbBR4/nf88wHv1A04FWEJ7FFiPnlG4FWCp2rRCkb4uQBORC0M07wegfX2AVvhaF4eIdADre+BKdQLrtu/+yiAJ1qpvdFhrz+e19TdcXxs4Jcr9AQDdawNFW7X2rWEA+TuEADb3C5IaqybfCfx+LyfC3Ze+BFdHg/Q9grSvoFLvAFOsu8ERrO4S1nDZAW5f3dxY3g+/hXZFBIaDvHA3iZpSdwq1/ZEp0xtFNlivHNbA+hfG3L8PUFxDRYAti7N+XGxd/QBRB8gmAcv2qglg/fmAN7T2l2oHqFHwDEPrb6iPgOwSMIUPEB0DTIkqAeN2mQhQxwPLWOwXsw6QbRSwtf6G6QjIIgFr+ADBMUD2cWC9/eYCAP2d4L0L9NZvHT5AIgAQUwL28AEiAQCenSIN03ZSCQCs7xxvXcDy10CPQCdADy8SeFknQCoAW5WMgnG7KAUA/I4CL62/QStAD1YJWNfVg1oA1qo5CvN2UAsA+BkF3lp/g16AHiwSsKzjDC4EYK+iNTys24UAAO8o8Nr6G24EAPgk8B4+4EyAHtoSWHeeUbgTgL262Nc3x50AgP0oiND6Gy4F6CEtQZTW33ArAFu1sa1nL24FAPRHQaTW33AtQI/REkRr/Q33AlhXn/XrX8W9AID8KIjY+hshBOhxVYKorb8RRgDtaoxQ/UAgAYDxoyBy62+EEqDHUQmit/5GOAGkqzNS9QMBBQCuj4IMrb8RUoAeWxJkaf2NsAKcudjUw8WcowkrADAutKjhA8EFAPYfD2Sa+1PCC9CjhZ5t7k9JIcDZKo5e/YDS7eJZOPLjFRnCB5J0gGKdVALsreos1Q8kEwDYDjdT+EBCAYp/SSnAvMrb/7NVf1EURZGavy/2zW8WN4WBAAAAAElFTkSuQmCC]=],
}

local function ensureDir(path)
    local ok, lfs = pcall(require, "lfs")
    if ok and lfs and lfs.attributes(path, "mode") == "directory" then return true end
    if ok and lfs then
        local made = lfs.mkdir(path)
        return made or lfs.attributes(path, "mode") == "directory"
    end
    return false
end

local function decodeBase64(data)
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local map = {}
    for i = 1, #chars do map[chars:sub(i, i)] = i - 1 end
    local out, buffer, bits = {}, 0, 0
    for i = 1, #data do
        local c = data:sub(i, i)
        if c ~= "=" then
            local v = map[c]
            if v then
                buffer = buffer * 64 + v
                bits = bits + 6
                if bits >= 8 then
                    bits = bits - 8
                    local byte = math.floor(buffer / (2 ^ bits)) % 256
                    out[#out + 1] = string.char(byte)
                    buffer = buffer % (2 ^ bits)
                end
            end
        end
    end
    return table.concat(out)
end

local function createEmbeddedIcons()
    local root = getWorkingDirectory() .. "/RoadHelper"
    local folder = root .. "/images"
    if not ensureDir(root) then
        log("cannot create RoadHelper folder; install lfs or create folder manually")
        return folder
    end
    if not ensureDir(folder) then
        log("cannot create images folder; install lfs or create folder manually")
        return folder
    end
    for name, encoded in pairs(embeddedIcons) do
        local path = folder .. "/" .. name .. ".png"
        local f = io.open(path, "wb")
        if f then
            f:write(decodeBase64(encoded))
            f:close()
            log("embedded image updated: " .. name .. ".png")
        else
            log("cannot write icon: " .. name .. ".png")
        end
    end
    return folder .. "/"
end

local function loadRoadIcons()
    local base = createEmbeddedIcons()
    for key, file in pairs(iconFiles) do
        local ok, texture = pcall(function()
            return imgui.CreateTextureFromFile(base .. file)
        end)
        if ok and texture then
            iconTextures[key] = texture
            log("icon loaded: " .. file)
        else
            iconTextures[key] = nil
            log("icon texture API unavailable or load failed: " .. file)
        end
    end
    for _, key in ipairs({"start", "stop", "repairs"}) do
        local ok, texture = pcall(function()
            return imgui.CreateTextureFromFile(base .. key .. ".png")
        end)
        actionTextures[key] = (ok and texture) or nil
        log((actionTextures[key] and "action image loaded: " or "action image failed: ") .. key .. ".png")
    end
    local okLogo, textureLogo = pcall(function()
        return imgui.CreateTextureFromFile(base .. "logo.png")
    end)
    if okLogo and textureLogo then
        logoTexture = textureLogo
        log("logo texture loaded: logo.png")
    else
        logoTexture = nil
        log("logo texture failed: logo.png")
    end
end

local function drawTabIcon(key, size)
    local texture = iconTextures[key]
    if texture then
        local ok = pcall(function() imgui.Image(texture, V2(size, size)) end)
        if ok then return true end
    end
    return false
end

-- Neоновые переключатели настроек (вместо стандартных Checkbox)
local function settingToggle(label, value, id, banWarning)
    if label and label ~= "" then imgui.Text(u8(label)) end
    if banWarning then
        if label and label ~= "" then imgui.SameLine() end
        imgui.PushStyleColor(imgui.Col.Button, V4(0.55, 0.035, 0.055, 1.0))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, V4(0.68, 0.045, 0.065, 1.0))
        imgui.PushStyleColor(imgui.Col.ButtonActive, V4(0.42, 0.025, 0.04, 1.0))
        imgui.PushStyleColor(imgui.Col.Text, V4(1.0, 0.88, 0.88, 1.0))
        imgui.Button(u8("БАН##rh_ban_" .. id), V2(39 * S, 21 * S))
        imgui.PopStyleColor(4)
    end
    local w, h = 50 * S, 27 * S
    local avail = imgui.GetContentRegionAvail()
    imgui.SetCursorPosX(math.max(0, avail.x - w))
    local clicked = imgui.Button("##rh_toggle_" .. id, V2(w, h))
    if clicked then value[0] = not value[0] end

    local p1 = imgui.GetItemRectMin()
    local p2 = imgui.GetItemRectMax()
    local dl = imgui.GetWindowDrawList()
    local cx = value[0] and (p2.x - h * 0.5) or (p1.x + h * 0.5)
    local cy = (p1.y + p2.y) * 0.5
    local radius = h * 0.36

    -- Track: белый при включении, фирменный бирюзовый при выключении.
    local track = value[0] and 0xFFEAF7FF or 0xFFD0B820
    local knob = value[0] and 0xFF382719 or 0xFF382719
    pcall(function()
        dl:AddRectFilled(p1, p2, track, h * 0.5)
        if value[0] then
            -- Мягкая светлая кайма вокруг активного белого переключателя.
            dl:AddCircleFilled(V2(cx, cy), radius + 3 * S, 0x66FFFFFF, 24)
        end
        dl:AddCircleFilled(V2(cx, cy), radius, knob, 24)
    end)
    return clicked
end

local function actionButton(key, label, id, width, height, textColor)
    local clicked = imgui.Button("##" .. id, V2(width, height))
    local p1 = imgui.GetItemRectMin()
    local p2 = imgui.GetItemRectMax()
    local dl = imgui.GetWindowDrawList()
    local tex = actionTextures[key]
    local iconSize = math.min(height * 0.58, 30 * S)
    local ix = p1.x + 13 * S
    local iy = p1.y + (height - iconSize) * 0.5
    if tex then
        pcall(function() dl:AddImage(tex, V2(ix, iy), V2(ix + iconSize, iy + iconSize)) end)
    end
    local fontSize = imgui.GetFontSize()
    local textSize = imgui.CalcTextSize(label)
    local tx = p1.x + (width - textSize.x) * 0.5 + 9 * S
    local ty = p1.y + (height - fontSize) * 0.5
    pcall(function() dl:AddText(V2(tx, ty), textColor or 0xFFFFFFFF, label) end)
    return clicked
end



-- =========================================================
-- ROAD HELPER OTA UPDATER
-- Проверяет версию прямо в удалённом Lua-файле GitHub.
-- Конфигурация RoadHelper_config.ini не затрагивается.
-- =========================================================
local UPDATE_URL = "https://raw.githubusercontent.com/bowsbani1998-cell/Road-Helper/refs/heads/main/Road%20Helper.lua"
local updateState = {
    checking = false, downloading = false, prompt = false,
    available = false, latest = "", status = u8"Проверка ещё не выполнялась",
    stage = u8"", progress = 0, error = "", remoteBody = nil,
    lastCheck = 0, dismissed = false
}

local function updateToast(message)
    note.msg = tostring(message or "")
    note.on = true
    note.t = os.clock()
end

local function versionParts(value)
    local result = {}
    for part in tostring(value or ""):gmatch("%d+") do
        result[#result + 1] = tonumber(part) or 0
    end
    if #result == 0 then return nil end
    return result
end

local function versionIsNewer(remote, localVersion)
    local a, b = versionParts(remote), versionParts(localVersion)
    if not a or not b then return false end
    local count = math.max(#a, #b)
    for i = 1, count do
        local av, bv = a[i] or 0, b[i] or 0
        if av > bv then return true end
        if av < bv then return false end
    end
    return false
end

local function versionsEqual(a, b)
    return not versionIsNewer(a, b) and not versionIsNewer(b, a)
end

local function extractRemoteVersion(body)
    if type(body) ~= "string" then return nil end
    local value = body:match('script_version%s*%(%s*["\']([%d%.]+)["\']%s*%)')
    if not value then value = body:match('local%s+VER%s*=%s*["\']([%d%.]+)["\']') end
    return value
end

local function requestBody(url)
    -- Сначала используем requests, если библиотека доступна.
    local okReq, requests = pcall(require, "requests")
    if okReq and requests and type(requests.get) == "function" then
        local ok, response = pcall(requests.get, url)
        if ok and type(response) == "table" then
            local code = tonumber(response.status_code or response.status)
            local body = response.text or response.content or response.body
            if type(body) == "string" and body ~= "" and (not code or code == 200) then
                return body
            end
        end
    end

    -- Резервный вариант: LuaSocket / LuaSec.
    local okHttp, http = pcall(require, "socket.http")
    if okHttp and http and type(http.request) == "function" then
        local ok, body, code = pcall(http.request, url)
        if ok and type(body) == "string" and body ~= "" and tonumber(code) == 200 then
            return body
        end
    end

    local okHttps, https = pcall(require, "ssl.https")
    if okHttps and https and type(https.request) == "function" then
        local ok, body, code = pcall(https.request, url)
        if ok and type(body) == "string" and body ~= "" and tonumber(code) == 200 then
            return body
        end
    end

    -- Последний резерв: встроенный загрузчик NeomLoader/MoonLoader.
    if type(downloadUrlToFile) == "function" then
        local temp = getWorkingDirectory() .. "/RoadHelper_version_check.tmp"
        pcall(os.remove, temp)
        local done, success = false, false
        local ok = pcall(downloadUrlToFile, url, temp, function(_, status)
            success = (tonumber(status) == 200 or status == true)
            done = true
        end)
        if ok then
            local started = os.clock()
            while not done and os.clock() - started < 30 do wait(100) end
            if done and success then
                local f = io.open(temp, "rb")
                if f then
                    local body = f:read("*a")
                    f:close()
                    pcall(os.remove, temp)
                    if body and #body > 0 then return body end
                end
            end
        end
        pcall(os.remove, temp)
    end
    return nil, "Не удалось подключиться к GitHub"
end

local function getScriptPath()
    local ok, script = pcall(thisScript)
    if ok and script and type(script.path) == "string" and script.path ~= "" then
        return script.path
    end
    return nil
end

local function startUpdateCheck(showResult)
    if updateState.checking or updateState.downloading then return end
    updateState.checking = true
    updateState.error = ""
    updateState.status = u8"Подключение к серверу..."
    updateState.stage = u8"Проверяем актуальную версию"
    updateState.progress = 0
    updateState.lastCheck = os.clock()
    lua_thread.create(function()
        local url = UPDATE_URL .. "?nocache=" .. tostring(os.time())
        local body, err = requestBody(url)
        if not body then
            updateState.checking = false
            updateState.error = err or "Ошибка загрузки"
            updateState.status = u8"Не удалось проверить обновления"
            if showResult then updateToast("Не удалось проверить обновления") end
            return
        end

        local remoteVersion = extractRemoteVersion(body)
        if not remoteVersion then
            updateState.checking = false
            updateState.error = "В удалённом файле не найдена версия"
            updateState.status = u8"Ошибка формата файла обновления"
            if showResult then updateToast("Ошибка файла обновления") end
            return
        end

        updateState.latest = remoteVersion
        updateState.remoteBody = body
        updateState.checking = false

        if versionIsNewer(remoteVersion, VER) then
            updateState.available = true
            updateState.prompt = true
            updateState.dismissed = false
            updateState.status = u8"Доступна новая версия: " .. remoteVersion
            updateState.stage = u8"Обновление готово к установке"
            updateState.progress = 0
            updateToast("Доступно обновление Road Helper v" .. remoteVersion)
        else
            updateState.available = false
            updateState.prompt = false
            if versionIsNewer(VER, remoteVersion) then
                updateState.status = u8"На сервере пока размещена более старая версия"
                updateState.stage = u8"Установленная версия новее серверной"
                if showResult then updateToast("Версия на сервере старее установленной") end
            else
                updateState.status = u8"Установлена последняя версия"
                updateState.stage = u8"Road Helper обновлён"
                if showResult then updateToast("У вас последняя версия Road Helper") end
            end
        end
    end)
end

local function installRoadHelperUpdate()
    if updateState.downloading or not updateState.available then return end
    updateState.downloading = true
    updateState.prompt = true
    updateState.progress = 0
    updateState.error = ""
    updateState.stage = u8"Подготовка обновления..."
    updateState.status = u8"Выполняется обновление"
    lua_thread.create(function()
        local body = updateState.remoteBody
        if type(body) ~= "string" or #body < 20000 then
            updateState.stage = u8"Загрузка файла..."
            body = requestBody(UPDATE_URL .. "?nocache=" .. tostring(os.time()))
        end

        if type(body) ~= "string" or #body < 20000 then
            updateState.downloading = false
            updateState.error = "Файл обновления пустой или слишком маленький"
            updateState.stage = u8"Не удалось загрузить обновление"
            updateState.status = u8"Ошибка обновления"
            return
        end
        updateState.progress = 0.45
        updateState.stage = u8"Проверка файла..."

        local remoteVersion = extractRemoteVersion(body)
        if not remoteVersion or not versionIsNewer(remoteVersion, VER) then
            updateState.downloading = false
            updateState.error = "Версия в загруженном файле не подходит"
            updateState.stage = u8"Проверка не пройдена"
            updateState.status = u8"Обновление отменено"
            return
        end
        if not body:find('script_name%s*%(%s*["\']Road Helper["\']%s*%)') then
            updateState.downloading = false
            updateState.error = "Это не файл Road Helper"
            updateState.stage = u8"Проверка не пройдена"
            updateState.status = u8"Обновление отменено"
            return
        end
        local compileFn, compileErr = loadstring(body)
        if not compileFn then
            updateState.downloading = false
            updateState.error = tostring(compileErr or "Синтаксическая ошибка")
            updateState.stage = u8"Файл повреждён"
            updateState.status = u8"Обновление отменено"
            return
        end

        local destination = getScriptPath()
        if not destination then
            updateState.downloading = false
            updateState.error = "Не удалось определить путь текущего скрипта"
            updateState.stage = u8"Не удалось установить обновление"
            updateState.status = u8"Ошибка обновления"
            return
        end

        local tempPath = destination .. ".update_tmp"
        local backupPath = destination .. ".backup"
        updateState.progress = 0.65
        updateState.stage = u8"Сохранение нового файла..."
        local wf, werr = io.open(tempPath, "wb")
        if not wf then
            updateState.downloading = false
            updateState.error = tostring(werr or "Не удалось создать временный файл")
            updateState.stage = u8"Не удалось сохранить файл"
            updateState.status = u8"Ошибка обновления"
            return
        end
        local wrote, writeErr = pcall(function()
            wf:write(body)
            wf:flush()
            wf:close()
        end)
        if not wrote then
            pcall(function() wf:close() end)
            pcall(os.remove, tempPath)
            updateState.downloading = false
            updateState.error = tostring(writeErr)
            updateState.stage = u8"Ошибка записи файла"
            updateState.status = u8"Ошибка обновления"
            return
        end

        -- Проверяем, что записанный файл совпадает по размеру с полученным.
        local rf = io.open(tempPath, "rb")
        local saved = rf and rf:read("*a") or nil
        if rf then rf:close() end
        if not saved or #saved ~= #body then
            pcall(os.remove, tempPath)
            updateState.downloading = false
            updateState.error = "Размер сохранённого файла не совпадает"
            updateState.stage = u8"Файл не прошёл проверку"
            updateState.status = u8"Ошибка обновления"
            return
        end

        updateState.progress = 0.82
        updateState.stage = u8"Сохранение настроек и резервной копии..."
        saveCfg()
        pcall(os.remove, backupPath)
        local movedOld = os.rename(destination, backupPath)
        if not movedOld then
            -- На некоторых сборках rename может быть ограничен; сохраняем копию вручную.
            local old = io.open(destination, "rb")
            local oldData = old and old:read("*a") or nil
            if old then old:close() end
            if oldData then
                local bf = io.open(backupPath, "wb")
                if bf then bf:write(oldData); bf:close() end
            end
        end

        updateState.stage = u8"Установка новой версии..."
        local installed = os.rename(tempPath, destination)
        if not installed then
            local out = io.open(destination, "wb")
            if out then
                local okWrite = pcall(function()
                    assert(out:write(body))
                    assert(out:flush())
                    out:close()
                end)
                local check = io.open(destination, "rb")
                local checkBody = check and check:read("*a") or nil
                if check then check:close() end
                installed = okWrite and checkBody ~= nil and #checkBody == #body
            end
        end

        if not installed then
            if movedOld then
                pcall(os.rename, backupPath, destination)
            else
                local backup = io.open(backupPath, "rb")
                local backupBody = backup and backup:read("*a") or nil
                if backup then backup:close() end
                if backupBody then
                    local restore = io.open(destination, "wb")
                    if restore then restore:write(backupBody); restore:close() end
                end
            end
            pcall(os.remove, tempPath)
            updateState.downloading = false
            updateState.error = "Не удалось заменить файл скрипта"
            updateState.stage = u8"Старая версия сохранена"
            updateState.status = u8"Ошибка установки"
            return
        end

        updateState.progress = 1
        updateState.stage = u8"Обновление установлено"
        updateState.status = u8"Установлена версия " .. remoteVersion
        updateState.downloading = false
        updateState.available = false
        updateState.prompt = false
        updateState.remoteBody = nil
        updateToast("Road Helper обновлён до v" .. remoteVersion)

        wait(700)
        saveCfg()
        local okReload = pcall(function() thisScript():reload() end)
        if not okReload then
            updateToast("Файл обновлён. Перезапусти Road Helper вручную")
        end
    end)
end

loadRoadIcons()

imgui.OnFrame(function() return ui.open end, function(self)
    self.HideCursor = false

    local W = math.min(sizeX * 0.95, 780 * S)
    local H = math.min(sizeY * 0.94, 690 * S)
    local sideW = math.min(165 * S, W * 0.31)

    imgui.SetNextWindowPos(V2(sizeX / 2, sizeY / 2), imgui.Cond.FirstUseEver, V2(0.5, 0.5))
    imgui.SetNextWindowSize(V2(W, H), imgui.Cond.FirstUseEver)

    imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, 16 * S)
    imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 12 * S)
    imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, 9 * S)
    imgui.PushStyleVarFloat(imgui.StyleVar.GrabRounding, 12 * S)
    imgui.PushStyleVarFloat(imgui.StyleVar.GrabMinSize, 18 * S)
    imgui.PushStyleVarFloat(imgui.StyleVar.ScrollbarSize, 6.93 * S)
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, V2(10 * S, 10 * S))
    imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, V2(7 * S, 7 * S))

    local palette = RH_UI_THEMES[ui.theme] or RH_UI_THEMES[1]
    imgui.PushStyleColor(imgui.Col.WindowBg, RH_themeColor(palette.window))
    imgui.PushStyleColor(imgui.Col.ChildBg, RH_themeColor(palette.child))
    imgui.PushStyleColor(imgui.Col.Button, RH_themeColor(palette.button))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, RH_themeColor(palette.hover))
    imgui.PushStyleColor(imgui.Col.ButtonActive, RH_themeColor(palette.active))
    imgui.PushStyleColor(imgui.Col.FrameBg, RH_themeColor(palette.frame))
    imgui.PushStyleColor(imgui.Col.CheckMark, RH_themeColor(palette.accent))
    imgui.PushStyleColor(imgui.Col.SliderGrab, RH_themeColor(palette.grab))
    imgui.PushStyleColor(imgui.Col.SliderGrabActive, RH_themeColor(palette.grabActive))
    imgui.PushStyleColor(imgui.Col.FrameBgHovered, RH_themeColor(palette.frameHover))
    imgui.PushStyleColor(imgui.Col.Text, RH_themeColor(palette.text))
    imgui.PushStyleColor(imgui.Col.TextDisabled, RH_themeColor(palette.disabled))
    imgui.PushStyleColor(imgui.Col.Border, RH_themeColor(palette.border))
    imgui.PushStyleColor(imgui.Col.TitleBg, RH_themeColor(palette.title))
    imgui.PushStyleColor(imgui.Col.TitleBgActive, RH_themeColor(palette.titleActive))

    imgui.Begin(u8"##road_helper_main", nil, imgui.WindowFlags.NoCollapse)

    -- Левая навигация. Иконки рисуются линиями, поэтому не зависят от шрифта.
    imgui.BeginChild("##side", V2(sideW, 0), true)
    local side = imgui.GetWindowDrawList()
    local sp = imgui.GetCursorScreenPos()
    local avail = imgui.GetContentRegionAvail()
    imgui.Dummy(V2(1, 3 * S))
    local logoW = math.min(132 * S, avail.x - 8)
    local logoH = logoW * 0.66
    if logoTexture then
        imgui.SetCursorPosX((avail.x - logoW) * 0.5)
        imgui.Image(logoTexture, V2(logoW, logoH))
    else
        imgui.Dummy(V2(avail.x, 72 * S))
        log("reference worker logo texture unavailable")
    end
    imgui.Dummy(V2(1, 5 * S))

    imgui.SetWindowFontScale(0.82)
    local sideText = u8"Road Helper v1.1"
    local sideTextW = imgui.CalcTextSize(sideText).x
    imgui.SetCursorPosX((imgui.GetWindowWidth() - sideTextW) * 0.5)
    imgui.TextDisabled(sideText)
    imgui.SetWindowFontScale(1.0)
    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()

    local tabs = {
        {u8"ГЛАВНАЯ", 1, "home"},
        {u8"ФУНКЦИИ", 2, "settings"},
        {u8"СТАТИСТИКА", 3, "statistics"},
        {u8"НАСТРОЙКИ", 4, "buttons"},
        {u8"АВТОР", 5, "author"}
    }
    for _, tab in ipairs(tabs) do
        local selected = (ui.tab == tab[2])
        if selected then
            imgui.PushStyleColor(imgui.Col.Button, V4(0.025, 0.285, 0.525, 1.0))
            imgui.PushStyleColor(imgui.Col.Border, V4(0.12, 0.58, 0.95, 1.0))
        end
        -- Кнопка и её текст остаются на прежнем месте; значок рисуется
        -- поверх кнопки слева и центрируется по вертикали внутри неё.
        local clicked
        if tab[3] == "buttons" then
            clicked = imgui.Button("##rh_tab_settings", V2(-1, 42 * S))
            local pMin = imgui.GetItemRectMin()
            local pMax = imgui.GetItemRectMax()
            local labelSize = imgui.CalcTextSize(tab[1])
            local labelX = pMin.x + ((pMax.x - pMin.x) - labelSize.x) * 0.5 + (pMax.x - pMin.x) * 0.02
            local labelY = pMin.y + ((pMax.y - pMin.y) - labelSize.y) * 0.5
            imgui.GetWindowDrawList():AddText(V2(labelX, labelY), 0xFFFFFFFF, tab[1])
        else
            clicked = imgui.Button(tab[1], V2(-1, 42 * S))
        end
        local iconTexture = iconTextures[tab[3]]
        if iconTexture then
            local pMin = imgui.GetItemRectMin()
            local pMax = imgui.GetItemRectMax()
            local iconSize = 26 * S
            local iconOffset = tab[3] == "statistics" and -3 * S or (tab[3] == "buttons" and 5 * S or 9 * S)
            local iconX = pMin.x + iconOffset
            local iconY = pMin.y + (pMax.y - pMin.y - iconSize) * 0.5
            pcall(function()
                imgui.GetWindowDrawList():AddImage(iconTexture, V2(iconX, iconY), V2(iconX + iconSize, iconY + iconSize))
            end)
        end
        if clicked then ui.tab = tab[2] end
        if selected then imgui.PopStyleColor(2) end
        imgui.Spacing()
    end

    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()
    if imgui.Button(u8"ЗАКРЫТЬ МЕНЮ", V2(-1, 40 * S)) then
        ui.open = false
        saveCfg()
    end
    imgui.Spacing()
    imgui.TextDisabled(u8"ANDROID / NEOMLOADER")
    imgui.EndChild()

    imgui.SameLine()
    imgui.BeginChild("##body", V2(0, 0), true)

    -- Touch scrolling: drag vertically anywhere in the content area, not only the scrollbar.
    local io = imgui.GetIO()
    local mouseDown = io.MouseDown[0]
    local mouseY = io.MousePos.y
    local hovered = imgui.IsWindowHovered()
    if mouseDown and hovered and not imgui.IsAnyItemActive() then
        if not ui.touchScroll.down then
            ui.touchScroll.down = true
            ui.touchScroll.lastY = mouseY
        else
            local dy = mouseY - ui.touchScroll.lastY
            if math.abs(dy) > 0 then
                imgui.SetScrollY(math.max(0, imgui.GetScrollY() - dy * 1.10))
                ui.touchScroll.lastY = mouseY
            end
        end
    else
        ui.touchScroll.down = false
    end

    local headers = {
        u8"ПАНЕЛЬ УПРАВЛЕНИЯ",
        u8"ИГРОВЫЕ ФУНКЦИИ",
        u8"СТАТИСТИКА РАБОТЫ",
        u8"НАСТРОЙКИ ПРИЛОЖЕНИЯ",
        u8"ИНФОРМАЦИЯ О ПРОЕКТЕ"
    }
    imgui.SetWindowFontScale(1.12)
    imgui.TextColored(RH_themeColor(palette.accent), headers[ui.tab] or u8"ROAD HELPER")
    imgui.SetWindowFontScale(1.0)
    imgui.Separator()
    imgui.Spacing()

    if ui.tab == 1 then
        imgui.TextDisabled(u8"УПРАВЛЕНИЕ И БЫСТРЫЙ ДОСТУП")
        imgui.Spacing()

        -- Статусная панель в стиле предоставленного образца
        if working then
            imgui.PushStyleColor(imgui.Col.ChildBg, V4(0.018, 0.115, 0.095, 1.0))
            imgui.BeginChild("##home_status", V2(-1, 82 * S), true)
            imgui.TextColored(V4(0.20, 1.00, 0.56, 1), u8"●  РАБОТАЕТ")
            imgui.Text(u8"Работа начата  |  Время: " .. fmtTime(workSec()))
            imgui.EndChild()
            imgui.PopStyleColor()
        else
            imgui.PushStyleColor(imgui.Col.ChildBg, V4(0.105, 0.045, 0.065, 1.0))
            imgui.BeginChild("##home_status", V2(-1, 82 * S), true)
            imgui.TextColored(V4(1.00, 0.39, 0.47, 1), u8"●  ОСТАНОВЛЕН")
            imgui.TextDisabled(u8"Нажми «СТАРТ», чтобы начать отсчёт работы")
            imgui.EndChild()
            imgui.PopStyleColor()
        end

        imgui.Spacing()
        local actionW = (imgui.GetContentRegionAvail().x - 8 * S) * 0.5
        imgui.PushStyleColor(imgui.Col.Button, V4(0.015, 0.34, 0.23, 1))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, V4(0.025, 0.48, 0.31, 1))
        if actionButton("start", u8"СТАРТ", "road_start", actionW, 48 * S, 0xFFFFFFFF) then
            if not working then setWork(true) end
        end
        imgui.PopStyleColor(2)
        imgui.SameLine()
        imgui.PushStyleColor(imgui.Col.Button, V4(0.40, 0.075, 0.105, 1))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, V4(0.58, 0.10, 0.14, 1))
        if actionButton("stop", u8"СТОП", "road_stop", actionW, 48 * S, 0xFFFFFFFF) then
            if working then setWork(false) end
        end
        imgui.PopStyleColor(2)

        imgui.Spacing()
        imgui.PushStyleColor(imgui.Col.Button, V4(0.025, 0.20, 0.36, 1))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, V4(0.035, 0.31, 0.52, 1))
        local repairsButtonW = imgui.GetContentRegionAvail().x
        if actionButton("repairs", u8"МЕСТА РЕМОНТА", "road_repairs", repairsButtonW, 44 * S, 0xFFFFFFFF) then
            repairsAt = 0
            openRepairs()
        end
        imgui.PopStyleColor(2)

        imgui.Spacing()
        imgui.Separator()
        imgui.TextColored(V4(0.20, 0.72, 1.00, 1), u8"ТЕКУЩАЯ СТАТИСТИКА")
        imgui.Spacing()

        -- Компактная сетка 2x2 хорошо помещается и на мобильном экране.
        local cardW = (imgui.GetContentRegionAvail().x - 8 * S) * 0.5
        imgui.BeginChild("##home_time", V2(cardW, 66 * S), true)
        imgui.TextDisabled(u8"ВРЕМЯ РАБОТЫ")
        imgui.TextColored(V4(0.70, 0.88, 1.00, 1), fmtTime(workSec()))
        imgui.EndChild()
        imgui.SameLine()
        imgui.BeginChild("##home_money", V2(-1, 66 * S), true)
        imgui.TextDisabled(u8"ДЕНЬГИ С СИСТЕМЫ")
        imgui.TextColored(V4(0.70, 0.88, 1.00, 1), fmtMoney(st.money))
        imgui.EndChild()

        imgui.BeginChild("##home_frame", V2(cardW, 66 * S), true)
        imgui.TextDisabled(u8"КЕЙСЫ FRAME")
        imgui.TextColored(V4(0.70, 0.88, 1.00, 1), tostring(st.frame) .. u8" шт.")
        imgui.TextDisabled(fmtMoney(st.frame * casePrice[0]))
        imgui.EndChild()
        imgui.SameLine()
        imgui.BeginChild("##home_total", V2(-1, 66 * S), true)
        imgui.TextDisabled(u8"ОБЩИЙ ЗАРАБОТОК")
        imgui.TextColored(V4(0.18, 0.96, 0.64, 1), fmtMoney(totalMoney()))
        imgui.EndChild()

        imgui.Spacing()
        imgui.TextDisabled(u8"Цена одного Frame: " .. fmtMoney(casePrice[0]))
        imgui.TextDisabled(u8"Учитываются ларцы и кейсы из уведомлений хранилища.")

    elseif ui.tab == 2 then
        -- Премиум Dark Neon: отдельные карточки с описаниями и предупреждениями.
        local function settingsCard(id, title, description, value, banWarning, onChanged)
            imgui.PushStyleColor(imgui.Col.ChildBg, RH_themeColor(palette.card))
            imgui.BeginChild("##settings_card_" .. id, V2(-1, 92 * S), true)
            local cardW = imgui.GetContentRegionAvail().x
            imgui.BeginChild("##settings_info_" .. id, V2(cardW * 0.70, -1), false)
            imgui.TextColored(V4(0.92, 0.97, 1.00, 1.0), u8(title))
            imgui.TextDisabled(u8(description))
            imgui.EndChild()
            imgui.SameLine()
            imgui.BeginChild("##settings_switch_" .. id, V2(0, -1), false)
            imgui.SetCursorPosY((imgui.GetWindowHeight() - 52 * S) * 0.5)
            if settingToggle("", value, id, banWarning) then
                if onChanged then onChanged() else mark() end
            end
            imgui.EndChild()
            imgui.EndChild()
            imgui.PopStyleColor()
            imgui.Spacing()
        end

        imgui.TextDisabled(u8"ИГРОВЫЕ ФУНКЦИИ / AUTOMATION")
        imgui.Spacing()
        settingsCard("auto_click", "АВТОКЛИКЕР МИНИ-ИГРЫ", "Автоматически нажимает, пока заполняется круг мини-игры.", autoClick, true)
        settingsCard("auto_captcha", "АВТОКАПЧА", "Распознаёт и помогает проходить появляющуюся капчу.", autoCaptcha, true)
        settingsCard("auto_repairs", "АВТОМАТИЧЕСКИЙ /REPAIRS", "Автоматически открывает список доступных мест ремонта.", autoRepairs, false)
        settingsCard("auto_flip", "АВТОФЛИП", "Автоматически переворачивает автомобиль при необходимости.", autoFlip, false, function()
            mark()
            flipT, flipped = nil, false
        end)
        settingsCard("auto_lock", "АВТО ЛОК", "Закрывает автомобиль и выполняет команды при посадке/выходе.", autoLock, false)
        settingsCard("auto_fill", "АВТОФУЛЛ", "Автоматически заправляет автомобиль на АЗС.", autoFill, false)

        -- Задержка AutoFlip оставлена внутренней (0.75 сек.), отдельный ползунок убран,
        -- чтобы переключатель AutoFlip был доступен без прокрутки.
        imgui.TextDisabled(u8"Изменения сохраняются автоматически.")
        if imgui.Button(u8"СОХРАНИТЬ НАСТРОЙКИ", V2(-1, 40 * S)) then
            saveCfg()
            sampAddChatMessage("{00BFFF}[Road Helper] Сохранено", -1)
        end

    elseif ui.tab == 4 then
        imgui.TextDisabled(u8"НАСТРОЙКИ ПРИЛОЖЕНИЯ")
        imgui.Spacing()
        local subW = (imgui.GetContentRegionAvail().x - 8 * S) * 0.5
        if ui.settingsPage == 1 then
            imgui.PushStyleColor(imgui.Col.Button, RH_themeColor(palette.active))
        end
        if imgui.Button(u8"КНОПКИ", V2(subW, 40 * S)) then ui.settingsPage = 1 end
        if ui.settingsPage == 1 then imgui.PopStyleColor() end
        imgui.SameLine()
        if ui.settingsPage == 2 then imgui.PushStyleColor(imgui.Col.Button, RH_themeColor(palette.active)) end
        if imgui.Button(u8"ИНТЕРФЕЙС", V2(-1, 40 * S)) then ui.settingsPage = 2 end
        if ui.settingsPage == 2 then imgui.PopStyleColor() end
        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()

        if ui.settingsPage == 2 then
            imgui.TextColored(RH_themeColor(palette.accent), u8"ВЫБОР ОФОРМЛЕНИЯ")
            imgui.TextDisabled(u8"Выбери цветовую тему главного окна Road Helper.")
            imgui.Spacing()
            local themeDescriptions = {
                "Тёмно-синяя основа и голубые неоновые акценты.",
                "Графитовый фон с тёплыми оранжевыми акцентами.",
                "Тёмно-фиолетовый фон с яркими сиреневыми акцентами."
            }
            for i, th in ipairs(RH_UI_THEMES) do
                local chosen = (ui.theme == i)
                if chosen then
                    imgui.PushStyleColor(imgui.Col.ChildBg, RH_themeColor(palette.cardInner))
                    imgui.PushStyleColor(imgui.Col.Border, RH_themeColor(palette.accent))
                else
                    imgui.PushStyleColor(imgui.Col.ChildBg, RH_themeColor(palette.card))
                end
                imgui.BeginChild("##rh_theme_" .. i, V2(-1, 92 * S), true)
                local themeCardW = imgui.GetContentRegionAvail().x
                imgui.BeginChild("##rh_theme_info_" .. i, V2(themeCardW * 0.68, -1), false)
                imgui.TextColored(RH_themeColor(RH_UI_THEMES[i].accent), u8(th.name))
                imgui.TextDisabled(u8(themeDescriptions[i]))
                imgui.EndChild()
                imgui.SameLine()
                imgui.BeginChild("##rh_theme_action_" .. i, V2(0, -1), false)
                imgui.SetCursorPosY((imgui.GetWindowHeight() - 38 * S) * 0.5)
                if chosen then
                    imgui.TextColored(RH_themeColor(palette.accent), u8"ВЫБРАНА")
                elseif imgui.Button(u8"ПРИМЕНИТЬ##theme" .. i, V2(-1, 38 * S)) then
                    ui.theme = i
                    mark()
                    saveCfg()
                end
                imgui.EndChild()
                imgui.EndChild()
                if chosen then imgui.PopStyleColor(2) else imgui.PopStyleColor() end
                imgui.Spacing()
            end
            imgui.TextDisabled(u8"Выбранная тема сохраняется автоматически и останется после перезапуска.")
            if imgui.Button(u8"ВОЗВРАТ К СТАНДАРТНОЙ ТЕМЕ", V2(-1, 40 * S)) then
                ui.theme = 1
                mark()
                saveCfg()
            end
        else
        imgui.TextDisabled(u8"ВНЕШНИЙ ВИД И РАСПОЛОЖЕНИЕ ЭЛЕМЕНТОВ")
        imgui.Spacing()

        local function buttonSettingsCard(id, title, description, enabled, toggleId)
            imgui.PushStyleColor(imgui.Col.ChildBg, RH_themeColor(palette.card))
            imgui.BeginChild("##button_card_" .. id, V2(-1, 92 * S), true)
            local cardW = imgui.GetContentRegionAvail().x
            imgui.BeginChild("##button_info_" .. id, V2(cardW * 0.70, -1), false)
            imgui.TextColored(V4(0.92, 0.97, 1.00, 1.0), u8(title))
            imgui.TextDisabled(u8(description))
            imgui.EndChild()
            imgui.SameLine()
            imgui.BeginChild("##button_switch_" .. id, V2(0, -1), false)
            imgui.SetCursorPosY((imgui.GetWindowHeight() - 52 * S) * 0.5)
            if settingToggle("", enabled, toggleId) then mark() end
            imgui.EndChild()
            imgui.EndChild()
            imgui.PopStyleColor()
            imgui.Spacing()
        end

        buttonSettingsCard("control", "КНОПКА СТАРТ / СТОП", "Показывать плавающую кнопку управления работой.", showCtrl, "show_ctrl")
        if showCtrl[0] then
            imgui.PushStyleColor(imgui.Col.ChildBg, RH_themeColor(palette.cardInner))
            imgui.BeginChild("##button_control_values", V2(-1, 150 * S), true)
            imgui.Text(u8"Положение X")
            if imgui.SliderInt("##cpx", ctrlX, 0, math.max(0, sizeX - 50)) then mark() end
            imgui.Text(u8"Положение Y")
            if imgui.SliderInt("##cpy", ctrlY, 0, math.max(0, sizeY - 50)) then mark() end
            imgui.Text(u8"Ширина")
            if imgui.SliderInt("##cw", ctrlW, 100, 300) then mark() end
            imgui.Text(u8"Высота")
            if imgui.SliderInt("##ch", ctrlH, 36, 80) then mark() end
            imgui.EndChild()
            imgui.PopStyleColor()
        end

        imgui.Spacing()
        buttonSettingsCard("repairs", "КНОПКА МЕСТА РЕМОНТА", "Показывать плавающую кнопку быстрого доступа к местам ремонта.", showRep, "show_rep")
        if showRep[0] then
            imgui.PushStyleColor(imgui.Col.ChildBg, RH_themeColor(palette.cardInner))
            imgui.BeginChild("##button_repairs_values", V2(-1, 150 * S), true)
            imgui.Text(u8"Положение X")
            if imgui.SliderInt("##rpx", repX, 0, math.max(0, sizeX - 50)) then mark() end
            imgui.Text(u8"Положение Y")
            if imgui.SliderInt("##rpy", repY, 0, math.max(0, sizeY - 50)) then mark() end
            imgui.Text(u8"Ширина")
            if imgui.SliderInt("##rw", repW, 100, 300) then mark() end
            imgui.Text(u8"Высота")
            if imgui.SliderInt("##rh", repH, 36, 80) then mark() end
            imgui.EndChild()
            imgui.PopStyleColor()
        end
        imgui.Spacing()
        imgui.TextDisabled(u8"Зажми плавающую кнопку на 0.4 сек. и перетащи пальцем.")
        if imgui.Button(u8"СОХРАНИТЬ ПОЛОЖЕНИЕ КНОПОК", V2(-1, 40 * S)) then
            saveCfg()
            sampAddChatMessage("{00BFFF}[Road Helper] Кнопки сохранены", -1)
        end
        end -- ui.settingsPage

    elseif ui.tab == 3 then
        imgui.TextDisabled(u8"РЕЗУЛЬТАТЫ ТЕКУЩЕЙ РАБОТЫ")
        imgui.Spacing()

        local function statToggleCard(id, title, description, value)
            imgui.PushStyleColor(imgui.Col.ChildBg, RH_themeColor(palette.card))
            imgui.BeginChild("##stat_card_" .. id, V2(-1, 92 * S), true)
            local cardW = imgui.GetContentRegionAvail().x
            imgui.BeginChild("##stat_info_" .. id, V2(cardW * 0.70, -1), false)
            imgui.TextColored(V4(0.92, 0.97, 1.00, 1.0), u8(title))
            imgui.TextDisabled(u8(description))
            imgui.EndChild()
            imgui.SameLine()
            imgui.BeginChild("##stat_switch_" .. id, V2(0, -1), false)
            imgui.SetCursorPosY((imgui.GetWindowHeight() - 52 * S) * 0.5)
            if settingToggle("", value, id) then mark() end
            imgui.EndChild()
            imgui.EndChild()
            imgui.PopStyleColor()
            imgui.Spacing()
        end

        statToggleCard("show_stats", "ОКНО СТАТИСТИКИ", "Показывать отдельное плавающее окно статистики.", showStats)
        if showStats[0] then
            imgui.PushStyleColor(imgui.Col.ChildBg, RH_themeColor(palette.cardInner))
            imgui.BeginChild("##stat_dimensions", V2(-1, 86 * S), true)
            imgui.Text(u8"Ширина окна")
            if imgui.SliderInt("##sw", statW, 280, 480) then mark() end
            imgui.Text(u8"Высота окна")
            if imgui.SliderInt("##sh", statH, 260, 380) then mark() end
            imgui.EndChild()
            imgui.PopStyleColor()
        end

        statToggleCard("vis_time", "ВРЕМЯ РАБОТЫ", "Отображать продолжительность текущей работы.", visTime)
        statToggleCard("vis_money", "ДЕНЬГИ С СИСТЕМЫ", "Отображать заработок, полученный от системы.", visMoney)
        statToggleCard("vis_frame", "КОЛИЧЕСТВО FRAME", "Отображать количество полученных кейсов Frame.", visFrame)
        statToggleCard("vis_chests", "ДРУГИЕ ЛАРЦЫ И КЕЙСЫ", "Считать полученные ларцы и кейсы, кроме Frame.", visChests)
        statToggleCard("vis_total", "ОБЩИЙ ЗАРАБОТОК", "Отображать сумму системного заработка и стоимости Frame.", visTotal)

        imgui.PushStyleColor(imgui.Col.ChildBg, RH_themeColor(palette.cardInner))
        imgui.BeginChild("##stat_price_card", V2(-1, 78 * S), true)
        imgui.TextColored(V4(0.20, 0.68, 1.00, 1), u8"ЦЕНА ОДНОГО FRAME ($)")
        imgui.PushItemWidth(-1)
        if imgui.InputInt("##cp", casePrice, 100000, 1000000) then
            if casePrice[0] < 0 then casePrice[0] = 0 end
            mark()
        end
        imgui.PopItemWidth()
        imgui.EndChild()
        imgui.PopStyleColor()

        imgui.Spacing()
        imgui.PushStyleColor(imgui.Col.ChildBg, RH_themeColor(palette.card))
        imgui.BeginChild("##stat_summary_card", V2(-1, 154 * S), true)
        imgui.TextColored(V4(0.20, 0.68, 1.00, 1), u8"СВОДКА")
        imgui.Text(u8"Время работы:  " .. fmtTime(workSec()))
        imgui.Text(u8"Деньги с системы:  " .. fmtMoney(st.money))
        imgui.Text(u8"Количество Frame:  " .. tostring(st.frame))
        if visChests[0] then imgui.Text(u8"Другие ларцы и кейсы:  " .. tostring(st.chests)) end
        imgui.Separator()
        imgui.TextColored(V4(0.18, 0.92, 0.62, 1), u8"ОБЩИЙ ЗАРАБОТОК:  " .. fmtMoney(totalMoney()))
        imgui.EndChild()
        imgui.PopStyleColor()
        imgui.Spacing()
        if imgui.Button(u8"ОЧИСТИТЬ ВСЁ", V2(-1, 40 * S)) then
            st.clicks, st.money, st.frame, st.chests = 0, 0, 0, 0
            elapsedWork = 0
            t0 = working and os.time() or 0
            lastMoney = -1
            pendingLoot = nil
            saveCfg()
            log("clear all")
        end

    elseif ui.tab == 5 then
        imgui.TextDisabled(u8"ИНФОРМАЦИЯ О ПРОЕКТЕ")
        imgui.Spacing()
        imgui.Text(u8"Версия: " .. VER)
        imgui.Text(u8"Автор: Bows")
        imgui.Text(u8"Платформа: Android / NeomLoader")
        imgui.Spacing()
        imgui.PushStyleColor(imgui.Col.Button, V4(0.035, 0.30, 0.48, 1.0))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, V4(0.04, 0.42, 0.66, 1.0))
        imgui.PushStyleColor(imgui.Col.ButtonActive, V4(0.025, 0.24, 0.39, 1.0))
        if imgui.Button(u8"TELEGRAM  ·  @bowsscripts", V2(-1, 42 * S)) then
            local opened = false
            if type(openUrl) == "function" then
                opened = pcall(openUrl, "https://t.me/bowsscripts")
            end
            if not opened then
                pcall(os.execute, 'am start -a android.intent.action.VIEW -d "https://t.me/bowsscripts" >/dev/null 2>&1')
            end
        end
        imgui.PopStyleColor(3)
        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()
        imgui.TextColored(V4(0.20, 0.68, 1.00, 1), u8"ОБНОВЛЕНИЕ ПО ВОЗДУХУ")
        imgui.TextDisabled(u8"Проверка новой версии и установка прямо в игре.")
        imgui.Spacing()
        if imgui.Button(u8"ПРОВЕРИТЬ ОБНОВЛЕНИЯ", V2(-1, 42 * S)) then
            startUpdateCheck(true)
        end
        imgui.Spacing()
        imgui.TextWrapped(updateState.status)
        if updateState.checking then
            imgui.TextDisabled(u8"Пожалуйста, подождите...")
        elseif updateState.available then
            imgui.TextColored(V4(0.25, 0.88, 0.72, 1), u8"Доступна версия " .. updateState.latest)
            if imgui.Button(u8"УСТАНОВИТЬ ОБНОВЛЕНИЕ", V2(-1, 42 * S)) then
                installRoadHelperUpdate()
            end
        elseif updateState.error ~= "" then
            imgui.TextWrapped(u8"Ошибка: " .. updateState.error)
        end
        imgui.TextDisabled(u8"Текущая версия: " .. VER)
    end

    imgui.EndChild()
    imgui.End()
    imgui.PopStyleColor(15)
    imgui.PopStyleVar(8)
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
    imgui.PushStyleColor(imgui.Col.WindowBg, V4(0.025, 0.075, 0.095, 0.98))
    imgui.PushStyleColor(imgui.Col.Button, V4(0.025, 0.075, 0.095, 0.0))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, V4(0.05, 0.25, 0.29, 0.28))
    imgui.PushStyleColor(imgui.Col.ButtonActive, V4(0.06, 0.35, 0.40, 0.42))
    imgui.PushStyleColor(imgui.Col.Text, V4(0.82, 0.98, 1.00, 1.00))
    local flags = imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoResize
    imgui.Begin("##ctl", nil, flags)
    local label = working and u8"ОСТАНОВИТЬ" or u8"СТАРТ"
    local hit = imgui.Button("##rh_neon_control", V2(W, H))
    local p1, p2 = imgui.GetItemRectMin(), imgui.GetItemRectMax()
    local dl = imgui.GetWindowDrawList()
    local borderColor = 0xFFDCBE37
    local textColor = 0xFFB0DD42
    local iconColor = 0xFFB0DD42
    local textSize = imgui.CalcTextSize(label)
    local iconSize = 11 * S
    local groupW = iconSize + 9 * S + textSize.x
    local groupX = p1.x + (W - groupW) * 0.5
    local centerY = (p1.y + p2.y) * 0.5
    pcall(function()
        dl:AddRect(p1, p2, 0x66DCBE37, H * 0.5, 0, 4 * S)
        dl:AddRect(p1, p2, borderColor, H * 0.5, 0, 1.8 * S)
        if working then
            dl:AddRectFilled(V2(groupX, centerY - iconSize * 0.5), V2(groupX + iconSize, centerY + iconSize * 0.5), iconColor, 2 * S)
        else
            dl:AddTriangleFilled(V2(groupX, centerY - iconSize * 0.55), V2(groupX, centerY + iconSize * 0.55), V2(groupX + iconSize, centerY), iconColor)
        end
        dl:AddText(V2(groupX + iconSize + 9 * S, centerY - imgui.GetFontSize() * 0.5), textColor, label)
    end)
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
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, 12 * S)
    imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, 10 * S)
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowBorderSize, 0)
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, V2(0, 0))
    imgui.PushStyleVarVec2(imgui.StyleVar.FramePadding, V2(0, 0))
    imgui.PushStyleColor(imgui.Col.WindowBg, V4(0.035, 0.095, 0.13, 0.98))
    imgui.PushStyleColor(imgui.Col.Button, V4(0.035, 0.095, 0.13, 0.0))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, V4(0.08, 0.25, 0.30, 0.30))
    imgui.PushStyleColor(imgui.Col.ButtonActive, V4(0.10, 0.34, 0.40, 0.42))
    imgui.PushStyleColor(imgui.Col.Text, V4(0.85, 0.97, 0.99, 1.00))
    local flags = imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoResize
    imgui.Begin("##rep", nil, flags)
    local hit = imgui.Button("##rh_location_button", V2(W, H))
    local p1, p2 = imgui.GetItemRectMin(), imgui.GetItemRectMax()
    local dl = imgui.GetWindowDrawList()
    local label = u8"МЕСТО"
    local textSize = imgui.CalcTextSize(label)
    local pinSize = 18 * S
    local groupW = pinSize + 9 * S + textSize.x
    local groupX = p1.x + (W - groupW) * 0.5
    local centerY = (p1.y + p2.y) * 0.5
    local pinX = groupX + pinSize * 0.5
    local pinY = centerY - 2 * S
    pcall(function()
        dl:AddRect(p1, p2, 0xFFC2AF38, 12 * S, 0, 1.6 * S)
        dl:AddTriangleFilled(V2(pinX - pinSize * 0.43, pinY - pinSize * 0.10), V2(pinX + pinSize * 0.43, pinY - pinSize * 0.10), V2(pinX, pinY + pinSize * 0.62), 0xFFE5D655)
        dl:AddCircleFilled(V2(pinX, pinY - pinSize * 0.12), pinSize * 0.43, 0xFFE5D655, 20)
        dl:AddCircleFilled(V2(pinX, pinY - pinSize * 0.12), pinSize * 0.16, 0xFF3B2F20, 16)
        dl:AddText(V2(groupX + pinSize + 9 * S, centerY - imgui.GetFontSize() * 0.5), 0xFFF8F6D9, label)
    end)
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


-- Окно подтверждения OTA-обновления и компактное уведомление.
imgui.OnFrame(function() return updateState.prompt end, function(self)
    self.HideCursor = false
    local W, H = 360 * S, 235 * S
    imgui.SetNextWindowPos(V2(sizeX * 0.5, sizeY * 0.5), imgui.Cond.Always, V2(0.5, 0.5))
    imgui.SetNextWindowSize(V2(W, H), imgui.Cond.Always)
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, 15 * S)
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowBorderSize, 1 * S)
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, V2(18 * S, 15 * S))
    imgui.PushStyleColor(imgui.Col.WindowBg, V4(0.018, 0.045, 0.080, 0.99))
    imgui.PushStyleColor(imgui.Col.Border, V4(0.12, 0.52, 0.82, 1.00))
    imgui.PushStyleColor(imgui.Col.Text, V4(0.91, 0.97, 1.00, 1.00))
    imgui.PushStyleColor(imgui.Col.TextDisabled, V4(0.55, 0.72, 0.84, 1.00))
    imgui.Begin(u8"##road_helper_update_modal", nil,
        imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse)

    imgui.TextColored(V4(0.30, 0.78, 1.00, 1.00), u8"ROAD HELPER")
    imgui.SameLine()
    imgui.TextDisabled(u8" / OTA UPDATE")
    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()

    if updateState.downloading then
        imgui.Text(u8"Установка обновления")
        imgui.TextDisabled(updateState.stage)
        imgui.Spacing()
        imgui.ProgressBar(updateState.progress, V2(-1, 18 * S))
        imgui.TextColored(V4(0.42, 0.84, 1.00, 1.00),
            tostring(math.floor(updateState.progress * 100)) .. "%")
        if updateState.error ~= "" then imgui.TextWrapped(u8(updateState.error)) end
    else
        imgui.Text(u8"Доступна новая версия!")
        imgui.TextColored(V4(0.38, 0.88, 0.98, 1.00), u8"v" .. updateState.latest)
        imgui.Spacing()
        imgui.TextWrapped(u8"Установить обновление Road Helper прямо сейчас?")
        imgui.TextDisabled(u8"Ваши настройки и статистика сохранятся.")
        if updateState.error ~= "" then
            imgui.Spacing()
            imgui.TextWrapped(u8(updateState.error))
        end
        imgui.Spacing()
        local bw = (W - 3 * 18 * S) * 0.5
        if imgui.Button(u8"ОБНОВИТЬ", V2(bw, 42 * S)) then
            installRoadHelperUpdate()
        end
        imgui.SameLine()
        if imgui.Button(u8"ПОЗЖЕ", V2(bw, 42 * S)) then
            updateState.prompt = false
            updateState.dismissed = true
        end
    end

    imgui.End()
    imgui.PopStyleColor(4)
    imgui.PopStyleVar(3)
end)

imgui.OnFrame(function()
    return note.on and (os.clock() - note.t) < 3.5
end, function(self)
    self.HideCursor = true
    local textValue = u8(note.msg or "")
    local textSize = imgui.CalcTextSize(textValue)
    local W, H = math.min(sizeX - 30 * S, textSize.x + 42 * S), 48 * S
    local x, y = (sizeX - W) * 0.5, 28 * S
    local dl = imgui.GetBackgroundDrawList()
    dl:AddRectFilled(V2(x, y), V2(x + W, y + H), 0xF20A2038, 10 * S)
    dl:AddRect(V2(x, y), V2(x + W, y + H), 0xFF287DB8, 10 * S, 0, 1.4 * S)
    dl:AddText(V2(x + 18 * S, y + (H - imgui.GetFontSize()) * 0.5),
        0xFFEAF7FF, textValue)
end)

local function drawMiniStatRow(label, value, valueColor)
    local valueText = u8(value)
    local available = imgui.GetContentRegionAvail()
    local valueSize = imgui.CalcTextSize(valueText)
    imgui.TextDisabled(u8(label))
    imgui.SameLine()
    imgui.SetCursorPosX(math.max(92 * S, available.x - valueSize.x))
    imgui.TextColored(valueColor or V4(0.82, 0.92, 0.97, 1.00), valueText)
end

imgui.OnFrame(function() return showStats[0] end, function(self)
    self.HideCursor = false
    local W, H = statW[0], statH[0]
    imgui.SetNextWindowSize(V2(W, H), imgui.Cond.Always)
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, 12 * S)
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowBorderSize, 1 * S)
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, V2(12 * S, 8 * S))
    imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, V2(6 * S, 3 * S))
    imgui.PushStyleColor(imgui.Col.WindowBg, V4(0.045, 0.075, 0.105, 0.98))
    imgui.PushStyleColor(imgui.Col.Text, V4(0.88, 0.95, 0.98, 1.00))
    imgui.PushStyleColor(imgui.Col.TextDisabled, V4(0.55, 0.69, 0.76, 1.00))
    imgui.PushStyleColor(imgui.Col.TitleBg, V4(0.035, 0.075, 0.105, 1.00))
    imgui.PushStyleColor(imgui.Col.TitleBgActive, V4(0.055, 0.16, 0.20, 1.00))
    imgui.PushStyleColor(imgui.Col.Border, V4(0.14, 0.48, 0.57, 0.90))
    local flags = imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoResize
    imgui.Begin(u8"Статистика", nil, flags)

    local headerAvailable = imgui.GetContentRegionAvail()
    imgui.TextColored(V4(0.30, 0.78, 0.88, 1.00), u8"ROAD HELPER")
    imgui.SameLine()
    local status = working and u8"РАБОТАЕТ" or u8"ОСТАНОВЛЕН"
    local statusSize = imgui.CalcTextSize(status)
    imgui.SetCursorPosX(math.max(105 * S, headerAvailable.x - statusSize.x))
    imgui.TextColored(working and V4(0.30, 0.88, 0.69, 1.00) or V4(0.55, 0.68, 0.75, 1.00), status)
    imgui.Separator()

    if visTime[0] then
        drawMiniStatRow("Время", fmtTime(workSec()), working and V4(0.40, 0.88, 0.91, 1.00) or V4(0.78, 0.88, 0.93, 1.00))
    end
    if visMoney[0] then
        drawMiniStatRow("Заработок", fmtMoney(st.money), V4(0.48, 0.84, 0.91, 1.00))
    end
    if visFrame[0] then
        drawMiniStatRow("Frame", tostring(st.frame) .. " шт. (" .. fmtMoney(st.frame * casePrice[0]) .. ")", V4(0.47, 0.78, 0.94, 1.00))
    end
    if visChests[0] then
        drawMiniStatRow("Ларцы", tostring(st.chests) .. " шт.", V4(0.68, 0.84, 0.91, 1.00))
    end
    if visTotal[0] then
        imgui.PushStyleColor(imgui.Col.ChildBg, V4(0.065, 0.19, 0.22, 1.00))
        imgui.PushStyleColor(imgui.Col.Border, V4(0.16, 0.55, 0.63, 0.95))
        imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 8 * S)
        imgui.BeginChild("##rh_total_earnings", V2(-1, 58 * S), true)
        imgui.TextDisabled(u8"ОБЩИЙ ЗАРАБОТОК")
        imgui.TextColored(V4(0.38, 0.91, 0.83, 1.00), u8"$")
        imgui.SameLine()
        local totalDigits = string.sub(fmtMoney(totalMoney()), 2)
        imgui.TextColored(V4(0.38, 0.91, 0.83, 1.00), u8(totalDigits))
        imgui.EndChild()
        imgui.PopStyleVar(1)
        imgui.PopStyleColor(2)
    end

    imgui.End()
    imgui.PopStyleColor(6)
    imgui.PopStyleVar(4)
end)

-- Vehicle callbacks are guarded by both Auto Lock and the global START state.
local sampevOk, sampev = pcall(require, 'lib.samp.events')
if sampevOk and type(sampev) == "table" then
    function sampev.onSendEnterVehicle(vehicleId, passenger)
        if not featureOn(autoLock) then return end
        lua_thread.create(function()
            local waited = 0
            while featureOn(autoLock) and not isCharInAnyCar(PLAYER_PED) and waited < 5000 do
                wait(100)
                waited = waited + 100
            end
            if not featureOn(autoLock) or not isCharInAnyCar(PLAYER_PED) then return end
            wait(250)
            if not featureOn(autoLock) then return end
            sampSendChat('/lock')
            wait(500)
            if not featureOn(autoLock) then return end
            sampSendChat('/key')
            wait(500)
            if not featureOn(autoLock) then return end
            sampSendChat('/engine')
        end)
    end

    function sampev.onSendExitVehicle(vehicleId)
        if not featureOn(autoLock) then return end
        lua_thread.create(function()
            if not featureOn(autoLock) then return end
            local ok, carHandle = sampGetCarHandleBySampVehicleId(vehicleId)
            if ok and carHandle then
                local statusOk, status = pcall(getCarDoorLockStatus, carHandle)
                if statusOk and status == 0 and featureOn(autoLock) then
                    sampSendChat('/lock')
                end
            end
            wait(500)
            if featureOn(autoLock) and isCharInAnyCar(PLAYER_PED) then
                sampSendChat('/key')
            end
        end)
    end
end

function main()
    while not isSampAvailable() do wait(100) end
    loadCfg()
    loadRoadIcons()
    log("load 2.6")
    sampRegisterChatCommand("rh", toggleMenu)
    sampAddChatMessage("{00BFFF}[Road Helper] Загружен. /rh | v1.1", -1)

    lua_thread.create(function()
        wait(9000)
        startUpdateCheck(false)
    end)

    local moneyAt = 0
    local updatePeriodicAt = os.clock() + 21600
    local wasSampAvailable = true
    while true do
        wait(0)

        local sampAvailable = isSampAvailable()
        if wasSampAvailable and not sampAvailable then
            -- При выходе с сервера сбрасываем только таймер; накопленная статистика остаётся.
            elapsedWork = 0
            t0 = 0
            working = false
            clicker = false
            pendingLoot = nil
            autoFillGeneration = autoFillGeneration + 1
            gasState = { gasType = nil, maxGas = nil, currentGas = nil }
            lastMoney = -1
        end
        wasSampAvailable = sampAvailable

        if featureOn(autoClick) and clicker then
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

        if featureOn(autoFlip) then
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

        if os.clock() >= updatePeriodicAt then
            updatePeriodicAt = os.clock() + 21600
            startUpdateCheck(false)
        end
    end
end

function onScriptTerminate(scr, quit)
    if scr == thisScript() then saveCfg() end
end
