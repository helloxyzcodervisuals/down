repeat task.wait() until game:IsLoaded()

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local Debris = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Anti-Cheat Bypass
do
    local function isAdonisAC(tab)
        return rawget(tab, "Detected") and typeof(rawget(tab, "Detected")) == "function" and rawget(tab, "RLocked")
    end
    
    for _, v in next, getgc(true) do
        if typeof(v) == "table" and isAdonisAC(v) then
            for i, f in next, v do
                if rawequal(i, "Detected") then
                    local old = f
                    hookfunction(old, function(action, info, crash)
                        if rawequal(action, "_") and rawequal(info, "_") and rawequal(crash, false) then
                            return old(action, info, crash)
                        end
                        return task.wait(9e9)
                    end)
                    break
                end
            end
            break
        end
    end
    
    for _, v in pairs(getgc(true)) do
        if type(v) == "table" then
            local func = rawget(v, "DTXC1")
            if type(func) == "function" then
                hookfunction(func, function() end)
                break
            end
        end
    end
end

-- Utility Functions (Cached)
local TableUtils = {
    contains = function(t, value)
        for i = 1, #t do
            if t[i] == value then
                return true
            end
        end
        return false
    end,
    remove = function(t, value)
        for i = 1, #t do
            if t[i] == value then
                table.remove(t, i)
                return true
            end
        end
        return false
    end
}

local VectorUtils = {
    magnitude2D = function(v1, v2)
        local dx = v2.X - v1.X
        local dy = v2.Y - v1.Y
        return dx * dx + dy * dy
    end
}

local RaycastUtils = {
    cache = {},
    params = RaycastParams.new(),
    
    visible = function(origin, target, ignore)
        RaycastUtils.params.FilterType = Enum.RaycastFilterType.Blacklist
        RaycastUtils.params.FilterDescendantsInstances = ignore
        
        local direction = target.Position - origin.Position
        local result = Workspace:Raycast(origin.Position, direction, RaycastUtils.params)
        
        if result then
            local hitChar = result.Instance:FindFirstAncestorOfClass("Model")
            return hitChar == target.Parent
        end
        return true
    end
}

-- Player Management (Optimized)
local TargetList = {}
local Whitelist = {}

-- Font Management (Cached)
local CustomFont = Font.fromEnum(Enum.Font.Code)
do
    local success, result = pcall(function()
        local folder = "FontCache_" .. tostring(math.random(10000, 99999))
        makefolder(folder)
        
        local ttfPath = folder .. "/font.ttf"
        local jsonPath = folder .. "/font.json"
        
        local response = request({
            Url = "https://raw.githubusercontent.com/bluescan/proggyfonts/refs/heads/master/ProggyOriginal/ProggyClean.ttf",
            Method = "GET"
        })
        
        if response and response.Success then
            writefile(ttfPath, response.Body)
            
            local fontData = {
                name = "CustomFont",
                faces = {{
                    name = "Regular",
                    weight = 400,
                    style = "Normal",
                    assetId = getcustomasset(ttfPath)
                }}
            }
            
            writefile(jsonPath, HttpService:JSONEncode(fontData))
            CustomFont = Font.new(getcustomasset(jsonPath))
        end
    end)
    
    if not success then
        CustomFont = Font.fromEnum(Enum.Font.Code)
    end
end

-- Legit Aimbot Module (Optimized)
local LegitAimbotModule = {
    Enabled = false,
    Settings = {
        FOV = 120,
        FOVSqr = 14400,
        Smoothness = 40,
        SmoothFactor = 0.06,
        VisibleCheck = true,
        ForcefieldCheck = true,
        DownedCheck = true,
        DiedCheck = true,
        TeamCheck = true,
        AimKey = Enum.KeyCode.LeftAlt,
        UseKeybind = true
    },
    ArmChams = {
        Enabled = false,
        OriginalTransparency = {},
        OriginalMaterial = {},
        TransparencyValue = 0.5
    },
    ItemsChams = {
        Enabled = false,
        OriginalData = {},
        TransparencyValue = 0.5
    },
    Connection = nil,
    ViewModel = nil,
    RightArm = nil,
    LeftArm = nil,
    CacheValid = false
}

do
    local camera = Camera
    local localPlayer = LocalPlayer
    local runService = RunService
    local userInput = UserInputService
    
    function LegitAimbotModule:UpdateCache()
        local vm = camera:FindFirstChild("ViewModel")
        self.ViewModel = vm
        if vm then
            self.RightArm = vm:FindFirstChild("Right Arm")
            self.LeftArm = vm:FindFirstChild("Left Arm")
        else
            self.RightArm = nil
            self.LeftArm = nil
        end
        self.CacheValid = true
    end
    
    function LegitAimbotModule:GetArms()
        if not self.CacheValid or not self.ViewModel or not self.ViewModel.Parent then
            self:UpdateCache()
        end
        return self.RightArm, self.LeftArm
    end
    
    function LegitAimbotModule:IsValidTarget(player, character, head, humanoid)
        if not character or not head or not humanoid then return false end
        if humanoid.Health <= 0 then return false end
        if self.Settings.DiedCheck and humanoid.Health <= 0 then return false end
        if self.Settings.DownedCheck and humanoid.Health < 15 then return false end
        if self.Settings.ForcefieldCheck and character:FindFirstChildOfClass("ForceField") then return false end
        return true
    end
    
    function LegitAimbotModule:GetClosestPlayer()
        local closest = nil
        local closestDistSqr = self.Settings.FOV * self.Settings.FOV
        local camera = camera
        local centerX = camera.ViewportSize.X * 0.5
        local centerY = camera.ViewportSize.Y * 0.5
        local localChar = localPlayer.Character
        local localHead = localChar and localChar:FindFirstChild("Head")
        
        for _, player in ipairs(Players:GetPlayers()) do
            if player == localPlayer then continue end
            if self.Settings.TeamCheck and player.Team == localPlayer.Team then continue end
            
            local character = player.Character
            if not character then continue end
            
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            local head = character:FindFirstChild("Head")
            
            if not self:IsValidTarget(player, character, head, humanoid) then
                continue
            end
            
            local screenPoint = camera:WorldToViewportPoint(head.Position)
            if screenPoint.Z > 0 then
                local dx = screenPoint.X - centerX
                local dy = screenPoint.Y - centerY
                local distSqr = dx * dx + dy * dy
                
                if distSqr < closestDistSqr then
                    if self.Settings.VisibleCheck and localHead then
                        if not RaycastUtils.visible(localHead, head, {localChar}) then
                            continue
                        end
                    end
                    
                    closestDistSqr = distSqr
                    closest = {
                        player = player,
                        character = character,
                        head = head,
                        humanoid = humanoid
                    }
                end
            end
        end
        
        return closest
    end
    
    function LegitAimbotModule:ShouldAim()
        if not self.Enabled then return false end
        if self.Settings.UseKeybind then
            return userInput:IsKeyDown(self.Settings.AimKey)
        end
        return true
    end
    
    function LegitAimbotModule:ApplyArmChams()
        local right, left = self:GetArms()
        if not right or not left then return end
        
        for _, arm in pairs({right, left}) do
            if not self.ArmChams.OriginalTransparency[arm] then
                self.ArmChams.OriginalTransparency[arm] = arm.Transparency
                self.ArmChams.OriginalMaterial[arm] = arm.Material
            end
            
            arm.Transparency = self.ArmChams.TransparencyValue
            arm.Material = Enum.Material.ForceField
        end
    end
    
    function LegitAimbotModule:RestoreArms()
        for arm, transparency in pairs(self.ArmChams.OriginalTransparency) do
            if arm and arm.Parent then
                arm.Transparency = transparency
                arm.Material = self.ArmChams.OriginalMaterial[arm]
            end
        end
    end
    
    function LegitAimbotModule:ApplyItemsChams()
        local function applyTool(tool)
            for _, part in ipairs(tool:GetDescendants()) do
                if part:IsA("BasePart") then
                    if not self.ItemsChams.OriginalData[part] then
                        self.ItemsChams.OriginalData[part] = {
                            Transparency = part.Transparency,
                            Material = part.Material
                        }
                    end
                    part.Transparency = self.ItemsChams.TransparencyValue
                    part.Material = Enum.Material.ForceField
                end
            end
        end
        
        if localPlayer:FindFirstChild("Backpack") then
            for _, tool in ipairs(localPlayer.Backpack:GetChildren()) do
                if tool:IsA("Tool") then applyTool(tool) end
            end
        end
        
        if localPlayer.Character then
            for _, tool in ipairs(localPlayer.Character:GetChildren()) do
                if tool:IsA("Tool") then applyTool(tool) end
            end
        end
    end
    
    function LegitAimbotModule:RestoreItemsChams()
        for part, data in pairs(self.ItemsChams.OriginalData) do
            if part and part.Parent then
                part.Transparency = data.Transparency
                part.Material = data.Material
            end
        end
        self.ItemsChams.OriginalData = {}
    end
    
    function LegitAimbotModule:Initialize()
        self:UpdateCache()
        
        self.Connection = runService.RenderStepped:Connect(function()
            if self.Enabled and self:ShouldAim() then
                local target = self:GetClosestPlayer()
                if target then
                    local smoothFactor = (100 - self.Settings.Smoothness) * 0.001
                    local targetCFrame = CFrame.new(camera.CFrame.Position, target.head.Position)
                    camera.CFrame = camera.CFrame:Lerp(targetCFrame, smoothFactor)
                end
            end
            
            if self.ArmChams.Enabled then
                self:ApplyArmChams()
            else
                self:RestoreArms()
            end
            
            if self.ItemsChams.Enabled then
                self:ApplyItemsChams()
            else
                self:RestoreItemsChams()
            end
        end)
        
        localPlayer.CharacterAdded:Connect(function()
            task.wait(1)
            self.CacheValid = false
        end)
        
        Workspace.DescendantAdded:Connect(function(descendant)
            if self.ItemsChams.Enabled and descendant:IsA("Tool") then
                task.wait()
                self:ApplyItemsChams()
            end
        end)
    end
end

LegitAimbotModule:Initialize()

-- UI Library
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/helloxyzcodervisuals/warepastecc/refs/heads/main/warepastecc.lua"))()
local UI = Library:CreateWindow("Warepaste", UDim2.new(0, 650, 0, 750))

-- Legitbot Tab
local Tab1 = UI:CreateTab("Legitbot")
local Sec1 = Tab1:CreateSection("Aimbot", "Left")
local Sec2 = Tab1:CreateSection("Visual", "Right")

Sec1:CreateToggle("Enable Legit Aimbot", false, function(v)
    LegitAimbotModule.Enabled = v
end)

Sec1:CreateToggle("Visible Check", true, function(v)
    LegitAimbotModule.Settings.VisibleCheck = v
end)

Sec1:CreateToggle("Forcefield Check", true, function(v)
    LegitAimbotModule.Settings.ForcefieldCheck = v
end)

Sec1:CreateToggle("Downed Check", true, function(v)
    LegitAimbotModule.Settings.DownedCheck = v
end)

Sec1:CreateToggle("Died Check", true, function(v)
    LegitAimbotModule.Settings.DiedCheck = v
end)

Sec1:CreateToggle("Team Check", true, function(v)
    LegitAimbotModule.Settings.TeamCheck = v
end)

Sec1:CreateToggle("Use Keybind", true, function(v)
    LegitAimbotModule.Settings.UseKeybind = v
end)

Sec1:CreateSlider("FOV Size", 0, 360, 120, "°", function(v)
    LegitAimbotModule.Settings.FOV = v
    LegitAimbotModule.Settings.FOVSqr = v * v
end)

Sec1:CreateSlider("Smoothness", 0, 100, 40, "%", function(v)
    LegitAimbotModule.Settings.Smoothness = v
end)

Sec1:CreateKeybind("Aimbot Key", Enum.KeyCode.LeftAlt, function(key)
    LegitAimbotModule.Settings.AimKey = key
end)

Sec1:CreateButton("Test Aimbot", function()
    print("Legit Aimbot Test")
end)

Sec2:CreateToggle("Arm Chams", false, function(v)
    LegitAimbotModule.ArmChams.Enabled = v
end)

Sec2:CreateSlider("Arm Transparency", 0, 1, 0.5, "", function(v)
    LegitAimbotModule.ArmChams.TransparencyValue = v
end)

Sec2:CreateToggle("Items Chams", false, function(v)
    LegitAimbotModule.ItemsChams.Enabled = v
end)

Sec2:CreateSlider("Items Transparency", 0, 1, 0.5, "", function(v)
    LegitAimbotModule.ItemsChams.TransparencyValue = v
end)

Sec2:CreateButton("Reset All Chams", function()
    LegitAimbotModule.ArmChams.Enabled = false
    LegitAimbotModule.ItemsChams.Enabled = false
    LegitAimbotModule:RestoreArms()
    LegitAimbotModule:RestoreItemsChams()
end)

-- ESP Module (Optimized)
local VisualModule = {
    ESP = {
        Enabled = false,
        Box = true,
        Name = true,
        Distance = true,
        Health = true,
        Tool = true,
        TeamColor = false,
        MaxDistance = 500,
        MaxDistanceSqr = 250000,
        BoxColor = Color3.new(1, 1, 1),
        NameColor = Color3.new(1, 1, 1),
        DistanceColor = Color3.new(1, 1, 1),
        HealthColor = Color3.fromRGB(0, 255, 0),
        EnemyColor = Color3.fromRGB(255, 50, 50),
        FriendColor = Color3.fromRGB(0, 150, 255),
        TextSize = 14
    },
    PlayerChams = {
        Enabled = false,
        BoxChams = true,
        Color = Color3.fromRGB(170, 0, 255),
        BorderColor = Color3.new(1, 1, 1),
        Transparency = 0,
        BorderTransparency = 0.5,
        LightEnabled = true,
        GlowEnabled = true,
        WallCheck = true,
        WallColor = Color3.new(1, 1, 1),
        WallTransparency = 0.3
    }
}

do
    local espDrawings = {}
    local chamParts = {}
    local connections = {}
    local font = CustomFont
    
    local function createESP(player)
        if player == LocalPlayer then return end
        if espDrawings[player] then return end
        
        local box = Drawing.new("Square")
        box.Visible = false
        box.Thickness = 1
        box.Filled = false
        box.Color = VisualModule.ESP.BoxColor
        box.Transparency = 1
        
        local sg = Instance.new("ScreenGui")
        sg.Name = player.Name .. "_ESP"
        sg.IgnoreGuiInset = true
        sg.Parent = CoreGui
        
        local nameLabel = Instance.new("TextLabel")
        nameLabel.BackgroundTransparency = 1
        nameLabel.TextColor3 = VisualModule.ESP.NameColor
        nameLabel.FontFace = font
        nameLabel.TextSize = VisualModule.ESP.TextSize
        nameLabel.TextStrokeTransparency = 0
        nameLabel.Parent = sg
        
        local distLabel = Instance.new("TextLabel")
        distLabel.BackgroundTransparency = 1
        distLabel.TextColor3 = VisualModule.ESP.DistanceColor
        distLabel.FontFace = font
        distLabel.TextSize = VisualModule.ESP.TextSize
        distLabel.TextStrokeTransparency = 0
        distLabel.Parent = sg
        
        local healthOutline = Instance.new("Frame")
        healthOutline.BackgroundColor3 = Color3.new(0, 0, 0)
        healthOutline.BorderSizePixel = 1
        healthOutline.Visible = false
        healthOutline.Parent = sg
        
        local healthFill = Instance.new("Frame")
        healthFill.BorderSizePixel = 0
        healthFill.Size = UDim2.new(1, 0, 1, 0)
        healthFill.Parent = healthOutline
        
        local gradient = Instance.new("UIGradient")
        gradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.new(1, 0, 0)),
            ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 0)),
            ColorSequenceKeypoint.new(1, VisualModule.ESP.HealthColor)
        })
        gradient.Rotation = -90
        gradient.Parent = healthFill
        
        local connection = RunService.RenderStepped:Connect(function()
            if not VisualModule.ESP.Enabled then
                box.Visible = false
                nameLabel.Visible = false
                distLabel.Visible = false
                healthOutline.Visible = false
                return
            end
            
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            
            if hrp and hum and hum.Health > 0 then
                local dist = (Camera.CFrame.Position - hrp.Position).Magnitude
                if dist > VisualModule.ESP.MaxDistance then
                    box.Visible = false
                    nameLabel.Visible = false
                    distLabel.Visible = false
                    healthOutline.Visible = false
                    return
                end
                
                local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                if onScreen then
                    local sizeX = 2000 / dist
                    local sizeY = 3500 / dist
                    local topY = pos.Y - sizeY * 0.5
                    local bottomY = pos.Y + sizeY * 0.5
                    
                    box.Visible = VisualModule.ESP.Box
                    box.Position = Vector2.new(pos.X - sizeX * 0.5, topY)
                    box.Size = Vector2.new(sizeX, sizeY)
                    
                    if VisualModule.ESP.TeamColor then
                        local color = player.Team == LocalPlayer.Team and VisualModule.ESP.FriendColor or VisualModule.ESP.EnemyColor
                        box.Color = color
                        nameLabel.TextColor3 = color
                        distLabel.TextColor3 = color
                    else
                        box.Color = VisualModule.ESP.BoxColor
                        nameLabel.TextColor3 = VisualModule.ESP.NameColor
                        distLabel.TextColor3 = VisualModule.ESP.DistanceColor
                    end
                    
                    nameLabel.Visible = VisualModule.ESP.Name
                    nameLabel.Text = player.Name
                    if VisualModule.ESP.Tool then
                        local tool = char:FindFirstChildOfClass("Tool")
                        if tool then
                            nameLabel.Text = nameLabel.Text .. " [" .. tool.Name .. "]"
                        end
                    end
                    nameLabel.Position = UDim2.new(0, pos.X, 0, topY - 20)
                    
                    distLabel.Visible = VisualModule.ESP.Distance
                    distLabel.Text = math.floor(dist) .. "ft"
                    distLabel.Position = UDim2.new(0, pos.X, 0, bottomY + 8)
                    
                    healthOutline.Visible = VisualModule.ESP.Health
                    healthOutline.Position = UDim2.new(0, (pos.X - sizeX * 0.5) - 6, 0, topY)
                    healthOutline.Size = UDim2.new(0, 3, 0, sizeY)
                    
                    local hpPercent = hum.Health / hum.MaxHealth
                    if hpPercent < 0 then hpPercent = 0 end
                    healthFill.Size = UDim2.new(1, 0, hpPercent, 0)
                    healthFill.Position = UDim2.new(0, 0, 1 - hpPercent, 0)
                    return
                end
            end
            
            box.Visible = false
            nameLabel.Visible = false
            distLabel.Visible = false
            healthOutline.Visible = false
        end)
        
        espDrawings[player] = {
            box = box,
            gui = sg,
            nameLabel = nameLabel,
            distLabel = distLabel,
            healthOutline = healthOutline,
            connection = connection
        }
        
        player.AncestryChanged:Connect(function()
            if not player:IsDescendantOf(Players) then
                if espDrawings[player] then
                    espDrawings[player].box:Remove()
                    espDrawings[player].gui:Destroy()
                    espDrawings[player].connection:Disconnect()
                    espDrawings[player] = nil
                end
            end
        end)
    end
    
    local function onPlayerAdded(player)
        if player ~= LocalPlayer then
            task.spawn(function()
                if player.Character then
                    task.wait(0.5)
                    createESP(player)
                end
            end)
            
            player.CharacterAdded:Connect(function()
                task.wait(0.5)
                createESP(player)
            end)
        end
    end
    
    for _, player in ipairs(Players:GetPlayers()) do
        onPlayerAdded(player)
    end
    
    table.insert(connections, Players.PlayerAdded:Connect(onPlayerAdded))
    table.insert(connections, Players.PlayerRemoving:Connect(function(player)
        if espDrawings[player] then
            espDrawings[player].box:Remove()
            espDrawings[player].gui:Destroy()
            espDrawings[player].connection:Disconnect()
            espDrawings[player] = nil
        end
    end))
end

-- Visuals Tab
local Tab2 = UI:CreateTab("Visuals")
local Sec3 = Tab2:CreateSection("ESP", "Left")

Sec3:CreateToggle("Enable ESP", false, function(v)
    VisualModule.ESP.Enabled = v
end)

Sec3:CreateToggle("Box ESP", true, function(v)
    VisualModule.ESP.Box = v
end)

Sec3:CreateToggle("Name ESP", true, function(v)
    VisualModule.ESP.Name = v
end)

Sec3:CreateToggle("Distance ESP", true, function(v)
    VisualModule.ESP.Distance = v
end)

Sec3:CreateToggle("Health ESP", true, function(v)
    VisualModule.ESP.Health = v
end)

Sec3:CreateToggle("Tool ESP", true, function(v)
    VisualModule.ESP.Tool = v
end)

Sec3:CreateToggle("Team Colors", false, function(v)
    VisualModule.ESP.TeamColor = v
end)

Sec3:CreateSlider("Max Distance", 0, 1000, 500, "ft", function(v)
    VisualModule.ESP.MaxDistance = v
    VisualModule.ESP.MaxDistanceSqr = v * v
end)

Sec3:CreateSlider("Text Size", 10, 20, 14, "", function(v)
    VisualModule.ESP.TextSize = v
end)

Sec3:CreateColorpicker("Box Color", Color3.new(1, 1, 1), function(c)
    VisualModule.ESP.BoxColor = c
end)

Sec3:CreateColorpicker("Name Color", Color3.new(1, 1, 1), function(c)
    VisualModule.ESP.NameColor = c
end)

Sec3:CreateColorpicker("Distance Color", Color3.new(1, 1, 1), function(c)
    VisualModule.ESP.DistanceColor = c
end)

Sec3:CreateColorpicker("Health Color", Color3.fromRGB(0, 255, 0), function(c)
    VisualModule.ESP.HealthColor = c
end)

Sec3:CreateColorpicker("Enemy Color", Color3.fromRGB(255, 50, 50), function(c)
    VisualModule.ESP.EnemyColor = c
end)

Sec3:CreateColorpicker("Friend Color", Color3.fromRGB(0, 150, 255), function(c)
    VisualModule.ESP.FriendColor = c
end)

-- Bullet Tracers Module (Optimized)
local BulletTracersModule = {
    Enabled = false,
    Settings = {
        Lifetime = 1,
        Width = 0.1,
        Color = Color3.fromRGB(255, 255, 255),
        Enabled = false
    },
    Running = false
}

do
    local camera = Camera
    local runService = RunService
    local tweenService = TweenService
    local workspace = Workspace
    
    local function createTracer(startPos, endPos)
        if not BulletTracersModule.Enabled or not BulletTracersModule.Settings.Enabled then return end
        
        local model = Instance.new("Model")
        model.Name = "Tracer"
        
        local beam = Instance.new("Beam")
        beam.Color = ColorSequence.new(BulletTracersModule.Settings.Color)
        beam.Width0 = BulletTracersModule.Settings.Width
        beam.Width1 = BulletTracersModule.Settings.Width
        beam.Texture = "rbxassetid://7136858729"
        beam.TextureSpeed = 1
        beam.Brightness = 2
        beam.LightEmission = 1
        beam.FaceCamera = true
        
        local a0 = Instance.new("Attachment")
        local a1 = Instance.new("Attachment")
        a0.WorldPosition = startPos
        a1.WorldPosition = endPos
        
        beam.Attachment0 = a0
        beam.Attachment1 = a1
        beam.Parent = model
        a0.Parent = model
        a1.Parent = model
        model.Parent = workspace
        
        local tween = tweenService:Create(beam, 
            TweenInfo.new(BulletTracersModule.Settings.Lifetime, Enum.EasingStyle.Linear),
            {Brightness = 0, Width0 = 0, Width1 = 0}
        )
        tween:Play()
        tween.Completed:Connect(function()
            if model then model:Destroy() end
        end)
    end
    
    local function trackGlobalBullets()
        if BulletTracersModule.Running then return end
        BulletTracersModule.Running = true
        
        local bfr = camera:FindFirstChild("Bullets")
        if not bfr then
            bfr = Instance.new("Folder")
            bfr.Name = "Bullets"
            bfr.Parent = camera
        end
        
        local function trackBullet(blt)
            if not blt:IsA("BasePart") then return end
            
            local startPos = blt.Position
            local lastPos = startPos
            local stuckCounter = 0
            local connection = nil
            
            connection = runService.Heartbeat:Connect(function()
                if not blt or not blt.Parent then
                    connection:Disconnect()
                    if (lastPos - startPos).Magnitude > 1 then
                        createTracer(startPos, lastPos)
                    end
                    return
                end
                
                local currentPos = blt.Position
                if (currentPos - lastPos).Magnitude < 0.1 then
                    stuckCounter = stuckCounter + 1
                    if stuckCounter > 3 then
                        connection:Disconnect()
                        if (currentPos - startPos).Magnitude > 1 then
                            createTracer(startPos, currentPos)
                        end
                    end
                else
                    stuckCounter = 0
                    lastPos = currentPos
                end
            end)
        end
        
        bfr.ChildAdded:Connect(trackBullet)
        for _, v in ipairs(bfr:GetChildren()) do
            task.spawn(trackBullet, v)
        end
    end
    
    trackGlobalBullets()
end

Sec3:CreateToggle("Enable Tracers", false, function(v)
    BulletTracersModule.Enabled = v
end)

Sec3:CreateToggle("Show Tracers", false, function(v)
    BulletTracersModule.Settings.Enabled = v
end)

Sec3:CreateSlider("Tracer Lifetime", 0.1, 5, 1, "s", function(v)
    BulletTracersModule.Settings.Lifetime = v
end)

Sec3:CreateSlider("Tracer Width", 0.01, 1, 0.1, "", function(v)
    BulletTracersModule.Settings.Width = v
end)

Sec3:CreateColorpicker("Tracer Color", Color3.fromRGB(255, 255, 255), function(c)
    BulletTracersModule.Settings.Color = c
end)

-- Character Render Module (Optimized)
local CharacterRenderModule = {
    Enabled = false,
    Color = Color3.fromRGB(170, 0, 255),
    Transparency = 0.3,
    OriginalData = {},
    Connection = nil
}

do
    local runService = RunService
    local localPlayer = LocalPlayer
    
    local function updateCharacterRender()
        if CharacterRenderModule.Enabled then
            local character = localPlayer.Character
            if character then
                local parts = {"Torso", "Right Leg", "Right Arm", "Left Leg", "Left Arm", "Head"}
                
                for i = 1, #parts do
                    local part = character:FindFirstChild(parts[i])
                    if part and part:IsA("BasePart") then
                        if not CharacterRenderModule.OriginalData[part] then
                            CharacterRenderModule.OriginalData[part] = {
                                Color = part.Color,
                                Transparency = part.Transparency,
                                Material = part.Material
                            }
                        end
                        
                        part.Color = CharacterRenderModule.Color
                        part.Transparency = CharacterRenderModule.Transparency
                        part.Material = Enum.Material.ForceField
                    end
                end
            end
        else
            for part, data in pairs(CharacterRenderModule.OriginalData) do
                if part and part.Parent then
                    part.Color = data.Color
                    part.Transparency = data.Transparency
                    part.Material = data.Material
                end
            end
            CharacterRenderModule.OriginalData = {}
        end
    end
    
    local function setupCharacterRender()
        if CharacterRenderModule.Connection then
            CharacterRenderModule.Connection:Disconnect()
            CharacterRenderModule.Connection = nil
        end
        
        if CharacterRenderModule.Enabled then
            CharacterRenderModule.Connection = runService.RenderStepped:Connect(updateCharacterRender)
        else
            updateCharacterRender()
        end
    end
    
    localPlayer.CharacterAdded:Connect(function()
        if CharacterRenderModule.Connection then
            CharacterRenderModule.Connection:Disconnect()
            CharacterRenderModule.Connection = nil
        end
        CharacterRenderModule.OriginalData = {}
        if CharacterRenderModule.Enabled then
            task.wait(0.5)
            CharacterRenderModule.Connection = runService.RenderStepped:Connect(updateCharacterRender)
        end
    end)
    
    if CharacterRenderModule.Enabled then
        setupCharacterRender()
    end
    
    local Sec4 = Tab2:CreateSection("Character Rendering", "Right")
    
    Sec4:CreateToggle("Enable", false, function(v)
        CharacterRenderModule.Enabled = v
        setupCharacterRender()
    end)
    
    Sec4:CreateColorpicker("Render Color", Color3.fromRGB(170, 0, 255), function(c)
        CharacterRenderModule.Color = c
        if CharacterRenderModule.Enabled then
            local character = localPlayer.Character
            if character then
                for _, part in ipairs(character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.Color = c
                    end
                end
            end
        end
    end)
    
    Sec4:CreateSlider("Transparency", 0, 1, 0.3, "", function(v)
        CharacterRenderModule.Transparency = v
        if CharacterRenderModule.Enabled then
            local character = localPlayer.Character
            if character then
                for _, part in ipairs(character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.Transparency = v
                    end
                end
            end
        end
    end)
end

-- Ragebot Configuration (Optimized)
local ConfigTable = {
    Ragebot = {
        Enabled = false,
        RapidFire = false,
        FireRate = 30,
        Prediction = true,
        PredictionAmount = 0.12,
        TeamCheck = false,
        VisibilityCheck = true,
        Wallbang = true,
        Tracers = true,
        TracerColor = Color3.fromRGB(255, 0, 0),
        TracerWidth = 1,
        TracerLifetime = 3,
        ShootRange = 15,
        HitRange = 15,
        HitNotify = true,
        AutoReload = true,
        HitSound = true,
        HitColor = Color3.fromRGB(255, 182, 193),
        UseTargetList = true,
        UseWhitelist = true,
        HitNotifyDuration = 5,
        LowHealthCheck = false,
        SelectedHitSound = "Skeet",
        FriendCheck = false,
        MaxTarget = 0,
        TracerTexture = "rbxassetid://7136858729"
    }
}

-- Ragebot Core (Optimized)
do
    local rs = ReplicatedStorage
    local ev = rs:WaitForChild("Events")
    local s_ev = ev:WaitForChild("GNX_S")
    local h_ev = ev:WaitForChild("ZFKLF__H")
    
    local currentTool = nil
    local toolValues = nil
    local ammoValue = nil
    local storedAmmoValue = nil
    local fireRate = 2.5
    local lastShotTime = 0
    local cachedPositions = {shootPos = nil, hitPos = nil, target = nil}
    local instantReloadConnections = {}
    local characterAddedConnection = nil
    
    local tracerTextures = {
        ["Default"] = "rbxassetid://7136858729",
        ["Alternative"] = "rbxassetid://6060542021",
        ["Laser"] = "rbxassetid://446111271",
        ["Rainbow"] = "rbxassetid://875688442"
    }
    
    local soundIds = {
        ["Skeet"] = "rbxassetid://5633695679",
        ["Neverlose"] = "rbxassetid://6534948092",
        ["Fatality"] = "rbxassetid://6534947869",
        ["Bameware"] = "rbxassetid://3124331820",
        ["Bell"] = "rbxassetid://6534947240",
        ["Bubble"] = "rbxassetid://6534947588",
        ["Pop"] = "rbxassetid://198598793",
        ["Rust"] = "rbxassetid://1255040462",
        ["Sans"] = "rbxassetid://3188795283",
        ["Minecraft"] = "rbxassetid://4018616850",
        ["xp"] = "rbxassetid://17148249625"
    }
    
    local function getCurrentTool()
        if LocalPlayer.Character then
            for _, tool in pairs(LocalPlayer.Character:GetChildren()) do
                if tool:IsA("Tool") then
                    return tool
                end
            end
        end
        return nil
    end
    
    local function updateToolInfo(tool)
        if not (tool and tool:IsA("Tool")) then return end
        currentTool = tool
        toolValues = tool:FindFirstChild("Values")
        ammoValue = toolValues and toolValues:FindFirstChild("SERVER_Ammo")
        storedAmmoValue = toolValues and toolValues:FindFirstChild("SERVER_StoredAmmo")
        
        for _, v in pairs(getgc(true)) do
            if type(v) == "table" and rawget(v, "FireRate") and rawget(v, "Damage") then
                fireRate = v.FireRate
                break
            end
        end
    end
    
    local function setupCharacter(char)
        if not char then return end
        char.ChildAdded:Connect(updateToolInfo)
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then updateToolInfo(tool) end
    end
    
    setupCharacter(LocalPlayer.Character)
    LocalPlayer.CharacterAdded:Connect(setupCharacter)
    
    local function generateRandomKey()
        local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
        local result = ""
        for i = 1, 30 do
            result = result .. chars:sub(math.random(1, #chars), math.random(1, #chars))
        end
        return result .. "0"
    end
    
    local function canSeeTarget(targetPart)
        if not ConfigTable.Ragebot.VisibilityCheck then return true end
        
        local localHead = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head")
        if not localHead then return false end
        
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Blacklist
        params.FilterDescendantsInstances = {LocalPlayer.Character}
        
        local direction = targetPart.Position - localHead.Position
        local result = Workspace:Raycast(localHead.Position, direction, params)
        
        if result then
            local hitPart = result.Instance
            if hitPart and hitPart.CanCollide then
                local model = hitPart:FindFirstAncestorOfClass("Model")
                if model then
                    local humanoid = model:FindFirstChildOfClass("Humanoid")
                    if humanoid then
                        return Players:GetPlayerFromCharacter(model) ~= nil
                    end
                end
                return false
            end
        end
        return true
    end
    
    local function checkClearPath(startPos, endPos)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Blacklist
        params.FilterDescendantsInstances = {LocalPlayer.Character}
        
        local direction = endPos - startPos
        local result = Workspace:Raycast(startPos, direction, params)
        
        if result then
            local hitPart = result.Instance
            if hitPart and hitPart.CanCollide then
                local model = hitPart:FindFirstAncestorOfClass("Model")
                if model then
                    return model:FindFirstChildOfClass("Humanoid") == nil
                end
                return false
            end
        end
        return true
    end
    
    local function getClosestTarget()
        local localHead = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head")
        if not localHead then return nil end
        
        local closest = nil
        local shortestDistance = math.huge
        local localTeam = LocalPlayer.Team
        local localChar = LocalPlayer.Character
        
        for _, player in ipairs(Players:GetPlayers()) do
            if player == LocalPlayer then continue end
            
            if ConfigTable.Ragebot.UseWhitelist and TableUtils.contains(Whitelist, player.Name) then
                continue
            end
            
            if ConfigTable.Ragebot.UseTargetList and not TableUtils.contains(TargetList, player.Name) then
                continue
            end
            
            if ConfigTable.Ragebot.TeamCheck and player.Team == localTeam then
                continue
            end
            
            if ConfigTable.Ragebot.FriendCheck and LocalPlayer:IsFriendsWith(player.UserId) then
                continue
            end
            
            local char = player.Character
            if not char then continue end
            
            local hum = char:FindFirstChildOfClass("Humanoid")
            local head = char:FindFirstChild("Head")
            
            if not hum or not head or hum.Health <= 0 then continue end
            if char:FindFirstChildOfClass("ForceField") then continue end
            if ConfigTable.Ragebot.LowHealthCheck and hum.Health < 15 then continue end
            
            local distance = (head.Position - localHead.Position).Magnitude
            if distance < shortestDistance then
                if ConfigTable.Ragebot.VisibilityCheck and not canSeeTarget(head) then
                    continue
                end
                closest = head
                shortestDistance = distance
            end
        end
        return closest
    end
    
    local function findWallbangPosition(startPos, targetPos)
        if not ConfigTable.Ragebot.Wallbang then
            return startPos, targetPos
        end
        
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Blacklist
        params.FilterDescendantsInstances = {LocalPlayer.Character}
        
        local shootRange = ConfigTable.Ragebot.ShootRange
        local hitRange = ConfigTable.Ragebot.HitRange
        
        for i = 1, 120 do
            local shootPos = startPos + Vector3.new(
                math.random(-shootRange, shootRange),
                math.random(-shootRange, shootRange),
                math.random(-shootRange, shootRange)
            )
            
            local hitPos = targetPos + Vector3.new(
                math.random(-hitRange, hitRange),
                math.random(-hitRange, hitRange),
                math.random(-hitRange, hitRange)
            )
            
            if checkClearPath(startPos, shootPos) and checkClearPath(shootPos, hitPos) then
                local finalRay = Workspace:Raycast(shootPos, (hitPos - shootPos).Unit * (hitPos - shootPos).Magnitude, params)
                if not finalRay then
                    return shootPos, hitPos
                end
            end
        end
        
        local fallbackY = math.random(-16, -14)
        local shootPos = Vector3.new(
            startPos.X + math.random(-3, 3),
            fallbackY,
            startPos.Z + math.random(-3, 3)
        )
        local hitPos = Vector3.new(
            targetPos.X + math.random(-3, 3),
            fallbackY,
            targetPos.Z + math.random(-3, 3)
        )
        
        return shootPos, hitPos
    end
    
    local function createTracer(startPos, endPos)
        if not ConfigTable.Ragebot.Tracers then return end
        
        local model = Instance.new("Model")
        model.Name = "TracerBeam"
        
        local beam = Instance.new("Beam")
        beam.Color = ColorSequence.new(ConfigTable.Ragebot.TracerColor)
        beam.Width0 = ConfigTable.Ragebot.TracerWidth
        beam.Width1 = ConfigTable.Ragebot.TracerWidth
        beam.Texture = tracerTextures[ConfigTable.Ragebot.TracerTexture] or "rbxassetid://7136858729"
        beam.TextureSpeed = 1
        beam.Brightness = 2
        beam.LightEmission = 2
        beam.FaceCamera = true
        
        local a0 = Instance.new("Attachment")
        local a1 = Instance.new("Attachment")
        a0.WorldPosition = startPos
        a1.WorldPosition = endPos
        
        beam.Attachment0 = a0
        beam.Attachment1 = a1
        beam.Parent = model
        a0.Parent = model
        a1.Parent = model
        model.Parent = Workspace
        
        local tween = TweenService:Create(beam,
            TweenInfo.new(ConfigTable.Ragebot.TracerLifetime, Enum.EasingStyle.Linear),
            {Brightness = 0}
        )
        tween:Play()
        tween.Completed:Connect(function()
            if model then model:Destroy() end
        end)
    end
    
    local hitNotifications = {}
    
    local function createHitNotification(playerName, offsetValue, usedCache)
        if not ConfigTable.Ragebot.HitNotify then return end
        
        local targetPlayer = Players:FindFirstChild(playerName)
        local health = targetPlayer and targetPlayer.Character and 
                      targetPlayer.Character:FindFirstChildOfClass("Humanoid") and 
                      math.floor(targetPlayer.Character.Humanoid.Health) or 0
        
        local screenGui = CoreGui:FindFirstChild("HitNotifications")
        if not screenGui then
            screenGui = Instance.new("ScreenGui")
            screenGui.Name = "HitNotifications"
            screenGui.Parent = CoreGui
        end
        
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 200, 0, 25)
        frame.Position = UDim2.new(0, 10, 0, 10 + (#hitNotifications * 29))
        frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        frame.BackgroundTransparency = 0.3
        frame.BorderSizePixel = 0
        frame.Parent = screenGui
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = string.format("Hit %s (%d HP) %.2f%s",
            playerName,
            health,
            offsetValue,
            usedCache and " [CACHE]" or ""
        )
        label.TextColor3 = ConfigTable.Ragebot.HitColor
        label.Font = Enum.Font.Gotham
        label.TextSize = 14
        label.Parent = frame
        
        table.insert(hitNotifications, frame)
        
        task.delay(ConfigTable.Ragebot.HitNotifyDuration, function()
            for i, notif in ipairs(hitNotifications) do
                if notif == frame then
                    table.remove(hitNotifications, i)
                    frame:Destroy()
                    break
                end
            end
            
            for i, notif in ipairs(hitNotifications) do
                notif.Position = UDim2.new(0, 10, 0, 10 + (i - 1) * 29)
            end
        end)
    end
    
    local function playHitSound()
        if not ConfigTable.Ragebot.HitSound then return end
        
        local soundId = soundIds[ConfigTable.Ragebot.SelectedHitSound] or soundIds["Skeet"]
        
        local sound = Instance.new("Sound")
        sound.SoundId = soundId
        sound.Volume = 0.75
        sound.Parent = Workspace
        sound:Play()
        Debris:AddItem(sound, 0.75)
    end
    
    local function autoReload()
        if not ConfigTable.Ragebot.AutoReload then
            for _, conn in pairs(instantReloadConnections) do
                if conn then conn:Disconnect() end
            end
            instantReloadConnections = {}
            if characterAddedConnection then
                characterAddedConnection:Disconnect()
                characterAddedConnection = nil
            end
            return
        end
        
        for _, conn in pairs(instantReloadConnections) do
            if conn then conn:Disconnect() end
        end
        instantReloadConnections = {}
        
        local gunRemote = ev:WaitForChild("GNX_R")
        
        local function setupToolListeners(toolObj)
            if not toolObj or not toolObj:FindFirstChild("IsGun") then return end
            
            local values = toolObj:FindFirstChild("Values")
            if not values then return end
            
            local ammo = values:FindFirstChild("SERVER_Ammo")
            local stored = values:FindFirstChild("SERVER_StoredAmmo")
            if not ammo or not stored then return end
            
            if stored.Value ~= 0 then
                gunRemote:FireServer(tick(), "KLWE89U0", toolObj)
            end
            
            local conn1 = stored:GetPropertyChangedSignal("Value"):Connect(function()
                if ConfigTable.Ragebot.AutoReload then
                    gunRemote:FireServer(tick(), "KLWE89U0", toolObj)
                end
            end)
            
            local conn2 = ammo:GetPropertyChangedSignal("Value"):Connect(function()
                if ConfigTable.Ragebot.AutoReload and stored.Value ~= 0 then
                    gunRemote:FireServer(tick(), "KLWE89U0", toolObj)
                end
            end)
            
            table.insert(instantReloadConnections, conn1)
            table.insert(instantReloadConnections, conn2)
        end
        
        local char = LocalPlayer.Character
        if char then
            local tool = char:FindFirstChildOfClass("Tool")
            if tool then setupToolListeners(tool) end
            
            local conn3 = char.ChildAdded:Connect(function(obj)
                if obj:IsA("Tool") then setupToolListeners(obj) end
            end)
            table.insert(instantReloadConnections, conn3)
        end
        
        if characterAddedConnection then
            characterAddedConnection:Disconnect()
        end
        
        characterAddedConnection = LocalPlayer.CharacterAdded:Connect(function(char)
            repeat task.wait() until char and char.Parent
            local conn4 = char.ChildAdded:Connect(function(obj)
                if obj:IsA("Tool") then setupToolListeners(obj) end
            end)
            table.insert(instantReloadConnections, conn4)
        end)
    end
    
    local SP = {["TEC-9"] = true, ["Beretta"] = true}
    
    local function shoot(target, useCache)
        local char = LocalPlayer.Character
        if not (target and char and currentTool and ammoValue) then return false end
        
        if ammoValue.Value <= 0 then
            autoReload()
            return false
        end
        
        local localHead = char:FindFirstChild("Head")
        if not localHead then return false end
        
        local shootPos, hitPos = findWallbangPosition(localHead.Position, target.Position)
        
        if ConfigTable.Ragebot.Prediction and target.Velocity then
            hitPos = hitPos + target.Velocity * ConfigTable.Ragebot.PredictionAmount
        end
        
        local direction = (hitPos - shootPos).Unit
        local key = generateRandomKey()
        
        s_ev:FireServer(tick(), key, currentTool, "FDS9I83", shootPos, {direction}, false)
        h_ev:FireServer("🧈", currentTool, key, 1, target, hitPos, direction)
        
        local targetPlayer = Players:GetPlayerFromCharacter(target.Parent)
        if targetPlayer then
            createHitNotification(targetPlayer.Name, (shootPos - localHead.Position).Magnitude, useCache)
            if ConfigTable.Ragebot.HitSound then
                playHitSound()
            end
        end
        
        local hitmarker = currentTool:FindFirstChild("Hitmarker")
        if hitmarker then
            hitmarker:Fire(currentTool)
        end
        
        if ConfigTable.Ragebot.Tracers then
            createTracer(shootPos, hitPos)
        end
        
        return true
    end
    
    RunService.Heartbeat:Connect(function()
        if not (ConfigTable.Ragebot.Enabled and LocalPlayer.Character and currentTool) then
            return
        end
        
        local target = getClosestTarget()
        if not target then return end
        
        local isRapidFire = ConfigTable.Ragebot.RapidFire and SP[currentTool.Name]
        
        if isRapidFire then
            shoot(target, true)
        else
            local now = tick()
            local rate = 1 / fireRate
            if now - lastShotTime >= rate then
                if shoot(target, false) then
                    lastShotTime = now
                end
            end
        end
    end)
end

-- Ragebot Tab
local Tab3 = UI:CreateTab("Ragebot")
local MainSection = Tab3:CreateSection("Main", "Left")

MainSection:CreateToggle("Enabled", false, function(v)
    ConfigTable.Ragebot.Enabled = v
end)

MainSection:CreateToggle("Rapid Fire", false, function(v)
    ConfigTable.Ragebot.RapidFire = v
end)

MainSection:CreateToggle("Auto Reload", true, function(v)
    ConfigTable.Ragebot.AutoReload = v
    autoReload()
end)

MainSection:CreateSlider("Fire Rate", 1, 1000, 30, "", function(v)
    ConfigTable.Ragebot.FireRate = v
end)

MainSection:CreateKeybind("Activation Key", Enum.KeyCode.LeftAlt, function(key) end)

local AimSection = Tab3:CreateSection("Aim Settings", "Right")

AimSection:CreateToggle("Prediction", true, function(v)
    ConfigTable.Ragebot.Prediction = v
end)

AimSection:CreateSlider("Prediction Amount", 0.05, 0.3, 0.12, "", function(v)
    ConfigTable.Ragebot.PredictionAmount = v
end)

AimSection:CreateToggle("Wallbang", true, function(v)
    ConfigTable.Ragebot.Wallbang = v
end)

AimSection:CreateSlider("Shoot Range", 1, 30, 15, "", function(v)
    ConfigTable.Ragebot.ShootRange = v
end)

AimSection:CreateSlider("Hit Range", 1, 30, 15, "", function(v)
    ConfigTable.Ragebot.HitRange = v
end)

AimSection:CreateSlider("Max Targets", 0, 10, 0, "", function(v)
    ConfigTable.Ragebot.MaxTarget = v
end)

local TargetSection = Tab3:CreateSection("Targeting", "Left")

TargetSection:CreateToggle("Team Check", false, function(v)
    ConfigTable.Ragebot.TeamCheck = v
end)

TargetSection:CreateToggle("Visibility Check", true, function(v)
    ConfigTable.Ragebot.VisibilityCheck = v
end)

TargetSection:CreateToggle("Friend Check", false, function(v)
    ConfigTable.Ragebot.FriendCheck = v
end)

TargetSection:CreateToggle("Low Health Check", false, function(v)
    ConfigTable.Ragebot.LowHealthCheck = v
end)

TargetSection:CreateToggle("Use Target List", true, function(v)
    ConfigTable.Ragebot.UseTargetList = v
end)

TargetSection:CreateToggle("Use Whitelist", true, function(v)
    ConfigTable.Ragebot.UseWhitelist = v
end)

local ManagementSection = Tab3:CreateSection("Management", "Left")

local currentSelectedPlayer = nil
local onlineOptions = {}

for _, player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        table.insert(onlineOptions, player.Name)
    end
end

local onlineListBox = ManagementSection:CreateListbox("Online Players", onlineOptions, false, function(selected)
    if typeof(selected) == "table" then
        currentSelectedPlayer = selected[1]
    else
        currentSelectedPlayer = selected
    end
end)

ManagementSection:CreateButton("Add to Target List", function()
    local name = tostring(currentSelectedPlayer)
    if name and name ~= "nil" then
        TableUtils.remove(Whitelist, name)
        if not TableUtils.contains(TargetList, name) then
            table.insert(TargetList, name)
        end
    end
end)

ManagementSection:CreateButton("Add to Whitelist", function()
    local name = tostring(currentSelectedPlayer)
    if name and name ~= "nil" then
        TableUtils.remove(TargetList, name)
        if not TableUtils.contains(Whitelist, name) then
            table.insert(Whitelist, name)
        end
    end
end)

ManagementSection:CreateButton("Clear Selected Player", function()
    local name = tostring(currentSelectedPlayer)
    if name and name ~= "nil" then
        TableUtils.remove(TargetList, name)
        TableUtils.remove(Whitelist, name)
    end
end)

ManagementSection:CreateButton("Clear All Lists", function()
    TargetList = {}
    Whitelist = {}
end)

Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then
        onlineListBox:Add(player.Name)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if player ~= LocalPlayer then
        onlineListBox:Remove(player.Name)
        TableUtils.remove(TargetList, player.Name)
        TableUtils.remove(Whitelist, player.Name)
    end
end)

local VisualSection = Tab3:CreateSection("Visuals", "Right")

VisualSection:CreateToggle("Tracers", true, function(v)
    ConfigTable.Ragebot.Tracers = v
end)

VisualSection:CreateColorpicker("Tracer Color", Color3.fromRGB(255, 0, 0), function(c)
    ConfigTable.Ragebot.TracerColor = c
end)

VisualSection:CreateSlider("Tracer Width", 0.1, 5, 1, "", function(v)
    ConfigTable.Ragebot.TracerWidth = v
end)

VisualSection:CreateSlider("Tracer Lifetime", 0.5, 10, 3, "s", function(v)
    ConfigTable.Ragebot.TracerLifetime = v
end)

local tracerTextureList = {"Default", "Alternative", "Laser", "Rainbow"}
VisualSection:CreateListbox("Tracer Texture", tracerTextureList, false, function(v)
    ConfigTable.Ragebot.TracerTexture = v
end)

VisualSection:CreateToggle("Hit Notify", true, function(v)
    ConfigTable.Ragebot.HitNotify = v
end)

VisualSection:CreateColorpicker("Hit Color", Color3.fromRGB(255, 182, 193), function(c)
    ConfigTable.Ragebot.HitColor = c
end)

VisualSection:CreateSlider("Notify Duration", 1, 10, 5, "s", function(v)
    ConfigTable.Ragebot.HitNotifyDuration = v
end)

VisualSection:CreateToggle("Hit Sound", true, function(v)
    ConfigTable.Ragebot.HitSound = v
end)

local SoundList = {"Skeet", "Neverlose", "Fatality", "Bameware", "Bell", "Bubble", "Pop", "Rust", "Sans", "Minecraft", "xp"}
VisualSection:CreateListbox("Hit Sound", SoundList, false, function(v)
    ConfigTable.Ragebot.SelectedHitSound = v
end)

-- Misc Tab Modules (Optimized)
local MiscModules = {
    ForceTime = {
        Enabled = false,
        Value = 12,
        Connection = nil,
        Enable = function(self)
            if self.Connection then self.Connection:Disconnect() end
            self.Connection = RunService.RenderStepped:Connect(function()
                if not self.Enabled then return end
                Lighting.ClockTime = self.Value
                Lighting.TimeOfDay = string.format("%02d:00:00", self.Value)
            end)
        end,
        Disable = function(self)
            if self.Connection then
                self.Connection:Disconnect()
                self.Connection = nil
            end
        end
    },
    
    Speed = {
        Enabled = false,
        Value = 50,
        Connection = nil,
        Enable = function(self)
            if self.Connection then self.Connection:Disconnect() end
            self.Connection = RunService.RenderStepped:Connect(function()
                if not self.Enabled then return end
                local char = LocalPlayer.Character
                if not char then return end
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then hum.WalkSpeed = self.Value end
            end)
        end,
        Disable = function(self)
            if self.Connection then
                self.Connection:Disconnect()
                self.Connection = nil
            end
            local char = LocalPlayer.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then hum.WalkSpeed = 16 end
            end
        end
    },
    
    Fly = {
        Enabled = false,
        Speed = 50,
        Connection = nil,
        Motors = {},
        RagdollEvent = nil,
        
        Initialize = function(self)
            self.RagdollEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("__RZDONL")
        end,
        
        Enable = function(self)
            local char = LocalPlayer.Character
            if not char then return end
            
            local hum = char:FindFirstChildOfClass("Humanoid")
            local root = char:FindFirstChild("HumanoidRootPart")
            if not hum or not root then return end
            
            for _, child in ipairs(char:GetDescendants()) do
                if child:IsA("Motor6D") then
                    child.Enabled = false
                end
            end
            
            hum.PlatformStand = true
            hum:ChangeState(Enum.HumanoidStateType.Freefall)
            
            for _, motor in ipairs(self.Motors) do
                motor:Destroy()
            end
            self.Motors = {}
            
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part ~= root then
                    local motor = Instance.new("Motor6D")
                    motor.Name = "FlyMotor"
                    motor.Part0 = root
                    motor.Part1 = part
                    motor.C1 = CFrame.new()
                    motor.C0 = root.CFrame:ToObjectSpace(part.CFrame)
                    motor.Parent = part
                    table.insert(self.Motors, motor)
                end
            end
            
            if self.Connection then self.Connection:Disconnect() end
            self.Connection = RunService.Heartbeat:Connect(function()
                if not self.Enabled then
                    self:Disable()
                    return
                end
                
                local cam = Workspace.CurrentCamera
                if not cam then return end
                
                local lookVector = cam.CFrame.LookVector
                local moveDirection = hum.MoveDirection
                
                if moveDirection.Magnitude > 0 then
                    root.CFrame = CFrame.new(root.Position, root.Position + lookVector)
                    root.Velocity = lookVector * self.Speed
                    if self.RagdollEvent then
                        self.RagdollEvent:FireServer("__---r", Vector3.zero, 
                            CFrame.new(-4574, 3, -443, 0, 0, 1, 0, 1, 0, -1, 0, 0), true)
                    end
                else
                    root.Velocity = Vector3.new(0, 0, 0)
                end
            end)
        end,
        
        Disable = function(self)
            self.Enabled = false
            if self.Connection then
                self.Connection:Disconnect()
                self.Connection = nil
            end
            
            local char = LocalPlayer.Character
            if not char then return end
            
            local hum = char:FindFirstChildOfClass("Humanoid")
            local root = char:FindFirstChild("HumanoidRootPart")
            
            if hum then
                hum.PlatformStand = false
                hum:ChangeState(Enum.HumanoidStateType.Running)
            end
            
            if root then
                root.Velocity = Vector3.new(0, 0, 0)
            end
            
            for _, motor in ipairs(self.Motors) do
                motor:Destroy()
            end
            self.Motors = {}
            
            for _, child in ipairs(char:GetDescendants()) do
                if child:IsA("Motor6D") and child.Name ~= "FlyMotor" then
                    child.Enabled = true
                end
            end
        end
    },
    
    JumpPower = {
        Enabled = false,
        Value = 100,
        Connection = nil,
        Enable = function(self)
            if self.Connection then self.Connection:Disconnect() end
            self.Connection = RunService.Heartbeat:Connect(function()
                if not self.Enabled then return end
                local char = LocalPlayer.Character
                if not char then return end
                local hum = char:FindFirstChildOfClass("Humanoid")
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hum and hrp and hum:GetState() == Enum.HumanoidStateType.Jumping then
                    hrp.Velocity = Vector3.new(hrp.Velocity.X, self.Value, hrp.Velocity.Z)
                end
            end)
        end,
        Disable = function(self)
            if self.Connection then
                self.Connection:Disconnect()
                self.Connection = nil
            end
        end
    },
    
    LoopFOV = {
        Enabled = false,
        Connection = nil,
        Enable = function(self)
            if self.Connection then self.Connection:Disconnect() end
            self.Connection = RunService.RenderStepped:Connect(function()
                if not self.Enabled then return end
                Workspace.CurrentCamera.FieldOfView = 120
            end)
        end,
        Disable = function(self)
            if self.Connection then
                self.Connection:Disconnect()
                self.Connection = nil
            end
        end
    },
    
    InfStamina = {
        Enabled = false,
        Hook = nil,
        Enable = function(self)
            if self.Hook then return end
            
            local module = nil
            for _, v in pairs(ReplicatedStorage:GetDescendants()) do
                if v:IsA("ModuleScript") and v.Name == "XIIX" then
                    module = v
                    break
                end
            end
            
            if module then
                module = require(module)
                local ac = module["XIIX"]
                local glob = getfenv(ac)["_G"]
                local stamina = getupvalues((getupvalues(glob["S_Check"]))[2])[1]
                
                if stamina ~= nil then
                    self.Hook = hookfunction(stamina, function()
                        return 100, 100
                    end)
                end
            end
        end,
        Disable = function(self)
            if self.Hook then
                hookfunction(self.Hook, self.Hook)
                self.Hook = nil
            end
        end
    },
    
    NoFallDamage = {
        Enabled = false,
        Hook = nil,
        Enable = function(self)
            if self.Hook then return end
            
            self.Hook = hookmetamethod(game, "__namecall", function(self, ...)
                local method = getnamecallmethod()
                local args = {...}
                
                if method == "FireServer" and not checkcaller() and args[1] == "FlllD" and args[4] == false then
                    args[2] = 0
                    args[3] = 0
                    return self.Hook(self, unpack(args))
                end
                return self.Hook(self, ...)
            end)
        end,
        Disable = function(self)
            if self.Hook then
                hookmetamethod(game, "__namecall", self.Hook)
                self.Hook = nil
            end
        end
    },
    
    Lockpick = {
        Enabled = false,
        Connection = nil,
        Enable = function(self)
            self.Enabled = true
            
            local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
            if not playerGui then return end
            
            local function modifyLockpick(gui)
                for _, a in ipairs(gui:GetDescendants()) do
                    if a:IsA("ImageLabel") and a.Name == "Bar" and a.Parent.Name ~= "Attempts" then
                        local oldSize = a.Size
                        local connection = RunService.RenderStepped:Connect(function()
                            if self.Enabled and a and a.Parent then
                                a.Size = UDim2.new(0, 280, 0, 280)
                            elseif not self.Enabled and a and a.Parent then
                                a.Size = oldSize
                                connection:Disconnect()
                            end
                        end)
                    end
                end
            end
            
            if self.Connection then self.Connection:Disconnect() end
            self.Connection = playerGui.ChildAdded:Connect(function(child)
                if child:IsA("ScreenGui") and child.Name == "LockpickGUI" then
                    modifyLockpick(child)
                end
            end)
            
            for _, child in ipairs(playerGui:GetChildren()) do
                if child:IsA("ScreenGui") and child.Name == "LockpickGUI" then
                    modifyLockpick(child)
                end
            end
        end,
        Disable = function(self)
            self.Enabled = false
            if self.Connection then
                self.Connection:Disconnect()
                self.Connection = nil
            end
        end
    },
    
    InstantPrompt = {
        Enabled = false,
        Connection = nil,
        Enable = function(self)
            self.Enabled = true
            
            for _, obj in ipairs(game:GetDescendants()) do
                if obj:IsA("ProximityPrompt") then
                    obj.HoldDuration = 0
                end
            end
            
            if self.Connection then self.Connection:Disconnect() end
            self.Connection = game.DescendantAdded:Connect(function(obj)
                if obj:IsA("ProximityPrompt") then
                    task.wait()
                    obj.HoldDuration = 0
                end
            end)
        end,
        Disable = function(self)
            self.Enabled = false
            if self.Connection then
                self.Connection:Disconnect()
                self.Connection = nil
            end
            
            for _, obj in ipairs(game:GetDescendants()) do
                if obj:IsA("ProximityPrompt") then
                    obj.HoldDuration = 1
                end
            end
        end
    },
    
    AutoDoor = {
        Enabled = false,
        Connection = nil,
        Enable = function(self)
            self.Enabled = true
            if self.Connection then self.Connection:Disconnect() end
            
            self.Connection = RunService.Heartbeat:Connect(function()
                if not self.Enabled then return end
                
                local char = LocalPlayer.Character
                if not char then return end
                
                local root = char:FindFirstChild("HumanoidRootPart")
                if not root then return end
                
                local map = Workspace:FindFirstChild("Map")
                if not map then return end
                
                local doors = map:FindFirstChild("Doors")
                if not doors then return end
                
                local closestDoor = nil
                local closestDist = 15
                
                for _, door in ipairs(doors:GetChildren()) do
                    local knob = door:FindFirstChild("Knob1") or door:FindFirstChild("Knob2")
                    if knob then
                        local dist = (knob.Position - root.Position).Magnitude
                        if dist < closestDist then
                            closestDist = dist
                            closestDoor = door
                        end
                    end
                end
                
                if closestDoor then
                    local knob = closestDoor:FindFirstChild("Knob1") or closestDoor:FindFirstChild("Knob2")
                    local events = closestDoor:FindFirstChild("Events")
                    local toggleEvent = events and events:FindFirstChild("Toggle")
                    
                    if knob and toggleEvent then
                        toggleEvent:FireServer("Open", knob)
                    end
                end
            end)
        end,
        Disable = function(self)
            self.Enabled = false
            if self.Connection then
                self.Connection:Disconnect()
                self.Connection = nil
            end
        end
    },
    
    HideHead = {
        Enabled = false,
        RenderConnection = nil,
        OriginalHook = nil,
        
        Enable = function(self)
            if not self.OriginalHook then
                self.OriginalHook = hookmetamethod(game, "__namecall", function(self, ...)
                    local method = getnamecallmethod()
                    if method == "FireServer" and self.Name == "MOVZREP" and MiscModules.HideHead.Enabled then
                        local args = {{
                            {
                                Vector3.new(-5721.2001953125, -5, 971.5162353515625),
                                Vector3.new(-4181.38818359375, -6, 11.123311996459961),
                                Vector3.new(0.006237113382667303, -6, -0.18136750161647797),
                                true, true, true, false
                            },
                            false, false, 15.8
                        }}
                        return self.OriginalHook(self, unpack(args))
                    end
                    return self.OriginalHook(self, ...)
                end)
            end
            
            self:LockNeck()
        end,
        
        Disable = function(self)
            if self.RenderConnection then
                self.RenderConnection:Disconnect()
                self.RenderConnection = nil
            end
        end,
        
        LockNeck = function(self)
            local char = LocalPlayer.Character
            if not char then return end
            
            local torso = char:FindFirstChild("Torso")
            if not torso then return end
            
            local neck = torso:FindFirstChild("Neck")
            if not neck or not neck:IsA("Motor6D") then return end
            
            if self.RenderConnection then
                self.RenderConnection:Disconnect()
            end
            
            self.RenderConnection = RunService.RenderStepped:Connect(function()
                if not MiscModules.HideHead.Enabled then
                    if self.RenderConnection then
                        self.RenderConnection:Disconnect()
                        self.RenderConnection = nil
                    end
                    return
                end
                
                neck.C0 = CFrame.new(0, 0, 0.75) * CFrame.Angles(math.rad(90), 0, 0)
                neck.C1 = CFrame.new(0, 0.25, 0) * CFrame.Angles(0, 0, 0)
            end)
        end
    },
    
    HandsUp = {
        Enabled = false,
        Connection = nil,
        OriginalHook = nil,
        CurrentTool = nil,
        CreatedMotors = {},
        OrigRightC0 = nil,
        OrigLeftC0 = nil,
        MoveForward = 1.25,
        RaiseAngle = math.rad(90),
        
        GetShoulders = function(self, character)
            local root = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
            if not root then return nil, nil end
            local rs = root:FindFirstChild("Right Shoulder") or character:FindFirstChild("RightUpperArm", true):FindFirstChild("RightShoulder")
            local ls = root:FindFirstChild("Left Shoulder") or character:FindFirstChild("LeftUpperArm", true):FindFirstChild("LeftShoulder")
            return rs, ls
        end,
        
        Cleanup = function(self)
            for _, m in ipairs(self.CreatedMotors) do
                if m then m:Destroy() end
            end
            self.CreatedMotors = {}
            
            local char = LocalPlayer.Character
            if char then
                local rs, ls = self:GetShoulders(char)
                if rs and self.OrigRightC0 then rs.C0 = self.OrigRightC0 end
                if ls and self.OrigLeftC0 then ls.C0 = self.OrigLeftC0 end
            end
            
            self.CurrentTool = nil
        end,
        
        UpdateHook = function(self)
            if self.OriginalHook then
                hookmetamethod(game, "__namecall", self.OriginalHook)
                self.OriginalHook = nil
            end
            
            if self.Enabled and self.CurrentTool then
                self.OriginalHook = hookmetamethod(game, "__namecall", function(self, ...)
                    local method = getnamecallmethod()
                    if method == "FireServer" and self.Name == "MOVZREP" then
                        local yValue = MiscModules.HideHead.Enabled and -6 or 0.9833956360816956
                        local args = {{
                            {
                                Vector3.new(-5721.2001953125, 9834.1708984375, 971.5162353515625),
                                Vector3.new(-4181.38818359375, 0.3198874592781067, 11.123311996459961),
                                Vector3.new(0.006237113382667303, yValue, -0.18136750161647797),
                                true, true, true, false
                            },
                            false, false, 15.8
                        }}
                        return self.OriginalHook(self, unpack(args))
                    end
                    return self.OriginalHook(self, ...)
                end)
            end
        end,
        
        OnStepped = function(self)
            local char = LocalPlayer.Character
            if not char or not self.Enabled then return end
            
            local rs, ls = self:GetShoulders(char)
            if not rs or not ls then return end
            if not self.OrigRightC0 then self.OrigRightC0 = rs.C0 end
            if not self.OrigLeftC0 then self.OrigLeftC0 = ls.C0 end
            
            local tool = char:FindFirstChildOfClass("Tool")
            if tool then
                rs.C0 = self.OrigRightC0 * CFrame.Angles(0, 0, self.RaiseAngle)
                ls.C0 = self.OrigLeftC0 * CFrame.Angles(0, 0, -self.RaiseAngle)
                
                if self.CurrentTool ~= tool then
                    for _, m in ipairs(self.CreatedMotors) do
                        if m then m:Destroy() end
                    end
                    self.CreatedMotors = {}
                    
                    local t6d = tool:FindFirstChild("Tool6D_Torso", true)
                    local m6d = tool:FindFirstChild("Mag6D_Torso", true)
                    local wHandle = tool:FindFirstChild("WeaponHandle", true)
                    local mHandle = tool:FindFirstChild("MagazineHandle", true)
                    
                    if t6d and wHandle then
                        local nm = Instance.new("Motor6D")
                        nm.Part0 = t6d.Part0
                        nm.Part1 = wHandle
                        nm.C0 = t6d.C0 * CFrame.new(0, 0, -self.MoveForward) * CFrame.Angles(self.RaiseAngle, 0, 0)
                        nm.Parent = wHandle
                        table.insert(self.CreatedMotors, nm)
                    end
                    
                    if m6d and mHandle then
                        local nm = Instance.new("Motor6D")
                        nm.Part0 = m6d.Part0
                        nm.Part1 = mHandle
                        nm.C0 = m6d.C0 * CFrame.new(0, 0, -self.MoveForward) * CFrame.Angles(self.RaiseAngle, 0, 0)
                        nm.Parent = mHandle
                        table.insert(self.CreatedMotors, nm)
                    end
                    
                    self.CurrentTool = tool
                    self:UpdateHook()
                end
            else
                if self.CurrentTool then
                    self:Cleanup()
                    self:UpdateHook()
                end
            end
        end,
        
        Enable = function(self)
            self.Enabled = true
            if not self.Connection then
                self.Connection = RunService.RenderStepped:Connect(function()
                    self:OnStepped()
                end)
            end
            self:UpdateHook()
        end,
        
        Disable = function(self)
            self.Enabled = false
            if self.Connection then
                self.Connection:Disconnect()
                self.Connection = nil
            end
            self:Cleanup()
            self:UpdateHook()
        end
    }
}

MiscModules.Fly:Initialize()

-- Quick UI
do
    local quickUIFrame = Instance.new("Frame")
    quickUIFrame.Name = "QuickUIFrame"
    quickUIFrame.Size = UDim2.new(0, 80, 0, 30)
    quickUIFrame.Position = UDim2.new(0, 10, 0, 50)
    quickUIFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    quickUIFrame.BackgroundTransparency = 0.5
    quickUIFrame.BorderSizePixel = 0
    
    local quickUIText = Instance.new("TextButton")
    quickUIText.Name = "QuickUIText"
    quickUIText.Size = UDim2.new(1, 0, 1, 0)
    quickUIText.BackgroundTransparency = 1
    quickUIText.Text = "FLY OFF"
    quickUIText.TextColor3 = Color3.fromRGB(255, 50, 50)
    quickUIText.Font = Enum.Font.GothamBold
    quickUIText.TextSize = 12
    quickUIText.Parent = quickUIFrame
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "QuickUIScreen"
    screenGui.Parent = CoreGui
    quickUIFrame.Parent = screenGui
    
    quickUIText.MouseButton1Click:Connect(function()
        MiscModules.Fly.Enabled = not MiscModules.Fly.Enabled
        if MiscModules.Fly.Enabled then
            quickUIText.Text = "FLY ON"
            quickUIText.TextColor3 = Color3.fromRGB(50, 255, 50)
            MiscModules.Fly:Enable()
        else
            quickUIText.Text = "FLY OFF"
            quickUIText.TextColor3 = Color3.fromRGB(255, 50, 50)
            MiscModules.Fly:Disable()
        end
    end)
end

-- Misc Tab
local Tab4 = UI:CreateTab("Misc")
local MovementSection = Tab4:CreateSection("Movement", "Left")

MovementSection:CreateToggle("Speed", false, function(v)
    MiscModules.Speed.Enabled = v
    if v then MiscModules.Speed:Enable() else MiscModules.Speed:Disable() end
end)

MovementSection:CreateSlider("Speed Value", 16, 200, 50, "", function(v)
    MiscModules.Speed.Value = v
end)

MovementSection:CreateKeybind("Speed Key", Enum.KeyCode.X, function() end)

MovementSection:CreateToggle("Fly", false, function(v)
    MiscModules.Fly.Enabled = v
    if v then MiscModules.Fly:Enable() else MiscModules.Fly:Disable() end
end)

MovementSection:CreateSlider("Fly Speed", 10, 200, 50, "", function(v)
    MiscModules.Fly.Speed = v
end)

MovementSection:CreateKeybind("Fly Key", Enum.KeyCode.F, function() end)

MovementSection:CreateToggle("Jump Power", false, function(v)
    MiscModules.JumpPower.Enabled = v
    if v then MiscModules.JumpPower:Enable() else MiscModules.JumpPower:Disable() end
end)

MovementSection:CreateSlider("Jump Value", 50, 300, 100, "", function(v)
    MiscModules.JumpPower.Value = v
end)

local WorldSection = Tab4:CreateSection("World", "Right")

WorldSection:CreateToggle("Force Time", false, function(v)
    MiscModules.ForceTime.Enabled = v
    if v then MiscModules.ForceTime:Enable() else MiscModules.ForceTime:Disable() end
end)

WorldSection:CreateSlider("Time", 0, 24, 12, "hr", function(v)
    MiscModules.ForceTime.Value = v
    if MiscModules.ForceTime.Enabled then
        Lighting.ClockTime = v
        Lighting.TimeOfDay = string.format("%02d:00:00", v)
    end
end)

local ToolsSection = Tab4:CreateSection("Tools", "Left")

ToolsSection:CreateToggle("Loop FOV", false, function(v)
    MiscModules.LoopFOV.Enabled = v
    if v then MiscModules.LoopFOV:Enable() else MiscModules.LoopFOV:Disable() end
end)

ToolsSection:CreateToggle("Inf Stamina", false, function(v)
    MiscModules.InfStamina.Enabled = v
    if v then MiscModules.InfStamina:Enable() else MiscModules.InfStamina:Disable() end
end)

ToolsSection:CreateToggle("No Fall Damage", false, function(v)
    MiscModules.NoFallDamage.Enabled = v
    if v then MiscModules.NoFallDamage:Enable() else MiscModules.NoFallDamage:Disable() end
end)

ToolsSection:CreateToggle("No Fail Lockpick", false, function(v)
    MiscModules.Lockpick.Enabled = v
    if v then MiscModules.Lockpick:Enable() else MiscModules.Lockpick:Disable() end
end)

ToolsSection:CreateToggle("Instant Prompt", false, function(v)
    MiscModules.InstantPrompt.Enabled = v
    if v then MiscModules.InstantPrompt:Enable() else MiscModules.InstantPrompt:Disable() end
end)

ToolsSection:CreateToggle("Auto Door", false, function(v)
    MiscModules.AutoDoor.Enabled = v
    if v then MiscModules.AutoDoor:Enable() else MiscModules.AutoDoor:Disable() end
end)

ToolsSection:CreateToggle("Hide Head", false, function(v)
    MiscModules.HideHead.Enabled = v
    if v then MiscModules.HideHead:Enable() else MiscModules.HideHead:Disable() end
end)

ToolsSection:CreateToggle("Hands Up", false, function(v)
    if v then
        MiscModules.HandsUp:Enable()
    else
        MiscModules.HandsUp:Disable()
    end
end)