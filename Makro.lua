-- SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- REMOTES (Sesuaikan nama remote jika berbeda)
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
frame.Parent = frame.Parent

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
-- LOGIKA PEMETAAN ANTREAN (MURNI STRUKTUR)
-- ==========================================
local recordTowersLog = {} -- Mencatat ID saat record [Urutan] = ID_Lama
local recordPlaceCount = 0

-- Mencari tahu remote upgrade/sell ini merujuk ke tower urutan keberapa saat record
local function findTowerIndexByRecordId(targetId)
	for idx, id in ipairs(recordTowersLog) do
		if id == targetId then
			return idx
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
-- HOOKING SENJATA UTAMA (METAMETHOD NESTING)
-- ==========================================
local spawnedTowersNewIds = {} -- Menampung ID Baru saat PLAY [Urutan] = ID_Baru_Server
local currentPlacingIndex = 0  -- Melacak penempatan aktif saat PLAY

local oldInvokeServer
oldInvokeServer = hookmetamethod(game, "__namecall", function(self, ...)
	local args = {...}
	local method = getnamecallmethod()
	
	-- 1. LOGIKA SAAT RECORD
	if method == "InvokeServer" and isRecording then
		if self == PlaceTower then
			recordPlaceCount = recordPlaceCount + 1
			local placedInventoryId = args[2]
			recordTowersLog[recordPlaceCount] = placedInventoryId
			
			logMacroAction("Place", {args[1], placedInventoryId, args[3], recordPlaceCount})
			
		elseif self == UpgradeTower then
			local targetId = args[1]
			local towerIdx = findTowerIndexByRecordId(targetId) or recordPlaceCount
			logMacroAction("Upgrade", {towerIdx})
			
		elseif self == SellTower then
			local targetId = args[1]
			local towerIdx = findTowerIndexByRecordId(targetId) or recordPlaceCount
			logMacroAction("Sell", {towerIdx})
		end
	end
	
	-- 2. LOGIKA INTERUPSI JARINGAN SAAT PLAY (MENANGKAP RETURN VALUE DARI SERVER)
	if method == "InvokeServer" and isPlaying and self == PlaceTower then
		-- Jalankan fungsi asli ke server dan TANGKAP hasilnya langsung!
		-- Biasanya InvokeServer dari PlaceTower mengembalikan Object Model atau String ID Baru dari server.
		local serverResponse = oldInvokeServer(self, ...)
		
		local targetIndex = currentPlacingIndex
		if serverResponse then
			local detectedId = nil
			if type(serverResponse) == "string" then
				detectedId = serverResponse
			elseif typeof(serverResponse) == "Instance" and serverResponse:IsA("Model") then
				detectedId = serverResponse:GetAttribute("ID") or serverResponse:GetAttribute("UUID") or (serverResponse:FindFirstChild("ID") and serverResponse.ID.Value) or serverResponse.Name
			end
			
			if detectedId then
				spawnedTowersNewIds[targetIndex] = detectedId
				print(string.format("[🔥 COUGHT] Server membalas! Tower #%d dapat ID: %s", targetIndex, detectedId))
			end
		end
		
		-- Jika server tidak mengembalikan apa-apa, jalankan backup instan via scan atribut tercepat
		if not spawnedTowersNewIds[targetIndex] then
			task.spawn(function()
				task.wait(0.05) -- Hanya tunggu 50 milidetik
				for _, obj in pairs(workspace:GetDescendants()) do
					if obj:IsA("Model") and obj.Parent ~= player.Character and obj.Name ~= player.Name and obj.Name ~= "Model" then
						local id = obj:GetAttribute("ID") or obj:GetAttribute("UUID") or (obj:FindFirstChild("ID") and obj.ID.Value)
						if id and not table.find(spawnedTowersNewIds, id) then
							spawnedTowersNewIds[targetIndex] = id
							print(string.format("[⚡ BACKUP] Berhasil ikat ID Tower #%d -> %s", targetIndex, id))
							break
						end
					end
				end
			end)
		end
		
		return serverResponse
	end
	
	return oldInvokeServer(self, ...)
end)

-- ==========================================
-- PLAYBACK ENGINE (PENGGUNA ID SINKRON)
-- ==========================================
local function playMacro()
	if #macroData == 0 then 
		print("Data makro kosong!")
		return 
	end
	
	isPlaying = true
	spawnedTowersNewIds = {}
	print("--- MEMULAI TRACK MAKRO ---")
	
	local macroStartTime = tick()
	local currentIndex = 1
	
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
				local originalInventoryId = args[2] 
				local rotation = args[3]
				local towerIndex = args[4]
				
				currentPlacingIndex = towerIndex -- Set urutan tower aktif sebelum invoke
				
				task.spawn(function()
					print(string.format("[PLAY] Menaruh Tower #%d...", towerIndex))
					PlaceTower:InvokeServer(oldPosition, originalInventoryId, rotation)
				end)
				
			elseif actionType == "Upgrade" then
				local towerIndex = args[1]
				
				task.spawn(function()
					if towerIndex then
						-- Tunggu maksimal 2 detik hingga ID tower tersebut lahir dan tertangkap oleh hook
						local timeout = 0
						while not spawnedTowersNewIds[towerIndex] and timeout < 2 do
							task.wait(0.05)
							timeout = timeout + 0.05
						end
						
						local realId = spawnedTowersNewIds[towerIndex]
						if realId then
							print(string.format("[PLAY] Mengupgrade Tower #%d menggunakan ID hasil Place: %s", towerIndex, realId))
							UpgradeTower:InvokeServer(realId)
						else
							print(string.format("[ERROR] Lewati Upgrade Tower #%d karena ID gagal ditangkap.", towerIndex))
						end
					end
				end)
				
			elseif actionType == "Sell" then
				local towerIndex = args[1]
				
				task.spawn(function()
					if towerIndex then
						local timeout = 0
						while not spawnedTowersNewIds[towerIndex] and timeout < 2 do
							task.wait(0.05)
							timeout = timeout + 0.05
						end
						
						local realId = spawnedTowersNewIds[towerIndex]
						if realId then
							print(string.format("[PLAY] Menjual Tower #%d menggunakan ID hasil Place: %s", towerIndex, realId))
							SellTower:InvokeServer(realId)
						else
							print(string.format("[ERROR] Lewati Sell Tower #%d karena ID gagal ditangkap.", towerIndex))
						end
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
		recordTowersLog = {}
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
