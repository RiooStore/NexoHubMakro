-- SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local FILE_NAME = "noobtd_macro_clean.json"

-- REMOTES (Jalur Fungsi Noob TD)
local Remotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Functions")
local PlaceTower = Remotes:WaitForChild("PlaceTower")
local UpgradeTower = Remotes:WaitForChild("UpgradeTower")
local SellTower = Remotes:WaitForChild("SellTower")

-- VARIABLES
local macroActions = {}
local isRecording = false
local isPlaying = false

-- UI SETUP (Bisa Digeser)
local screenGui = Instance.new("ScreenGui", player:WaitForChild("PlayerGui"))
screenGui.Name = "NoobTDBypassSpy"
screenGui.ResetOnSpawn = false

local frame = Instance.new("Frame", screenGui)
frame.Size = UDim2.new(0, 160, 0, 100)
frame.Position = UDim2.new(0.05, 0, 0.2, 0)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
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

-- ========================================================
-- CORE ENGINE: SAFE CAPTURING (Bypass Proteksi Game)
-- ========================================================
local oldInvokeServer
oldInvokeServer = hookmetamethod(game, "__namecall", function(self, ...)
    local args = {...}
    local method = getnamecallmethod()
    local result = oldInvokeServer(self, ...) -- Jalankan fungsi asli game dulu
    
    if method == "InvokeServer" and isRecording then
        local rawData = args[1]
        
        -- Validasi Ketat: Pastikan data berupa tabel dan bukan jebakan kosong (nil) dari game
        if type(rawData) == "table" then
            if self == PlaceTower then
                -- Cek apakah tabel struktur koordinat game benar-benar ada dan valid
                if rawData.partPos and rawData.placePos then
                    table.insert(macroActions, {
                        towerID = tostring(rawData.towerID),
                        type = "place",
                        placedId = tostring(rawData.placedId),
                        cost = tonumber(rawData.cost) or 0,
                        towerToPlace = tostring(rawData.towerToPlace),
                        partPos = { 
                            y = tonumber(rawData.partPos.y) or 0, 
                            x = tonumber(rawData.partPos.x) or 0, 
                            z = tonumber(rawData.partPos.z) or 0 
                        },
                        placePos = { 
                            y = tonumber(rawData.placePos.y) or 0, 
                            x = tonumber(rawData.placePos.x) or 0, 
                            z = tonumber(rawData.placePos.z) or 0 
                        }
                    })
                    print("📝 [SPY REKORD] Berhasil mengunci data Place ID: " .. tostring(rawData.placedId))
                end
                
            elseif self == UpgradeTower then
                table.insert(macroActions, {
                    cost = tonumber(rawData.cost) or 0,
                    type = "upgrade",
                    placedId = tostring(rawData.placedId),
                    slot = tostring(rawData.slot)
                })
                print("📝 [SPY REKORD] Berhasil mengunci data Upgrade ID: " .. tostring(rawData.placedId))
                
            elseif self == SellTower then
                table.insert(macroActions, {
                    cost = tonumber(rawData.cost) or 0,
                    type = "sell",
                    placedId = tostring(rawData.placedId),
                    slot = tostring(rawData.slot)
                })
                print("📝 [SPY REKORD] Berhasil mengunci data Sell ID: " .. tostring(rawData.placedId))
            end
        end
    end
    return result
end)

-- ========================================================
-- CORE ENGINE: EXECUTION ENGINE (Spy V3 Execution Style)
-- ========================================================
local function runMacroPlayback()
    if not isfile(FILE_NAME) then 
        warn("❌ File makro " .. FILE_NAME .. " tidak ditemukan di folder executor!") 
        return 
    end
    
    local fileContent = readfile(FILE_NAME)
    local success, parsed = pcall(function() return HttpService:JSONDecode(fileContent) end)
    
    if not success or not parsed or not parsed.actions then
        warn("❌ Gagal memuat file makro, format JSON di dalam file rusak!")
        return
    end
    
    isPlaying = true
    print("--- 🚀 MEMULAI EKSEKUSI DATA SPY (1X RUN) ---")
    
    local actionsList = parsed.actions
    
    task.spawn(function()
        for index, data in ipairs(actionsList) do
            if not isPlaying then break end
            
            -- Jeda aman otomatis agar transaksi uang di server sinkron
            task.wait(0.2) 
            
            local successExec, err = pcall(function()
                if data.type == "place" then
                    print(string.format("[EXECUTE] (%d/%d) Pasang %s di map (ID: %s)", index, #actionsList, data.towerToPlace, data.placedId))
                    PlaceTower:InvokeServer(data)
                    
                elseif data.type == "upgrade" then
                    print(string.format("[EXECUTE] (%d/%d) Upgrade Unit Urutan: %s", index, #actionsList, data.placedId))
                    UpgradeTower:InvokeServer(data)
                    
                elseif data.type == "sell" then
                    print(string.format("[EXECUTE] (%d/%d) Menjual Unit Urutan: %s", index, #actionsList, data.placedId))
                    SellTower:InvokeServer(data)
                end
            end)
            
            if not successExec then
                warn("⚠ Gagal mengeksekusi aksi urutan ke-" .. tostring(index) .. ": " .. tostring(err))
            end
        end
        
        isPlaying = false
        print("--- ✅ SELURUH DATA MAKRO SELESAI DIEKSEKUSI 1X SAJA ---")
    end)
end

-- ========================================================
-- CONTROLLER BUTTONS
-- ========================================================
btnRecord.MouseButton1Click:Connect(function()
    if isPlaying then return end
    if isRecording then
        isRecording = false
        btnRecord.Text = "🔴 RECORD"
        btnRecord.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
        
        if #macroActions > 0 then
            -- Dibungkus ke format struktur data asli game kamu ("version": 7)
            local finalFileStructure = {
                version = 7,
                actions = macroActions
            }
            writefile(FILE_NAME, HttpService:JSONEncode(finalFileStructure))
            print("💾 BERHASIL! File disimpan bersih tanpa crash: " .. FILE_NAME)
        else
            print("⚠ Rekaman kosong, tidak ada aksi game yang ditangkap.")
        end
    else
        macroActions = {}
        isRecording = true
        btnRecord.Text = "⏹️ STOP SAVE"
        btnRecord.BackgroundColor3 = Color3.fromRGB(200, 120, 0)
        print("🔴 Perekaman Noob TD Aktif... Skrip siap menangkap Remote Call game!")
    end
end)

btnPlay.MouseButton1Click:Connect(function()
    if not isRecording and not isPlaying then
        runMacroPlayback()
    end
end)
