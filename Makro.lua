-- SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer

-- FILE CONFIG
local FILE_NAME = "noobtd_macro.txt"

-- REMOTES (Sesuai struktur Noob Tower Defense)
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
screenGui.Name = "NoobMacroUI"
screenGui.ResetOnSpawn = false

local frame = Instance.new("Frame", screenGui)
frame.Size = UDim2.new(0, 200, 0, 150)
frame.Position = UDim2.new(0.5, -100, 0.5, -75)
frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
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
    return btn
end

local btnRecord = createBtn("🔴 RECORD", UDim2.new(0, 10, 0, 10), Color3.fromRGB(200, 0, 0))
local btnPlay = createBtn("▶️ PLAY ONCE", UDim2.new(0, 10, 0, 60), Color3.fromRGB(0, 200, 0))

-- LOGIC: RECORDING
local oldInvokeServer
oldInvokeServer = hookmetamethod(game, "__namecall", function(self, ...)
    local args = {...}
    local method = getnamecallmethod()
    
    if method == "InvokeServer" and isRecording then
        local elapsed = tick() - startTime
        if self == PlaceTower then
            -- Simpan posisi dan ID tower
            table.insert(macroData, {Time = elapsed, Action = "Place", Args = args[1]})
            print("[RECORD] PlaceTower tercatat")
        elseif self == UpgradeTower then
            table.insert(macroData, {Time = elapsed, Action = "Upgrade", Args = args[1]})
            print("[RECORD] Upgrade tercatat: " .. tostring(args[1]))
        elseif self == SellTower then
            table.insert(macroData, {Time = elapsed, Action = "Sell", Args = args[1]})
            print("[RECORD] Sell tercatat: " .. tostring(args[1]))
        end
    end
    return oldInvokeServer(self, ...)
end)

-- LOGIC: PLAYBACK
local function runPlayback()
    if not isfile(FILE_NAME) then warn("File tidak ditemukan!") return end
    
    local data = HttpService:JSONDecode(readfile(FILE_NAME))
    isPlaying = true
    local startTick = tick()
    local idx = 1
    
    print("--- 🚀 MEMULAI REPLAY ---")
    
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
            local success, err = pcall(function()
                if action.Action == "Place" then
                    PlaceTower:InvokeServer(action.Args)
                elseif action.Action == "Upgrade" then
                    UpgradeTower:InvokeServer(action.Args)
                elseif action.Action == "Sell" then
                    SellTower:InvokeServer(action.Args)
                end
            end)
            
            if not success then
                warn("[ERROR REPLAY] Gagal menjalankan " .. action.Action .. ": " .. tostring(err))
            else
                print("[SUCCESS] " .. action.Action .. " berhasil dikirim")
            end
            
            idx = idx + 1
        end
    end)
end

-- BUTTON EVENTS
btnRecord.MouseButton1Click:Connect(function()
    if isRecording then
        isRecording = false
        btnRecord.Text = "🔴 RECORD"
        writefile(FILE_NAME, HttpService:JSONEncode(macroData))
        print("💾 File Tersimpan!")
    else
        macroData = {}
        startTime = tick()
        isRecording = true
        btnRecord.Text = "⏹️ STOP & SAVE"
    end
end)

btnPlay.MouseButton1Click:Connect(function()
    if not isPlaying then runPlayback() end
end)
