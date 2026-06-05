-- SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- REMOTES
local Events = ReplicatedStorage:WaitForChild("Events")
local PlaceTower = Events:WaitForChild("PlaceTower")
local UpgradeTower = Events:WaitForChild("UpgradeTower")
local SellTower = Events:WaitForChild("SellTower")

-- VARIABLES FOR MACRO
local macroData = {}
local isRecording = false
local isPlaying = false
local startTime = 0

-- UI Sederhana
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MacroTestingUI"
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
recordButton.Text = "🔴 RECORD"
recordButton.TextColor3 = Color3.fromRGB(255, 255, 255)
recordButton.Font = Enum.Font.SourceSansBold
recordButton.TextSize = 16
recordButton.Parent = frame

local playButton = Instance.new("TextButton")
playButton.Size = UDim2.new(0, 180, 0, 40)
playButton.Position = UDim2.new(0, 10, 0, 60)
playButton.BackgroundColor3 = Color3.fromRGB(40, 167, 69)
playButton.Text = "▶️ PLAY MACRO"
playButton.TextColor3 = Color3.fromRGB(255, 255, 255)
playButton.Font = Enum.Font.SourceSansBold
playButton.TextSize = 16
playButton.Parent = frame

-- ==========================================
-- HOOKING & PEREKAMAN (SISTEM INDEX ANTREAN)
-- ==========================================
local recordedTowersOrder = {} 
local recordPlaceCount = 0

local function getTowerIndex(oldId)
	for index, id in ipairs(recordedTowersOrder) do
		if id == oldId then
			return index
		end
	end
	return nil
end

local function logMacroAction(actionType, args)
	if not isRecording then return end
	local elapsedTime = tick() - startTime
	
	table.insert(macroData, {
		Time = elapsedTime,
		Action = actionType,
		Args = args
	})
	print(string.format("[RECORDED] %s pada detik ke %.2f", actionType, elapsedTime))
end

local oldInvokeServer
oldInvokeServer = hookmetamethod(game, "__namecall", function(self, ...)
	local args = {...}
	local method = getnamecallmethod()
	
	if method == "InvokeServer" and isRecording then
		if self == PlaceTower then
			recordPlaceCount = recordPlaceCount + 1
			local oldId = args[2]
			recordedTowersOrder[recordPlaceCount] = oldId
			
			logMacroAction("Place", {args[1], oldId, args[3], recordPlaceCount})
		elseif self == UpgradeTower then
			local oldId = args[1]
			local towerIdx = getTowerIndex(oldId)
			logMacroAction("Upgrade", {oldId, towerIdx})
		elseif self == SellTower then
			local oldId = args[1]
			local towerIdx = getTowerIndex(oldId)
			logMacroAction("Sell", {oldId, towerIdx})
		end
	end
	
	return oldInvokeServer(self, ...)
end)

-- Fungsi pembantu untuk mencuri ID/UUID dari objek Model game
local function extractIdFromModel(model)
	return model:GetAttribute("ID") 
		or model:GetAttribute("UUID") 
		or (model:FindFirstChild("ID") and model.ID.Value)
		or (model:FindFirstChild("UUID") and model.UUID.Value)
		or model.Name
end

-- ==========================================
-- PLAYBACK ENGINE (REAL-TIME LISTENER)
-- ==========================================

local function playMacro()
	if #macroData == 0 then 
		print("Data makro kosong!")
		return 
	end
	
	isPlaying = true
	print("--- MEMULAI TRACK MAKRO ---")
	
	local macroStartTime = tick()
	local currentIndex = 1
	
	local spawnedTowersNewIds = {} 
	local currentPlacingIndex = 0 -- Melacak urutan tower keberapa yang sedang ditaruh saat PLAY
	
	-- [KUNCI PERBAIKAN]: Otomatis mengintip Workspace / Map game. 
	-- Begitu ada Model baru muncul, langsung ambil ID-nya dan masukkan ke urutan antrean!
	local mapConnection
	mapConnection = workspace.DescendantAdded:Connect(function(descendant)
		if not isPlaying then return end
		
		-- Pastikan yang muncul adalah Model dan bukan karakter player kita sendiri
		if descendant:IsA("Model") and descendant.Parent ~= player.Character and descendant.Name ~= player.Name then
			-- Tunggu 0.1 detik agar atribut/ID di dalam model tersebut selesai dimuat oleh server game
			task.wait(0.1)
			
			local detectedId = extractIdFromModel(descendant)
			-- Pastikan data ID yang ditarik bukan string kosong atau nama bawaan seperti "Model"
			if detectedId and detectedId ~= "Model" and currentPlacingIndex > 0 then
				if not spawnedTowersNewIds[currentPlacingIndex] then
					spawnedTowersNewIds[currentPlacingIndex] = detectedId
					print(string.format("[🔥 SYSTEM] Berhasil Mengunci ID Tower #%d -> %s", currentPlacingIndex, detectedId))
				end
			end
		end
	end)
	
	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not isPlaying or currentIndex > #macroData then
			connection:Disconnect()
			if mapConnection then mapConnection:Disconnect() end
			isPlaying = false
			print("--- MAKRO SELESAI DIPUTAR ---")
			return
		end
		
		local currentElapsedTime = tick() - macroStartTime
		local currentAction = macroData[currentIndex]
		
		if currentElapsedTime >= currentAction.Time then
			local actionType = currentAction.Action
			local args = currentAction.Args
			
			if actionType == "Place" then
				local oldPosition = args[1]
				local originalInventoryId = args[2] 
				local rotation = args[3]
				local towerIndex = args[4]
				
				currentPlacingIndex = towerIndex -- Naikkan index antrean aktif
				
				task.spawn(function()
					print(string.format("[PLAY] Menaruh Tower #%d ke posisi...", towerIndex))
					PlaceTower:InvokeServer(oldPosition, originalInventoryId, rotation)
				end)
				
			elseif actionType == "Upgrade" then
				local towerIndex = args[2]
				local oldId = args[1]
				
				task.spawn(function()
					if towerIndex then
						-- Menunggu maksimal 3 detik sampai objek tower lahir dan ID-nya tertangkap oleh Listener
						local timeout = 0
						while not spawnedTowersNewIds[towerIndex] and timeout < 3 do
							task.wait(0.05)
							timeout = timeout + 0.05
						end
						
						local realId = spawnedTowersNewIds[towerIndex]
						if realId then
							print(string.format("[PLAY] Mengupgrade Tower #%d dengan ID Terikat: %s", towerIndex, realId))
							UpgradeTower:InvokeServer(realId)
						else
							print(string.format("[ERROR] Gagal Upgrade Tower #%d karena ID Baru tidak tertangkap.", towerIndex))
						end
					else
						print("[ERROR] Tower Index tidak valid saat Upgrade!")
					end
				end)
				
			elseif actionType == "Sell" then
				local towerIndex = args[2]
				local oldId = args[1]
				
				task.spawn(function()
					if towerIndex then
						-- Menunggu maksimal 3 detik sampai objek tower lahir dan ID-nya tertangkap oleh Listener
						local timeout = 0
						while not spawnedTowersNewIds[towerIndex] and timeout < 3 do
							task.wait(0.05)
							timeout = timeout + 0.05
						end
						
						local realId = spawnedTowersNewIds[towerIndex]
						if realId then
							print(string.format("[PLAY] Menjual Tower #%d dengan ID Terikat: %s", towerIndex, realId))
							SellTower:InvokeServer(realId)
						else
							print(string.format("[ERROR] Gagal Sell Tower #%d karena ID Baru tidak tertangkap.", towerIndex))
						end
					else
						print("[ERROR] Tower Index tidak valid saat Sell!")
					end
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
		recordedTowersOrder = {}
		recordPlaceCount = 0
		isRecording = true
		startTime = tick()
		recordButton.BackgroundColor3 = Color3.fromRGB(255, 165, 0)
		recordButton.Text = "⏹️ STOP RECORD"
		print("Perekaman dimulai!")
	else
		isRecording = false
		recordButton.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
		recordButton.Text = "🔴 RECORD"
		print("Perekaman berhenti. Total aksi:", #macroData)
	end
end)

playButton.MouseButton1Click:Connect(function()
	if isRecording or isPlaying then return end
	playMacro()
end)
