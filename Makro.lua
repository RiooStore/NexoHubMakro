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
-- HOOKING & PEREKAMAN (URUTAN INDEX)
-- ==========================================
local recordedTowersOrder = {} -- Mencatat urutan ID lama pas record
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
			recordedTowersOrder[recordPlaceCount] = oldId -- Simpan urutan ID lamanya
			
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

-- ==========================================
-- BACKUP SCANNER (MENCARI ID BARU DI KOORDINAT)
-- ==========================================
local function scanNewTowerIdAtPosition(targetPos)
	local closestModel = nil
	local closestDistance = 5
	
	for _, obj in pairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and obj.Parent ~= player.Character then
			local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
			if part then
				local distance = (part.Position - targetPos).Magnitude
				if distance < closestDistance then
					closestDistance = distance
					closestModel = obj
				end
			end
		end
	end
	
	if closestModel then
		return closestModel:GetAttribute("ID") 
			or closestModel:GetAttribute("UUID") 
			or (closestModel:FindFirstChild("ID") and closestModel.ID.Value)
			or closestModel.Name
	end
	return nil
end

-- ==========================================
-- PLAYBACK ENGINE (ANTI-MELESET)
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
	
	-- Tabel penampung ID Baru berdasarkan urutan/index tower [index] = ID_Baru
	local spawnedTowersNewIds = {} 
	
	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not isPlaying or currentIndex > #macroData then
			connection:Disconnect()
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
				local oldId = args[2]
				local rotation = args[3]
				local towerIndex = args[4] -- Nomor urut tower ini (misal: Tower ke-1)
				
				task.spawn(function()
					print(string.format("[PLAY] Menaruh Tower #%d ke posisi...", towerIndex))
					local serverResponse = PlaceTower:InvokeServer(oldPosition, oldId, rotation)
					
					-- Coba ambil ID baru langsung dari respon server dulu
					if serverResponse and type(serverResponse) == "string" then
						spawnedTowersNewIds[towerIndex] = serverResponse
						print(string.format("[SYSTEM] Tower #%d Terdaftar dengan ID: %s", towerIndex, serverResponse))
					else
						-- Jika server tidak me-return ID, tunggu objek muncul lalu scan map
						task.wait(0.4)
						local foundId = scanNewTowerIdAtPosition(oldPosition)
						if foundId then
							spawnedTowersNewIds[towerIndex] = foundId
							print(string.format("[SYSTEM] Tower #%d Terdaftar via Scan Map: %s", towerIndex, foundId))
						else
							-- Jika gagal total, gunakan ID lama sebagai fallback terpaksa
							spawnedTowersNewIds[towerIndex] = oldId
							print(string.format("[WARN] Gagal total scan ID Tower #%d. Menggunakan ID Cadangan.", towerIndex))
						end
					end
				end)
				
			elseif actionType == "Upgrade" then
				local oldId = args[1]
				local towerIndex = args[2] -- Kita cari berdasarkan urutan nomor towernya, bukan string ID lamanya
				
				task.spawn(function()
					if towerIndex then
						-- Menunggu sampai Tower dengan urutan index tersebut selesai mendapatkan ID barunya
						local timeout = 0
						while not spawnedTowersNewIds[towerIndex] and timeout < 2.5 do
							task.wait(0.05)
							timeout = timeout + 0.05
						end
						
						local realId = spawnedTowersNewIds[towerIndex] or oldId
						print(string.format("[PLAY] Mengupgrade Tower #%d dengan ID Baru: %s", towerIndex, realId))
						UpgradeTower:InvokeServer(realId)
					else
						print("[ERROR] Urutan indeks tower tidak valid, memaksa dengan ID lama.")
						UpgradeTower:InvokeServer(oldId)
					end
				end)
				
			elseif actionType == "Sell" then
				local oldId = args[1]
				local towerIndex = args[2]
				
				task.spawn(function()
					if towerIndex then
						-- Menunggu sampai Tower dengan urutan index tersebut selesai mendapatkan ID barunya
						local timeout = 0
						while not spawnedTowersNewIds[towerIndex] and timeout < 2.5 do
							task.wait(0.05)
							timeout = timeout + 0.05
						end
						
						local realId = spawnedTowersNewIds[towerIndex] or oldId
						print(string.format("[PLAY] Menjual Tower #%d dengan ID Baru: %s", towerIndex, realId))
						SellTower:InvokeServer(realId)
					else
						print("[ERROR] Urutan indeks tower tidak valid, memaksa dengan ID lama.")
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
