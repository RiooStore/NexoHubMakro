-- SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer

-- FILE CONFIG
local FILE_NAME = "noobtd_macro_v2.txt"

-- REMOTES
local Remotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Functions")
local PlaceTower = Remotes:WaitForChild("PlaceTower")
local UpgradeTower = Remotes:WaitForChild("UpgradeTower")
local SellTower = Remotes:WaitForChild("SellTower")

-- VARIABLES
local macroData = {}
local isRecording = false
local isPlaying = false
local startTime = 0

-- UI SETUP
local screenGui = Instance.new("ScreenGui", player:WaitForChild("PlayerGui"))
screenGui.Name = "NoobMacroFIX"
screenGui.ResetOnSpawn = false

local frame = Instance.new("Frame", screenGui)
frame.Size = UDim2.new(0, 200, 0, 120)
frame.Position = UDim2.new(0.1, 0, 0.1, 0)
frame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
frame.Active = true
frame.Draggable = true

local function createBtn(text, pos, color)
    local btn = Instance.new("TextButton", frame)
    btn.Size = UDim2.new(0, 180, 0, 40)
    btn.Position = pos
    btn.BackgroundColor3 = color
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 14
    return btn
end

local btnRecord = createBtn("🔴 RECORD NEW", UDim2.new(0, 10, 0, 10), Color3.fromRGB(200, 50, 50))
local btnPlay = createBtn("▶️ PLAY ONCE", UDim2.new(0, 10, 0, 60), Color3.fromRGB(50, 150, 50))

-- ==========================================
-- LOGIC: SERIALIZATION (MENGAMANKAN DATA)
-- ==========================================
local function cleanArgsForSaving(actionType, rawArgs)
    if actionType == "Place" then
        local orig = rawArgs[1]
        if type(orig) == "table" then
            return {
                towerID = orig.towerID,
                towerToPlace = orig.towerToPlace,
                -- Simpan path instance-nya sebagai string teks biar tidak hilang
                instancePath = orig.instance and orig.instance:GetFullName() or "Workspace.Map.Map.Plains.Placeable.Part",
                -- Pecah Vector3 jadi angka biasa agar aman di-JSON
                posArray = orig.position and {orig.position.X, orig.position.Y, orig.position.Z} or {0, 0, 0}
            }
        end
    end
    -- Upgrade & Sell cuma kirim string urutan (misal: "1"), aman langsung disimpan
    return rawArgs[1]
end

local function rebuildArgsForPlaying(actionType, savedArgs)
    if actionType == "Place" then
        -- Cari ulang objek Part berdasarkan string path-nya
        local foundInstance = nil
        pcall(function()
            local pathParts = string.split(savedArgs.instancePath, ".")
            local currentObj = game
            for i = 2, #pathParts do
                currentObj = currentObj:FindFirstChild(pathParts[i])
            end
            foundInstance = currentObj
        end)
        
        -- Rakit kembali menjadi Vector3 asli Roblox
        local posX = savedArgs.posArray[1]
        local posY = savedArgs.posArray[2]
        local posZ = savedArgs.posArray[3]
        
        return {
            [1] = {
                towerID = savedArgs.towerID,
                towerToPlace = savedArgs.towerToPlace,
                instance = foundInstance or workspace:FindFirstChild("Map", true),
                position = Vector3.new(posX, posY, posZ)
            }
        }
    end
    return { [1] = savedArgs }
end

-- ==========================================
-- HOOK RECORDING
-- ==========================================
local oldInvokeServer
oldInvokeServer = hookmetamethod(game, "__namecall", function(self, ...)
    local args = {...}
    local method = getnamecallmethod()
    
    if method == "InvokeServer" and isRecording then
        local elapsed = tick() - startTime
        if self == PlaceTower then
            local cleanData = cleanArgsForSaving("Place", args)
            table.insert(macroData, {Time = elapsed, Action = "Place", SavedArgs = cleanData})
            print("✔️ [RECORD] Berhasil mencatat penempatan unit")
        elseif self == UpgradeTower then
            local cleanData = cleanArgsForSaving("Upgrade", args)
            table.insert(macroData, {Time = elapsed, Action = "Upgrade", SavedArgs = cleanData})
            print("✔️ [RECORD] Berhasil mencatat upgrade unit ke: " .. tostring(cleanData))
        elseif self == SellTower then
            local cleanData = cleanArgsForSaving("Sell", args)
            table.insert(macroData, {Time = elapsed, Action = "Sell", SavedArgs = cleanData})
            print("✔️ [RECORD] Berhasil mencatat penjualan unit ke: " .. tostring(cleanData))
        end
    end
    return oldInvokeServer(self, ...)
end)

-- ==========================================
-- PLAYBACK ENGINE
-- ==========================================
local function runPlayback()
    if not isfile(FILE_NAME) then 
        warn("❌ File makro tidak ditemukan!") 
        return 
    end
    
    local fileContent = readfile(FILE_NAME)
    local success, data = pcall(function() return HttpService:JSONDecode(fileContent) end)
    if not success or not data then 
        warn("❌ Gagal membaca file JSON!") 
        return 
    end
    
    isPlaying = true
    local startTick = tick()
    local idx = 1
    
    print("--- 🚀 MEMULAI REPLAY MAKRO BARU ---")
    
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not isPlaying or idx > #data then
            conn:Disconnect()
            isPlaying = false
            print("--- ✅ REPLAY SELESAI ---")
            return
        end
        
        local action = data[idx]
        if (tick() - startTick) >= action.Time then
            -- Rebuild data mentah jadi tipe data Roblox asli
            local realArgs = rebuildArgsForPlaying(action.Action, action.SavedArgs)
            
            task.spawn(function()
                if action.Action == "Place" then
                    print("[REPLAY] Mencoba memunculkan unit di koordinat asli...")
                    PlaceTower:InvokeServer(unpack(realArgs))
                elseif action.Action == "Upgrade" then
                    print("[REPLAY] Mencoba upgrade unit urutan ke: " .. tostring(action.SavedArgs))
                    UpgradeTower:InvokeServer(unpack(realArgs))
                elseif action.Action == "Sell" then
                    print("[REPLAY] Mencoba menjual unit urutan ke: " .. tostring(action.SavedArgs))
                    SellTower:InvokeServer(unpack(realArgs))
                end
            end)
            
            idx = idx + 1
        end
    end)
end

-- ==========================================
-- BUTTON CONTROLLER
-- ==========================================
btnRecord.MouseButton1Click:Connect(function()
    if isPlaying then return end
    if isRecording then
        isRecording = false
        btnRecord.Text = "🔴 RECORD NEW"
        btnRecord.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        
        if #macroData > 0 then
            writefile(FILE_NAME, HttpService:JSONEncode(macroData))
            print("💾 REKAMAN SELESAI! File disimpan sebagai:", FILE_NAME)
        else
            print("⚠ Data kosong, gagal menyimpan file.")
        end
    else
        macroData = {}
        startTime = tick()
        isRecording = true
        btnRecord.Text = "⏹️ STOP & SAVE"
        btnRecord.BackgroundColor3 = Color3.fromRGB(200, 120, 0)
        print("🔴 Sedang merekam aksi kamu... Silakan tempatkan unit!")
    end
end)

btnPlay.MouseButton1Click:Connect(function()
    if not isRecording and not isPlaying then 
        runPlayback() 
    end
end)
