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
-- METODE SCANNING TOTAL (MENCARI ID BARU DI WORKSPACE)
-- ==========================================
local function findNewUnitIdByPosition(oldTargetPosition)
	local closestModel = nil
	local closestDistance = 6 -- Toleransi jarak 6 studs
	
	-- Kita cek semua object di Workspace
	for _, obj in pairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and obj.Parent ~= player.Character then
			-- Coba cari BasePart di dalam model untuk dihitung posisinya
			local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
			if part then
				local distance = (part.Position - oldTargetPosition).Magnitude
				if distance < closestDistance then
					closestDistance = distance
					closestModel = obj
				end
			end
		end
	end
	
	if closestModel then
		-- Trik Terakhir: Ekstrak ID dari segala kemungkinan tempat penyimpanan di Roblox
		local possibleId = closestModel:GetAttribute("ID") 
			or closestModel:GetAttribute("UUID") 
			or (closestModel:FindFirstChild("ID") and closestModel.ID.Value)
			or (closestModel:FindFirstChild("UUID") and closestModel.UUID.Value)
			or closestModel.Name -- Jika nama modelnya adalah ID-nya
			
		return possibleId
	end
	return nil
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
	local idMappingTable = {} 
	
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
					PlaceTower:InvokeServer(oldPosition, oldId, rotation)
					
					-- Beri jeda 0.5 detik agar game selesai memunculkan model towernya di map
					task.wait(0.5)
					local foundId = findNewUnitIdByPosition(oldPosition)
					
					if foundId then
						idMappingTable[oldId] = foundId
						print("[SYSTEM] Berhasil Menangkap ID Baru dari Map:", foundId)
					else
						-- Jika scan gagal, pakai ID lama sebagai tebakan terakhir
						idMappingTable[oldId] = oldId
						print("[WARN] Gagal scan ID baru, terpaksa menggunakan ID Cadangan.")
					end
				end)
				
			elseif actionType == "Upgrade" then
				local oldId = args[1]
				
				task.spawn(function()
					-- Menunggu sampai sistem "Place" selesai memetakan ID Baru (max 2 detik)
					local timeout = 0
					while not idMappingTable[oldId] and timeout < 2 do
						task.wait(0.05)
						timeout = timeout + 0.05
					end
					
					local realId = idMappingTable[oldId] or oldId
					print("[PLAY] Mengupgrade Tower dengan ID:", realId)
					UpgradeTower:InvokeServer(realId)
				end)
				
			elseif actionType == "Sell" then
				local oldId = args[1]
				
				task.spawn(function()
					-- Menunggu sampai sistem "Place" selesai memetakan ID Baru (max 2 detik)
					local timeout = 0
					while not idMappingTable[oldId] and timeout < 2 do
						task.wait(0.05)
						timeout = timeout + 0.05
					end
					
					local realId = idMappingTable[oldId] or oldId
					print("[PLAY] Menjual Tower dengan ID:", realId)
					SellTower:InvokeServer(realId)
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
