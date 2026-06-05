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
-- TRACKING URUTAN TOWER BERDASARKAN POSISI
-- ==========================================
local recordedTowerPositions = {} -- Menyimpan koordinat tempat naruh tower [index] = Vector3
local recordPlaceCount = 0

-- Fungsi mencari tower terdekat berdasarkan posisi remote unit saat record
local function findTowerIndexByClosestPosition(targetPos)
	if not targetPos or type(targetPos) ~= "Vector3" then return nil end
	local closestIndex = nil
	local closestDistance = 6 -- Toleransi jarak klik (6 studs)
	
	for idx, pos in ipairs(recordedTowerPositions) do
		local distance = (pos - targetPos).Magnitude
		if distance < closestDistance then
			closestDistance = distance
			closestIndex = idx
		end
	end
	return closestIndex
end

-- Fungsi pembantu untuk mencari koordinat object tower saat ini di Workspace
local function getTowerPositionFromWorkspace(towerId)
	for _, obj in pairs(workspace:GetDescendants()) do
		if obj:IsA("Model") then
			local id = obj:GetAttribute("ID") or obj:GetAttribute("UUID") or (obj:FindFirstChild("ID") and obj.ID.Value) or obj.Name
			if id == towerId then
				local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
				if part then
					return part.Position
				end
			end
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

-- ==========================================
-- HOOKING REMOTES
-- ==========================================
local oldInvokeServer
oldInvokeServer = hookmetamethod(game, "__namecall", function(self, ...)
	local args = {...}
	local method = getnamecallmethod()
	
	if method == "InvokeServer" and isRecording then
		if self == PlaceTower then
			recordPlaceCount = recordPlaceCount + 1
			local placePos = args[1]
			recordedTowerPositions[recordPlaceCount] = placePos -- Kunci koordinat penempatan
			
			logMacroAction("Place", {placePos, args[2], args[3], recordPlaceCount})
			
		elseif self == UpgradeTower then
			local targetId = args[1]
			-- Cari posisi fisik tower yang diklik di workspace untuk tahu ini tower index keberapa
			local currentPos = getTowerPositionFromWorkspace(targetId)
			local towerIdx = findTowerIndexByClosestPosition(currentPos)
			
			logMacroAction("Upgrade", {targetId, towerIdx})
			
		elseif self == SellTower then
			local targetId = args[1]
			local currentPos = getTowerPositionFromWorkspace(targetId)
			local towerIdx = findTowerIndexByClosestPosition(currentPos)
			
			logMacroAction("Sell", {targetId, towerIdx})
		end
	end
	
	return oldInvokeServer(self, ...)
end)

-- Fungsi mengambil ID dari Model
local function extractIdFromModel(model)
	return model:GetAttribute("ID") 
		or model:GetAttribute("UUID") 
		or (model:FindFirstChild("ID") and model.ID.Value)
		or (model:FindFirstChild("UUID") and model.UUID.Value)
		or model.Name
end

-- ==========================================
-- PLAYBACK ENGINE
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
	local currentPlacingIndex = 0 
	
	-- Menangkap ID Tower baru yang muncul di game secara real-time
	local mapConnection
	mapConnection = workspace.DescendantAdded:Connect(function(descendant)
		if not isPlaying then return end
		if descendant:IsA("Model") and descendant.Parent ~= player.Character and descendant.Name ~= player.Name then
			task.wait(0.1)
			local detectedId = extractIdFromModel(descendant)
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
				
				currentPlacingIndex = towerIndex 
				
				task.spawn(function()
					print(string.format("[PLAY] Menaruh Tower #%d ke posisi...", towerIndex))
					PlaceTower:InvokeServer(oldPosition, originalInventoryId, rotation)
				end)
				
			elseif actionType == "Upgrade" then
				local towerIndex = args[2]
				local oldId = args[1]
				
				task.spawn(function()
					if towerIndex then
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
						print("[ERROR] Indeks posisi tower tidak terdeteksi saat Record! Menggunakan ID Cadangan.")
						UpgradeTower:InvokeServer(oldId)
					end
				end)
				
			elseif actionType == "Sell" then
				local towerIndex = args[2]
				local oldId = args[1]
				
				task.spawn(function()
					if towerIndex then
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
						print("[ERROR] Indeks posisi tower tidak terdeteksi saat Record! Menggunakan ID Cadangan.")
						SellTower:InvokeServer(oldId)
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
		recordedTowerPositions = {}
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
