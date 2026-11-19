script_name("Road Helper")
script_author("Bows")
script_version("1.5")

local VER = "1.4"
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
local touchScroll = { down = false, lastY = 0 }

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
    working = on
    if on then
        t0 = os.time()
        lastMoney = -1
        log("start")
        trunk = false
        sampAddChatMessage("{00FF00}[Road Helper] Запущен", -1)
    else
        log("stop")
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

local pendingLoot = nil

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
    author = [=[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]=],
    settings = [=[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]=],
    home = [=[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]=],
    statistics = [=[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]=],
    buttons = [=[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]=],
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
local UPDATE_URL = "https://raw.githubusercontent.com/bowsbani1998-cell/Road-Helper/refs/heads/main/Road%20Helper%20v1.4.lua"
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

    imgui.PushStyleColor(imgui.Col.WindowBg, V4(0.012, 0.022, 0.045, 0.99))
    imgui.PushStyleColor(imgui.Col.ChildBg, V4(0.020, 0.043, 0.080, 0.99))
    imgui.PushStyleColor(imgui.Col.Button, V4(0.035, 0.105, 0.190, 1.00))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, V4(0.045, 0.205, 0.355, 1.00))
    imgui.PushStyleColor(imgui.Col.ButtonActive, V4(0.025, 0.310, 0.560, 1.00))
    imgui.PushStyleColor(imgui.Col.FrameBg, V4(0.030, 0.085, 0.145, 1.00))
    imgui.PushStyleColor(imgui.Col.CheckMark, V4(0.12, 0.68, 1.00, 1.00))
    imgui.PushStyleColor(imgui.Col.SliderGrab, V4(0.05, 0.78, 0.92, 1.00))
    imgui.PushStyleColor(imgui.Col.SliderGrabActive, V4(0.25, 0.94, 1.00, 1.00))
    imgui.PushStyleColor(imgui.Col.FrameBgHovered, V4(0.045, 0.19, 0.29, 1.00))
    imgui.PushStyleColor(imgui.Col.Text, V4(0.90, 0.95, 1.00, 1.00))
    imgui.PushStyleColor(imgui.Col.TextDisabled, V4(0.43, 0.58, 0.73, 1.00))
    imgui.PushStyleColor(imgui.Col.Border, V4(0.08, 0.30, 0.52, 0.85))
    imgui.PushStyleColor(imgui.Col.TitleBg, V4(0.012, 0.035, 0.070, 1.00))
    imgui.PushStyleColor(imgui.Col.TitleBgActive, V4(0.020, 0.070, 0.135, 1.00))

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
    local sideText = u8"Road Helper v1.4"
    local sideTextW = imgui.CalcTextSize(sideText).x
    imgui.SetCursorPosX((imgui.GetWindowWidth() - sideTextW) * 0.5)
    imgui.TextDisabled(sideText)
    imgui.SetWindowFontScale(1.0)
    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()

    local tabs = {
        {u8"ГЛАВНАЯ", 1, "home"},
        {u8"НАСТРОЙКИ", 2, "settings"},
        {u8"КНОПКИ", 3, "buttons"},
        {u8"СТАТИСТИКА", 4, "statistics"},
        {u8"АВТОР", 5, "author"}
    }
    for _, tab in ipairs(tabs) do
        local selected = (ui.tab == tab[2])
        if selected then
            imgui.PushStyleColor(imgui.Col.Button, V4(0.025, 0.285, 0.525, 1.0))
            imgui.PushStyleColor(imgui.Col.Border, V4(0.12, 0.58, 0.95, 1.0))
        end
        if drawTabIcon(tab[3], 25 * S) then imgui.SameLine() end
        if imgui.Button(tab[1], V2(-1, 42 * S)) then ui.tab = tab[2] end
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
        if not touchScroll.down then
            touchScroll.down = true
            touchScroll.lastY = mouseY
        else
            local dy = mouseY - touchScroll.lastY
            if math.abs(dy) > 0 then
                imgui.SetScrollY(math.max(0, imgui.GetScrollY() - dy * 1.10))
                touchScroll.lastY = mouseY
            end
        end
    else
        touchScroll.down = false
    end

    local headers = {
        u8"ПАНЕЛЬ УПРАВЛЕНИЯ",
        u8"НАСТРОЙКИ ФУНКЦИЙ",
        u8"ПЛАВАЮЩИЕ КНОПКИ",
        u8"СТАТИСТИКА РАБОТЫ",
        u8"ИНФОРМАЦИЯ О ПРОЕКТЕ"
    }
    imgui.SetWindowFontScale(1.12)
    imgui.TextColored(V4(0.20, 0.68, 1.00, 1), headers[ui.tab] or u8"ROAD HELPER")
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
            imgui.PushStyleColor(imgui.Col.ChildBg, V4(0.075, 0.125, 0.185, 1.0))
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

        imgui.TextDisabled(u8"ROAD HELPER / CONFIGURATION")
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

    elseif ui.tab == 3 then
        imgui.TextDisabled(u8"НАСТРОЙКА РАСПОЛОЖЕНИЯ И РАЗМЕРА")
        imgui.Spacing()

        local function buttonSettingsCard(id, title, description, enabled, toggleId)
            imgui.PushStyleColor(imgui.Col.ChildBg, V4(0.075, 0.125, 0.185, 1.0))
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
            imgui.PushStyleColor(imgui.Col.ChildBg, V4(0.055, 0.105, 0.16, 1.0))
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
            imgui.PushStyleColor(imgui.Col.ChildBg, V4(0.055, 0.105, 0.16, 1.0))
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

    elseif ui.tab == 4 then
        imgui.TextDisabled(u8"РЕЗУЛЬТАТЫ ТЕКУЩЕЙ РАБОТЫ")
        imgui.Spacing()

        local function statToggleCard(id, title, description, value)
            imgui.PushStyleColor(imgui.Col.ChildBg, V4(0.075, 0.125, 0.185, 1.0))
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
            imgui.PushStyleColor(imgui.Col.ChildBg, V4(0.055, 0.105, 0.16, 1.0))
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

        imgui.PushStyleColor(imgui.Col.ChildBg, V4(0.055, 0.105, 0.16, 1.0))
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
        imgui.PushStyleColor(imgui.Col.ChildBg, V4(0.075, 0.125, 0.185, 1.0))
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
        if imgui.Button(u8"СБРОСИТЬ СТАТИСТИКУ", V2(-1, 40 * S)) then
            st.clicks, st.money, st.frame, st.chests = 0, 0, 0, 0
            lastMoney = -1
            t0 = working and os.time() or 0
            saveCfg()
            log("reset")
        end

    elseif ui.tab == 5 then
        imgui.TextDisabled(u8"ИНФОРМАЦИЯ О ПРОЕКТЕ")
        imgui.Spacing()
        imgui.Text(u8"Версия: " .. VER)
        imgui.Text(u8"Автор: Bows")
        imgui.Text(u8"Платформа: Android / NeomLoader")
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
    log("load 1.8")
    sampRegisterChatCommand("rh", toggleMenu)
    sampAddChatMessage("{00BFFF}[Road Helper] Загружен. /rh | v1.4", -1)

    lua_thread.create(function()
        wait(9000)
        startUpdateCheck(false)
    end)

    local moneyAt = 0
    local updatePeriodicAt = os.clock() + 21600
    while true do
        wait(0)

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
