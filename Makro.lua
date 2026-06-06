-- SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- FILE CONFIG
local FILE_NAME = "noobtd_macro.txt"
local HttpService = game:GetService("HttpService")

-- REMOTES
local Remotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Functions")
local PlaceTower = Remotes:WaitForChild("PlaceTower")
local UpgradeTower = Remotes:WaitForChild("UpgradeTower")
local SellTower = Remotes:WaitForChild("SellTower")

-- VARIABLES FOR MACRO
local macroData = {}
local isRecording = false
local isPlaying = false
local startTime = 0

-- UI Sederhana
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "NoobTD_SaveLoadUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 200, 0, 110)
frame.Position = UDim2.new(0, 20, 0, 20)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = screenGui

local recordButton = Instance.new("TextButton")
recordButton.Size = UDim2.new(0, 180, 0, 40)
recordButton.Position = UDim2.new(0, 10, 0, 10)
recordButton.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
recordButton.Text = "🔴 RECORD & SAVE"
recordButton.TextColor3 = Color3.fromRGB(255, 255, 255)
recordButton.Font = Enum.Font.SourceSansBold
recordButton.TextSize = 16
recordButton.Parent = frame

local playButton = Instance.new("TextButton")
playButton.Size = UDim2.new(0, 180, 0, 40)
playButton.Position = UDim2.new(0, 10, 0, 60)
playButton.BackgroundColor3 = Color3.fromRGB(40, 167, 69)
playButton.Text = "▶️ PLAY ONCE (LOAD)"
playButton.TextColor3 = Color3.fromRGB(255, 255, 255)
playButton.Font = Enum.Font.SourceSansBold
playButton.TextSize = 16
playButton.Parent = frame

-- ==========================================
-- FUNGSI SAVE & LOAD FILE (SERIALIZATION)
-- ==========================================

-- Fungsi merubah Vector3/Instance menjadi format tabel murni yang bisa disimpan jadi teks file
local function sanitizeDataForSaving(data)
    local sanitized = {}
    for _, action in ipairs(data) do
        local savedArgs = {}
        if action.Action == "Place" then
            local origArgs = action.Args[1]
            savedArgs = {
                towerID = origArgs.towerID,
                towerToPlace = origArgs.towerToPlace,
                -- Simpan path string untuk instance agar bisa dicari ulang saat load
                instancePath = origArgs.instance and origArgs.instance:GetFullName() or "",
                -- Simpan posisi koordinat X, Y, Z secara terpisah
                position = {origArgs.position.X, origArgs.position.Y, origArgs.position.Z}
            }
        else
            -- Upgrade dan Sell cuma berupa string urutan angka ("1", "2"), langsung aman disimpan
            savedArgs = action.Args
        end
        
        table.insert(sanitized, {
            Time = action.Time,
            Action = action.Action,
            Args = savedArgs
        })
    end
    return sanitized
end

-- Fungsi mengembalikan format teks file menjadi data game (Vector3 & Instance) kembali
local function parseDataForPlaying(sanitizedData)
    local parsed = {}
    for _, action in ipairs(sanitizedData) do
        local runArgs = {}
        if action.Action == "Place" then
            local sArgs = action.Args
            
            -- Cari ulang object part map berdasarkan path stringnya
            local foundInstance = nil
            local pathParts = string.split(sArgs.instancePath, ".")
            local currentObj = game
            for i = 2, #pathParts do -- Lewati "game" di indeks 1
                currentObj = currentObj and currentObj:FindFirstChild(pathParts[i])
            end
            foundInstance = currentObj
            
            runArgs = {
                {
                    towerID = sArgs.towerID,
                    towerToPlace = sArgs.towerToPlace,
                    instance = foundInstance or workspace:WaitForChild("Map"):WaitForChild("Map"):WaitForChild("Plains"):WaitForChild("Placeable"):WaitForChild("Part"), -- fallback jika path berubah sedikit
                    position = Vector3.new(sArgs.position[1], sArgs.position[2], sArgs.position[3])
                }
            }
        else
            runArgs = action.Args
        end
        
        table.insert(parsed, {
            Time = action.Time,
            Action = action.Action,
            Args = runArgs
        })
    end
    return parsed
end

-- ==========================================
-- HOOKING PEREKAMAN
-- ==========================================
local oldInvokeServer
oldInvokeServer = hookmetamethod(game, "__namecall", function(self, ...)
	local args = {...}
	local method = getnamecallmethod()
	
	if method == "InvokeServer" and isRecording then
		local elapsedTime = tick() - startTime
		if self == PlaceTower then
			table.insert(macroData, {Time = elapsedTime, Action = "Place", Args = {args[1]}})
			print(string.format("[RECORDED] Place pada %.2f", elapsedTime))
		elseif self == UpgradeTower then
			table.insert(macroData, {Time = elapsedTime, Action = "Upgrade", Args = {args[1]}})
			print(string.format("[RECORDED] Upgrade %s pada %.2f", tostring(args[1]), elapsedTime))
		elseif self == SellTower then
			table.insert(macroData, {Time = elapsedTime, Action = "Sell", Args = {args[1]}})
			print(string.format("[RECORDED] Sell %s pada %.2f", tostring(args[1]), elapsedTime))
		end
	end
	
	return oldInvokeServer(self, ...)
end)

-- ==========================================
-- PLAYBACK ENGINE (REPLY 1X SAJA DARI FILE)
-- ==========================================
local function playMacroFromFile()
	if not isfile(FILE_NAME) then 
		print("❌ File makro tidak ditemukan di folder executor kamu!")
		return 
	end
	
	-- Read dan Parse dari file teks txt
	local fileContent = readfile(FILE_NAME)
	local success, rawData = pcall(function() return HttpService:JSONDecode(fileContent) end)
	
	if not success or not rawData then
		print("❌ Gagal membaca atau merusak struktur file makro!")
		return
	end
	
	-- Ubah data teks menjadi data game siap pakai
	local playData = parseDataForPlaying(rawData)
	
	isPlaying = true
	print("--- ▶️ MEMULAI PUTAR MAKRO (1X SELESAI) ---")
	
	local macroStartTime = tick()
	local currentIndex = 1
	
	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not isPlaying or currentIndex > #playData then
			connection:Disconnect()
			isPlaying = false
			print("--- ⏹️ MAKRO TELAH SELESAI DIPUTAR 1X ---")
			return
		end
		
		local currentElapsedTime = tick() - macroStartTime
		local currentAction = playData[currentIndex]
		
		if currentElapsedTime >= currentAction.Time then
			local actionType = currentAction.Action
			local args = currentAction.Args
			
			if actionType == "Place" then
				task.spawn(function()
					print("[PLAY] Menaruh Tower dari file...")
					PlaceTower:InvokeServer(args[1])
				end)
			elseif actionType == "Upgrade" then
				task.spawn(function()
					print(string.format("[PLAY] Upgrade Tower Urutan Ke: %s", tostring(args[1])))
					UpgradeTower:InvokeServer(args[1])
				end)
			elseif actionType == "Sell" then
				task.spawn(function()
					print(string.format("[PLAY] Menjual Tower Urutan Ke: %s", tostring(args[1])))
					SellTower:InvokeServer(args[1])
				end)
			end
			
			currentIndex = currentIndex + 1
		end
	end)
end

-- ==========================================
-- UI CONTROLLER
-- ==========================================
recordButton.MouseButton1Click:Connect(function()
	if isPlaying then return end
	if not isRecording then
		macroData = {}
		isRecording = true
		startTime = tick()
		recordButton.BackgroundColor3 = Color3.fromRGB(255, 165, 0)
		recordButton.Text = "⏹️ STOP & SAVE"
		print("Perekaman Dimulai...")
	else
		isRecording = false
		recordButton.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
		recordButton.Text = "🔴 RECORD & SAVE"
		
		-- PROSES ENCODE DAN SAVE KE FILE TXT
		if #macroData > 0 then
			local cleanData = sanitizeDataForSaving(macroData)
			local jsonString = HttpService:JSONEncode(cleanData)
			writefile(FILE_NAME, jsonString)
			print("💾 BERHASIL! File makro disimpan dengan nama:", FILE_NAME)
		else
			print("⚠️ Gagal menyimpan karena data makro kosong.")
		end
	end
end)

playButton.MouseButton1Click:Connect(function()
	if isRecording or isPlaying then return end
	playMacroFromFile()
end)
