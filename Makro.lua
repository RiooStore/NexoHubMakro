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
-- HOOKING REMOTES
-- ==========================================

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
			logMacroAction("Place", {args[1], args[2], args[3]})
		elseif self == UpgradeTower then
			logMacroAction("Upgrade", {args[1]})
		elseif self == SellTower then
			logMacroAction("Sell", {args[1]})
		end
	end
	
	return oldInvokeServer(self, ...)
end)

-- ==========================================
-- BACKUP METHOD: MENCARI ID BERDASARKAN POSISI
-- ==========================================
local function findNewUnitIdByPosition(oldTargetPosition)
	local closestModel = nil
	local closestDistance = 5
	
	for _, obj in pairs(workspace:GetDescendants()) do
		if obj:IsA("Model") then
			local primary = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
			if primary then
				local distance = (primary.Position - oldTargetPosition).Magnitude
				if distance < closestDistance then
					closestDistance = distance
					closestModel = obj
				end
			end
		end
	end
	
	if closestModel then
		local detectedId = closestModel:GetAttribute("ID") 
			or closestModel:GetAttribute("UUID") 
			or (closestModel:FindFirstChild("ID") and closestModel.ID.Value)
			or closestModel.Name
		return detectedId
	end
	return nil
end

-- ==========================================
-- PLAYBACK ENGINE (PEMUTAR MAKRO YANG DIPERBAIKI)
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
	local idMappingTable = {} -- Menghubungkan ID_Lama -> ID_Baru
	
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
				
				task.spawn(function()
					print("[PLAY] Menyebarkan Tower ke posisi...", tostring(oldPosition))
					local serverResponse = PlaceTower:InvokeServer(oldPosition, oldId, rotation)
					
					if serverResponse and type(serverResponse) == "string" then
						idMappingTable[oldId] = serverResponse
						print("[SYSTEM] ID Baru terpetakan dari Server:", serverResponse)
					else
						-- Tunggu sebentar sampai model tower benar-benar muncul di workspace
						task.wait(0.3)
						local foundId = findNewUnitIdByPosition(oldPosition)
						if foundId then
							idMappingTable[oldId] = foundId
							print("[SYSTEM] ID Baru terpetakan dari Posisi:", foundId)
						else
							print("[WARN] Gagal mendeteksi ID baru di posisi:", tostring(oldPosition))
						end
					end
				end)
				
			elseif actionType == "Upgrade" then
				local oldId = args[1]
				
				task.spawn(function()
					-- PERBAIKAN: Tunggu hingga ID baru tersedia (maksimal menunggu 3 detik)
					local timeout = 0
					while not idMappingTable[oldId] and timeout < 3 do
						task.wait(0.1)
						timeout = timeout + 0.1
					end
					
					local realId = idMappingTable[oldId]
					if realId then
						print("[PLAY] Mengupgrade Tower dengan ID:", realId)
						UpgradeTower:InvokeServer(realId)
					else
						print("[ERROR] Batas waktu habis, memaksa Upgrade dengan ID Cadangan...")
						UpgradeTower:InvokeServer(oldId)
					end
				end)
				
			elseif actionType == "Sell" then
				local oldId = args[1]
				
				task.spawn(function()
					-- PERBAIKAN: Tunggu hingga ID baru tersedia (maksimal menunggu 3 detik)
					local timeout = 0
					while not idMappingTable[oldId] and timeout < 3 do
						task.wait(0.1)
						timeout = timeout + 0.1
					end
					
					local realId = idMappingTable[oldId]
					if realId then
						print("[PLAY] Menjual Tower dengan ID:", realId)
						SellTower:InvokeServer(realId)
					else
						print("[ERROR] Batas waktu habis, memaksa Sell dengan ID Cadangan...")
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
