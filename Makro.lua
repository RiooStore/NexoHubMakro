-- SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- REMOTES (Sesuai dengan kode yang kamu kirim)
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
screenGui.Name = "NoobTD_MacroUI"
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
-- LOGIKA PEREKAMAN (MURNI MENGIKUTI STRUKTUR GAME)
-- ==========================================
local function logMacroAction(actionType, args)
	if not isRecording then return end
	local elapsedTime = tick() - startTime
	
	table.insert(macroData, {
		Time = elapsedTime,
		Action = actionType,
		Args = args
	})
	print(string.format("[RECORDED] %s -> Detik: %.2f", actionType, elapsedTime))
end

local oldInvokeServer
oldInvokeServer = hookmetamethod(game, "__namecall", function(self, ...)
	local args = {...}
	local method = getnamecallmethod()
	
	if method == "InvokeServer" and isRecording then
		if self == PlaceTower then
			-- Simpan seluruh isi tabel argumen [1] yang berisi towerID, position, dll.
			logMacroAction("Place", {args[1]})
		elseif self == UpgradeTower then
			-- Simpan nomor urut string (misal: "3")
			logMacroAction("Upgrade", {args[1]})
		elseif self == SellTower then
			-- Simpan nomor urut string (misal: "1")
			logMacroAction("Sell", {args[1]})
		end
	end
	
	return oldInvokeServer(self, ...)
end)

-- ==========================================
-- PLAYBACK ENGINE (SUPER RINGAN & AKURAT)
-- ==========================================
local function playMacro()
	if #macroData == 0 then 
		print("Data makro kosong!")
		return 
	end
	
	isPlaying = true
	print("--- MEMULAI TRACK MAKRO NOOB TD ---")
	
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
				task.spawn(function()
					print("[PLAY] Menaruh Tower...")
					PlaceTower:InvokeServer(args[1])
				end)
				
			elseif actionType == "Upgrade" then
				task.spawn(function()
					print(string.format("[PLAY] Mengupgrade Tower Urutan Ke: %s", tostring(args[1])))
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
		recordButton.Text = "⏹️ STOP RECORD"
		print("Perekaman Noob TD Dimulai!")
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
