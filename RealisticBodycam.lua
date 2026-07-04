-- SCRIPT CHIẾN THUẬT CAMERA V3 (DELTA EXECUTOR) - THÊM NÚT CHẠY NHANH TỐC ĐỘ 27
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Dọn dẹp UI cũ chống trùng lặp
if CoreGui:FindFirstChild("TacticalCamUI") then CoreGui["TacticalCamUI"]:Destroy() end
if Lighting:FindFirstChild("TacticalColor") then Lighting["TacticalColor"]:Destroy() end

-- ================= TRẠNG THÁI =================
local isCamActive = false
local isZoomed = false
local isFlashlightOn = false
local isChamsOn = false
local isSprinting = false -- Trạng thái chạy nhanh
local startTime = 0
local isBlinking = false 

-- ================= KHỞI TẠO UI =================
local gui = Instance.new("ScreenGui")
gui.Name = "TacticalCamUI"
gui.IgnoreGuiInset = true
gui.Parent = CoreGui

-- Nút bật Cam tròn (Có tính năng Kéo rê - Drag)
local openBtn = Instance.new("TextButton", gui)
openBtn.Size = UDim2.new(0, 55, 0, 55)
openBtn.Position = UDim2.new(1, -85, 1, -210)
openBtn.Text = "📷"
openBtn.TextSize = 25
openBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
openBtn.BackgroundTransparency = 0.4
openBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
Instance.new("UICorner", openBtn).CornerRadius = UDim.new(1, 0)
local stroke1 = Instance.new("UIStroke", openBtn); stroke1.Color = Color3.fromRGB(255,255,255); stroke1.Thickness = 2

-- Khung giao diện chính khi bật cam
local camFrame = Instance.new("Frame", gui)
camFrame.Size = UDim2.new(1, 0, 1, 0)
camFrame.BackgroundTransparency = 1
camFrame.Visible = false

-- Màn đen phục vụ hiệu ứng chớp mắt (Blink)
local blinkFrame = Instance.new("Frame", camFrame)
blinkFrame.Size = UDim2.new(1, 0, 1, 0)
blinkFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
blinkFrame.BackgroundTransparency = 1 
blinkFrame.ZIndex = 10 

local closeBtn = Instance.new("TextButton", camFrame)
closeBtn.Size = UDim2.new(0, 40, 0, 40)
closeBtn.Position = UDim2.new(1, -60, 0, 25)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 0, 0)
closeBtn.TextSize = 26
closeBtn.BackgroundTransparency = 1
closeBtn.Font = Enum.Font.FredokaOne

local recLabel = Instance.new("TextLabel", camFrame)
recLabel.Size = UDim2.new(0, 100, 0, 40)
recLabel.Position = UDim2.new(1, -170, 0, 25)
recLabel.Text = "● REC"
recLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
recLabel.TextSize = 26
recLabel.BackgroundTransparency = 1
recLabel.Font = Enum.Font.FredokaOne
recLabel.TextXAlignment = Enum.TextXAlignment.Right

local timerLabel = Instance.new("TextLabel", camFrame)
timerLabel.Size = UDim2.new(0, 200, 0, 40)
timerLabel.Position = UDim2.new(0.5, -100, 0, 40)
timerLabel.Text = "00:00:00"
timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
timerLabel.TextSize = 24
timerLabel.BackgroundTransparency = 1
timerLabel.Font = Enum.Font.Code

local dateLabel = Instance.new("TextLabel", camFrame)
dateLabel.Size = UDim2.new(0, 250, 0, 60)
dateLabel.Position = UDim2.new(0, 30, 1, -90)
dateLabel.Text = "AM 9:38\nNOW. 04/07/2026"
dateLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
dateLabel.TextSize = 18
dateLabel.BackgroundTransparency = 1
dateLabel.Font = Enum.Font.Code
dateLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Hàm tạo các nút menu bên phải một cách tự động và thẳng hàng
local function createMenuButton(text, posIndex)
	local btn = Instance.new("TextButton", camFrame)
	btn.Size = UDim2.new(0, 50, 0, 50)
	-- Khoảng cách các nút được tính toán lại dựa trên posIndex để không bị đè lên nhau
	btn.Position = UDim2.new(1, -75, 0.5, (posIndex * 60) - 90)
	btn.Text = text
	btn.TextSize = 24
	btn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	btn.BackgroundTransparency = 0.5
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
	Instance.new("UIStroke", btn).Color = Color3.fromRGB(255, 255, 255)
	return btn
end

-- Tạo 4 nút chức năng theo thứ tự từ trên xuống dưới
local zoomBtn = createMenuButton("🔍", -1)  -- Nút Kính ngắm
local lightBtn = createMenuButton("🔦", 0)   -- Nút Đèn pin
local chamsBtn = createMenuButton("👁️", 1)   -- Nút Nhìn xuyên tường
local sprintBtn = createMenuButton("🏃", 2)  -- Nút Chạy nhanh mới thêm

-- ================= HỆ THỐNG MÀU SẮC =================
local colorEffect = Instance.new("ColorCorrectionEffect")
colorEffect.Name = "TacticalColor"
colorEffect.Enabled = false
colorEffect.Parent = Lighting

local function applyColorWhiteBlack()
	colorEffect.TintColor = Color3.fromRGB(255, 255, 255)
	colorEffect.Saturation = -1 
	colorEffect.Contrast = 0.2   
	colorEffect.Brightness = 0.05
end

local function applyColorGreen()
	colorEffect.TintColor = Color3.fromRGB(130, 255, 130) 
	colorEffect.Saturation = 0.5 
	colorEffect.Contrast = 0.4
	colorEffect.Brightness = 0.15
end

-- ================= LOGIC KÉO RÊ NÚT (DRAG BUTTON) =================
local dragging, dragInput, dragStart, startPos
openBtn.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = openBtn.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then dragging = false end
		end)
	end
end)
openBtn.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		dragInput = input
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if input == dragInput and dragging then
		local delta = input.Position - dragStart
		openBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)

-- ================= HÀM XỬ LÝ CHAMS & ĐÈN PIN =================
local function toggleFlashlight(state)
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if head then
		local light = head:FindFirstChild("CamFlashlight")
		if state then
			if not light then
				light = Instance.new("SpotLight")
				light.Name = "CamFlashlight"
				light.Brightness = 4; light.Range = 70; light.Angle = 50
				light.Parent = head
			end
			light.Enabled = true
		else
			if light then light.Enabled = false end
		end
	end
end

local function updateChams()
	for _, p in pairs(Players:GetPlayers()) do
		if p ~= player and p.Character then
			local highlight = p.Character:FindFirstChild("CamChams")
			if isChamsOn and isCamActive and not isBlinking then
				if not highlight then
					highlight = Instance.new("Highlight")
					highlight.Name = "CamChams"
					highlight.FillTransparency = 1
					highlight.OutlineColor = Color3.fromRGB(0, 255, 100)
					highlight.OutlineTransparency = 0
					highlight.Parent = p.Character
				end
			else
				if highlight then highlight:Destroy() end
			end
		end
	end
end

-- ================= HÀM CHỚP MẮT CHẬM (BLINK EFFECT) =================
local function playBlinkEffect(callback)
	isBlinking = true
	for i = 1, 0, -0.1 do
		blinkFrame.BackgroundTransparency = i
		task.wait(0.04)
	end
	blinkFrame.BackgroundTransparency = 0
	
	callback() 
	task.wait(0.2) 
	
	for i = 0, 1, 0.1 do
		blinkFrame.BackgroundTransparency = i
		task.wait(0.04)
	end
	blinkFrame.BackgroundTransparency = 1
	isBlinking = false
	updateChams() 
end

-- ================= SỰ KIỆN NÚT BẤM =================
openBtn.MouseButton1Click:Connect(function()
	if dragging then return end 
	isCamActive = true
	openBtn.Visible = false
	camFrame.Visible = true
	
	applyColorWhiteBlack() 
	colorEffect.Enabled = true
	
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	startTime = tick()
end)

closeBtn.MouseButton1Click:Connect(function()
	isCamActive = false
	openBtn.Visible = true
	camFrame.Visible = false
	colorEffect.Enabled = false
	player.CameraMode = Enum.CameraMode.Classic
	
	isZoomed = false; camera.FieldOfView = 70
	isFlashlightOn = false; toggleFlashlight(false)
	isChamsOn = false; updateChams()
	
	-- Tắt chế độ chạy nhanh khi thoát camera
	isSprinting = false
	if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
		humanoid.CameraOffset = Vector3.new(0, 0, 0)
		humanoid.WalkSpeed = 16 -- Trả lại tốc độ mặc định
	end
end)

zoomBtn.MouseButton1Click:Connect(function()
	isZoomed = not isZoomed
	camera.FieldOfView = isZoomed and 30 or 70
end)

lightBtn.MouseButton1Click:Connect(function()
	isFlashlightOn = not isFlashlightOn
	toggleFlashlight(isFlashlightOn)
end)

chamsBtn.MouseButton1Click:Connect(function()
	if isBlinking then return end 
	isChamsOn = not isChamsOn
	
	playBlinkEffect(function()
		if isChamsOn then
			applyColorGreen() 
		else
			applyColorWhiteBlack() 
		end
	end)
end)

-- Sự kiện nhấn nút Chạy nhanh 🏃
sprintBtn.MouseButton1Click:Connect(function()
	isSprinting = not isSprinting
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	
	if humanoid then
		if isSprinting then
			humanoid.WalkSpeed = 27 -- Đặt tốc độ chạy nhanh là 27 theo yêu cầu
			sprintBtn.BackgroundColor3 = Color3.fromRGB(0, 255, 100) -- Đổi viền/nền sang xanh để báo đang bật
			sprintBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
		else
			humanoid.WalkSpeed = 16 -- Tắt đi trả về tốc độ chạy thường 16
			sprintBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
			sprintBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
	end
end)

-- ================= VÒNG LẶP HỆ THỐNG CẬP NHẬT GÓC NHÌN =================
RunService.RenderStepped:Connect(function()
	if not isCamActive then return end
	
	local char = player.Character
	if char then
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.CameraOffset = Vector3.new(0, 0.4, -1.2)
			
			-- Giữ tốc độ luôn là 27 nếu đang bật nút 🏃 (Đề phòng game tự reset tốc độ nhân vật)
			if isSprinting and humanoid.WalkSpeed ~= 27 then
				humanoid.WalkSpeed = 27
			elseif not isSprinting and humanoid.WalkSpeed == 27 then
				humanoid.WalkSpeed = 16
			end
		end
		
		for _, part in pairs(char:GetDescendants()) do
			if part:IsA("BasePart") then
				if part.Name == "Head" or part.Parent:IsA("Accessory") then
					part.LocalTransparencyModifier = 1 
				else
					part.LocalTransparencyModifier = 0 
				end
			end
		end
	end
	
	-- Cập nhật bộ đếm thời gian
	local elapsed = tick() - startTime
	local mins = math.floor(elapsed / 60)
	local secs = math.floor(elapsed % 60)
	local milsecs = math.floor((elapsed * 100) % 100)
	timerLabel.Text = string.format("%02d:%02d:%02d", mins, secs, milsecs)
	
	-- Cập nhật đồng hồ hệ thống thực tế
	local date = os.date("*t")
	local ampm = date.hour >= 12 and "PM" or "AM"
	local hour = date.hour % 12
	if hour == 0 then hour = 12 end
	dateLabel.Text = string.format("%s. %d:%02d\nNOW. %02d/%02d/%04d", ampm, hour, date.min, date.day, date.month, date.year)
	
	if isChamsOn and not isBlinking then updateChams() end
end)

-- Nhấp nháy chữ ● REC
task.spawn(function()
	while true do
		task.wait(0.5)
		if isCamActive then
			recLabel.Visible = not recLabel.Visible
		end
	end
end)
