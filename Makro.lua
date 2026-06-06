-- SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local FILE_NAME = "noobtd_macro_clean.json"

-- REMOTES (Sesuai jalur game Noob TD)
local Remotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Functions")
local PlaceTower = Remotes:WaitForChild("PlaceTower")
local UpgradeTower = Remotes:WaitForChild("UpgradeTower")
local SellTower = Remotes:WaitForChild("SellTower")

-- VARIABLES
local macroActions = {}
local isRecording = false
local isPlaying = false

-- UI SETUP (Sederhana & Bisa Digeser)
local screenGui = Instance.new("ScreenGui", player:WaitForChild("PlayerGui"))
screenGui.Name = "NoobTDFinalMacro"
screenGui.ResetOnSpawn = false

local frame = Instance.new("Frame", screenGui)
frame.Size = UDim2.new(0, 160, 0, 100)
frame.Position = UDim2.new(0.05, 0, 0.2, 0)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.Active = true
frame.Draggable = true

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

local btnRecord = createBtn("🔴 RECORD", 10, Color3.fromRGB(180, 40, 40))
local btnPlay = createBtn("▶️ PLAY ONCE", 55, Color3.fromRGB(40, 140, 40))

-- ==========================================
-- ENGINE: CAPTURING (Merekam Persis Format Game)
-- ==========================================
local oldInvokeServer
oldInvokeServer = hookmetamethod(game, "__namecall", function(self, ...)
    local args = {...}
    local method = getnamecallmethod()
    local result = oldInvokeServer(self, ...) -- Jalankan game aslinya dulu
    
    if method == "InvokeServer" and isRecording then
        local rawData = args[1]
        if type(rawData) == "table" then
            if self == PlaceTower then
                -- Salin data tabel dictionary persis seperti format game kamu
                table.insert(macroActions, {
                    towerID = rawData.towerID,
                    type = "place",
                    placedId = rawData.placedId,
                    cost = rawData.cost,
                    towerToPlace = rawData.towerToPlace,
                    partPos = { y = rawData.partPos.y, x = rawData.partPos.x, z = rawData.partPos.z },
                    placePos = { y = rawData.placePos.y, x = rawData.placePos.x, z = rawData.placePos.z }
                })
                print("📝 [RECORD] Tersemat Place Tower ID: " .. tostring(rawData.placedId))
                
            elseif self == UpgradeTower then
                table.insert(macroActions, {
                    cost = rawData.cost,
                    type = "upgrade",
                    placedId = rawData.placedId,
                    slot = rawData.slot
                })
                print("📝 [RECORD] Tersemat Upgrade Tower ID: " .. tostring(rawData.placedId))
                
            elseif self == SellTower then
                table.insert(macroActions, {
                    cost = rawData.cost,
                    type = "sell",
                    placedId = rawData.placedId,
                    slot = rawData.slot
                })
                print("📝 [RECORD] Tersemat Sell Tower ID: " .. tostring(rawData.placedId))
            end
        end
    end
    return result
end)

-- ==========================================
-- ENGINE: PLAYBACK (Eksekusi 1X Dari File)
-- ==========================================
local function runMacroPlayback()
    if not isfile(FILE_NAME) then 
        warn("❌ File makro " .. FILE_NAME .. " tidak ditemukan!") 
        return 
    end
    
    local fileContent = readfile(FILE_NAME)
    local success, parsed = pcall(function() return HttpService:JSONDecode(fileContent) end)
    
    if not success or not parsed or not parsed.actions then
        warn("❌ Format isi file makro rusak / salah!")
        return
    end
    
    isPlaying = true
    print("--- 🚀 MEMULAI EKSEKUSI MAKRO (1X PLAY) ---")
    
    -- Ambil array actions-nya
    local actionsList = parsed.actions
    
    task.spawn(function()
        for index, data in ipairs(actionsList) do
            if not isPlaying then break end
            
            -- Kasih sedikit jeda interaksi (0.15 detik) biar server game ga anggap exploit spamming
            task.wait(0.15) 
            
            if data.type == "place" then
                print(string.format("[PLAY] (%d/%d) Pasang %s (ID: %s)", index, #actionsList, data.towerToPlace, data.placedId))
                PlaceTower:InvokeServer(data)
                
            elseif data.type == "upgrade" then
                print(string.format("[PLAY] (%d/%d) Upgrade Tower ID: %s", index, #actionsList, data.placedId))
                UpgradeTower:InvokeServer(data)
                
            elseif data.type == "sell" then
                print(string.format("[PLAY] (%d/%d) Jual Tower ID: %s", index, #actionsList, data.placedId))
                SellTower:InvokeServer(data)
            end
        end
        
        isPlaying = false
        print("--- ✅ SELURUH FILE MAKRO SELESAI DIEKSEKUSI 1X ---")
    end)
end

-- ==========================================
-- CONTROLLER BUTTONS
-- ==========================================
btnRecord.MouseButton1Click:Connect(function()
    if isPlaying then return end
    if isRecording then
        isRecording = false
        btnRecord.Text = "🔴 RECORD"
        btnRecord.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
        
        if #macroActions > 0 then
            -- Bungkus ke objek "version" dan "actions" biar COCOK 100% sama file contohmu
            local finalFileStructure = {
                version = 7,
                actions = macroActions
            }
            writefile(FILE_NAME, HttpService:JSONEncode(finalFileStructure))
            print("💾 SELESAI! Hasil ekspor file sukses ditimpa ke -> " .. FILE_NAME)
        else
            print("⚠ Tidak ada aksi yang direkam.")
        end
    else
        macroActions = {}
        isRecording = true
        btnRecord.Text = "⏹️ STOP SAVE"
        btnRecord.BackgroundColor3 = Color3.fromRGB(200, 120, 0)
        print("🔴 Perekaman Noob TD aktif... Silakan beraksi di dalam map!")
    end
end)

btnPlay.MouseButton1Click:Connect(function()
    if not isRecording and not isPlaying then
        runMacroPlayback()
    end
end)
