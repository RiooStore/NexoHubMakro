-- SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- KONFIGURASI VERSI (Ubah ini kalau update script)
local UI_VERSION = "v1.0.3" 

local player = Players.LocalPlayer
local FILE_NAME = "noobtd_macro_clean.json"

-- REMOTES
local Remotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Functions")
local PlaceTower = Remotes:WaitForChild("Functions"):FindFirstChild("PlaceTower") or Remotes:WaitForChild("PlaceTower")
local UpgradeTower = Remotes:WaitForChild("Functions"):FindFirstChild("UpgradeTower") or Remotes:WaitForChild("UpgradeTower")
local SellTower = Remotes:WaitForChild("Functions"):FindFirstChild("SellTower") or Remotes:WaitForChild("SellTower")

-- VARIABLES
local macroActions = {}
local isRecording = false
local isPlaying = false

-- UI SETUP
local screenGui = Instance.new("ScreenGui", player:WaitForChild("PlayerGui"))
screenGui.Name = "NoobTDBypassSpy"
screenGui.ResetOnSpawn = false

local frame = Instance.new("Frame", screenGui)
frame.Size = UDim2.new(0, 160, 0, 135) -- Ditinggikan sedikit buat label versi
frame.Position = UDim2.new(0.05, 0, 0.2, 0)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
frame.Active = true
frame.Draggable = true

-- LABEL VERSI (Agar kamu tidak bingung)
local lblVersion = Instance.new("TextLabel", frame)
lblVersion.Size = UDim2.new(1, 0, 0, 20)
lblVersion.Position = UDim2.new(0, 0, 0, 0)
lblVersion.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
lblVersion.Text = "Macro Version: " .. UI_VERSION
lblVersion.TextColor3 = Color3.new(1, 1, 1)
lblVersion.Font = Enum.Font.Code
lblVersion.TextSize = 12

local function createBtn(text, yPos, color)
    local btn = Instance.new("TextButton", frame)
    btn.Size = UDim2.new(0, 140, 0, 35)
    btn.Position = UDim2.new(0, 10, 0, yPos)
    btn.BackgroundColor3 = color
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 14
    return btn
end

local btnRecord = createBtn("🔴 RECORD", 30, Color3.fromRGB(180, 40, 40))
local btnPlay = createBtn("▶️ PLAY ONCE", 75, Color3.fromRGB(40, 140, 40))

-- ========================================================
-- CORE ENGINE: SAFE CAPTURING
-- ========================================================
local oldInvokeServer
oldInvokeServer = hookmetamethod(game, "__namecall", function(self, ...)
    local args = {...}
    local method = getnamecallmethod()
    local result = oldInvokeServer(self, ...) 
    
    if method == "InvokeServer" and isRecording then
        local rawData = args[1]
        if type(rawData) == "table" then
            if self == PlaceTower then
                if rawData.partPos and rawData.placePos then
                    table.insert(macroActions, {
                        towerID = tostring(rawData.towerID),
                        type = "place",
                        placedId = tostring(rawData.placedId),
                        cost = tonumber(rawData.cost) or 0,
                        towerToPlace = tostring(rawData.towerToPlace),
                        partPos = { y = tonumber(rawData.partPos.y) or 0, x = tonumber(rawData.partPos.x) or 0, z = tonumber(rawData.partPos.z) or 0 },
                        placePos = { y = tonumber(rawData.placePos.y) or 0, x = tonumber(rawData.placePos.x) or 0, z = tonumber(rawData.placePos.z) or 0 }
                    })
                    print("📝 [SPY REKORD] Berhasil mengunci data Place ID: " .. tostring(rawData.placedId))
                end
            elseif self == UpgradeTower then
                table.insert(macroActions, { cost = tonumber(rawData.cost) or 0, type = "upgrade", placedId = tostring(rawData.placedId), slot = tostring(rawData.slot) })
            elseif self == SellTower then
                table.insert(macroActions, { cost = tonumber(rawData.cost) or 0, type = "sell", placedId = tostring(rawData.placedId), slot = tostring(rawData.slot) })
            end
        end
    end
    return result
end)

-- ========================================================
-- CORE ENGINE: EXECUTION
-- ========================================================
local function runMacroPlayback()
    if not isfile(FILE_NAME) then warn("❌ File tidak ditemukan!"); return end
    
    local success, parsed = pcall(function() return HttpService:JSONDecode(readfile(FILE_NAME)) end)
    if not success or not parsed or not parsed.actions then warn("❌ Format file rusak!"); return end
    
    isPlaying = true
    print("--- 🚀 MEMULAI EKSEKUSI [" .. UI_VERSION .. "] ---")
    
    task.spawn(function()
        for index, data in ipairs(parsed.actions) do
            if not isPlaying then break end
            task.wait(0.2) 
            pcall(function()
                if data.type == "place" then PlaceTower:InvokeServer(data)
                elseif data.type == "upgrade" then UpgradeTower:InvokeServer(data)
                elseif data.type == "sell" then SellTower:InvokeServer(data)
                end
            end)
        end
        isPlaying = false
        print("--- ✅ EKSEKUSI SELESAI ---")
    end)
end

-- BUTTON EVENTS
btnRecord.MouseButton1Click:Connect(function()
    if isPlaying then return end
    if isRecording then
        isRecording = false
        btnRecord.Text = "🔴 RECORD"
        btnRecord.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
        writefile(FILE_NAME, HttpService:JSONEncode({version = 7, actions = macroActions}))
        print("💾 File Tersimpan: " .. FILE_NAME)
    else
        macroActions = {}
        isRecording = true
        btnRecord.Text = "⏹️ STOP SAVE"
        btnRecord.BackgroundColor3 = Color3.fromRGB(200, 120, 0)
    end
end)

btnPlay.MouseButton1Click:Connect(function()
    if not isRecording and not isPlaying then runMacroPlayback() end
end)
