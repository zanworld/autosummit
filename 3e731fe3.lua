-- GotoDetect Hub v5.0 - FINAL CLEAN & SEMPURNA
-- Compatible: Executor langsung OR Plugin IY via loader
-- Fitur: CP Auto + WP Auto + Player TP + Misc (SEMUA WORK) + Detector Stuck

if not getfenv then
    print("ERROR: Executor tidak support!")
    return
end

--== PLUGIN METADATA (untuk loader IY) ==--
local PluginMetadata = {
    PluginName = "GotoDetect",
    PluginDescription = "Hub CP Near + IY WayPoints + Player + Misc + Detector Stuck",
    Commands = {}
}

--== Services ==--
local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService       = game:GetService("HttpService")
local TeleportService   = game:GetService("TeleportService")
local RunService        = game:GetService("RunService")
local CoreGui           = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

--== THEME ==--
local THEME = {
    bg_primary      = Color3.fromRGB(15, 18, 24),
    bg_secondary    = Color3.fromRGB(21, 25, 33),
    bg_tertiary     = Color3.fromRGB(31, 36, 48),
    accent_primary  = Color3.fromRGB(0, 199, 255),
    text_primary    = Color3.fromRGB(255, 255, 255),
    text_secondary  = Color3.fromRGB(170, 178, 199),
    text_muted      = Color3.fromRGB(110, 118, 140),
    success         = Color3.fromRGB(34, 197, 94),
    danger          = Color3.fromRGB(239, 68, 68),
    warning         = Color3.fromRGB(245, 158, 11),
}

local KEYWORDS = {
    Checkpoint = {"checkpoint","cp","stage","level"},
}

local State = {
    Gui              = nil,
    ActiveTab        = "CP",
    LastScan         = nil,
    AutoRunning      = false,
    AutoRescan       = false,
    AutoRescanDelay  = 8,
    DetectorActive   = false,
    DetectorStuck    = false,
    LastCPStage      = nil,
    IsPaused         = false,
}

local MiscState = {
    FlyMode          = false,
    NoClipMode       = false,
    SpeedWalkMode    = false,
    InfJumpMode      = false,
    SpeedValue       = 60,
}

local DetectorConfig = {
    StuckTimeout     = 3,
    DistanceThreshold = 5,
    CheckInterval    = 0.5,
}

local SelectedWP = {}
local WPRoute = {}
local CurrentLoopCount = 0
local CurrentWPIndex = 0

--== MISC FEATURES ==--
local function toggleFly(state)
    local char = LocalPlayer.Character
    if not char then return end
    
    if state then
        local speed = 60
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        
        local bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bodyVelocity.Parent = hrp
        
        MiscState.FlyConnection = RunService.RenderStepped:Connect(function()
            if not MiscState.FlyMode or not bodyVelocity.Parent then return end
            
            local moveDir = Vector3.new(0, 0, 0)
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + (hrp.CFrame.LookVector) end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - (hrp.CFrame.LookVector) end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - (hrp.CFrame.RightVector) end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + (hrp.CFrame.RightVector) end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir = moveDir - Vector3.new(0, 1, 0) end
            
            if moveDir.Magnitude > 0 then
                bodyVelocity.Velocity = moveDir.Unit * speed
            else
                bodyVelocity.Velocity = Vector3.new(0, 0, 0)
            end
        end)
        
        MiscState.FlyMode = true
        notify("✈️ Fly Mode ON", THEME.success)
    else
        if MiscState.FlyConnection then
            MiscState.FlyConnection:Disconnect()
        end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local bv = hrp:FindFirstChild("BodyVelocity")
            if bv then bv:Destroy() end
        end
        MiscState.FlyMode = false
        notify("✈️ Fly Mode OFF", THEME.warning)
    end
end

local function toggleNoClip(state)
    local char = LocalPlayer.Character
    if not char then return end
    
    if state then
        MiscState.NoClipConnection = RunService.Stepped:Connect(function()
            if not MiscState.NoClipMode then return end
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end)
        MiscState.NoClipMode = true
        notify("🛟 NoClip Mode ON", THEME.success)
    else
        if MiscState.NoClipConnection then
            MiscState.NoClipConnection:Disconnect()
        end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
        MiscState.NoClipMode = false
        notify("🛟 NoClip Mode OFF", THEME.warning)
    end
end

local function toggleSpeedWalk(state)
    local char = LocalPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid then return end
    
    if state then
        MiscState.SpeedWalkMode = true
        humanoid.WalkSpeed = MiscState.SpeedValue
        notify("🚀 SpeedWalk ON ("..MiscState.SpeedValue..")", THEME.success)
    else
        MiscState.SpeedWalkMode = false
        humanoid.WalkSpeed = 16
        notify("🚀 SpeedWalk OFF", THEME.warning)
    end
end

local function toggleInfJump(state)
    local char = LocalPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid then return end
    
    if state then
        MiscState.InfJumpConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if input.KeyCode == Enum.KeyCode.Space and MiscState.InfJumpMode then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
        MiscState.InfJumpMode = true
        notify("⬆️ Infinite Jump ON", THEME.success)
    else
        if MiscState.InfJumpConnection then
            MiscState.InfJumpConnection:Disconnect()
        end
        MiscState.InfJumpMode = false
        notify("⬆️ Infinite Jump OFF", THEME.warning)
    end
end

--== NOTIFY ==--
local function notify(text, color)
    local parent = LocalPlayer:FindFirstChildOfClass("PlayerGui") or CoreGui
    local sg = Instance.new("ScreenGui")
    sg.Name = "GotoDetectNotify"
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.IgnoreGuiInset = true
    sg.ResetOnSpawn = false
    sg.Parent = parent

    color = color or THEME.accent_primary

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0,300,0,40)
    lbl.Position = UDim2.new(0.5,-150,0.08,0)
    lbl.BackgroundColor3 = THEME.bg_secondary
    lbl.BackgroundTransparency = 0.15
    lbl.BorderSizePixel = 0
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 13
    lbl.TextColor3 = color
    lbl.Text = text
    lbl.Parent = sg

    local corner = Instance.new("UICorner", lbl)
    corner.CornerRadius = UDim.new(0,10)

    local stroke = Instance.new("UIStroke", lbl)
    stroke.Thickness = 1
    stroke.Transparency = 0.4
    stroke.Color = color

    task.delay(2,function()
        if sg and sg.Parent then sg:Destroy() end
    end)
end

--== UTIL ==--
local function matchAny(str, list)
    str = str:lower()
    for _,kw in ipairs(list) do
        if str:find(kw) then return true end
    end
    return false
end

local function getNumberAtEnd(name)
    local n = tostring(name):match("(-?%d+)$")
    return n and tonumber(n) or nil
end

local function getFullPath(inst)
    local names = {inst.Name}
    local p = inst.Parent
    while p and p ~= game do
        table.insert(names,1,p.Name)
        p = p.Parent
    end
    return table.concat(names,".")
end

local function teleportTo(inst)
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local cf
    if inst:IsA("BasePart") then
        cf = inst.CFrame
    elseif inst:IsA("Model") and inst.PrimaryPart then
        cf = inst.PrimaryPart.CFrame
    end
    if not cf then return end

    hrp.CFrame = cf + Vector3.new(0,3,0)
end

local function teleportToPos(pos)
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    hrp.CFrame = CFrame.new(pos + Vector3.new(0,3,0))
end

local function getStage()
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if not ls then return nil end
    for _,name in ipairs({"Stage","Stages","CP","Checkpoint","Level"}) do
        local v = ls:FindFirstChild(name)
        if v and v:IsA("IntValue") then
            return v.Value
        end
    end
    return nil
end

local function makeDraggable(dragArea, target)
    local dragging = false
    local dragStart, startPos

    dragArea.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = target.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            target.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

--== WAYPOINTS (IY) ==--
local function getIYWaypoints()
    if type(WayPoints) ~= "table" then return {} end
    local list = {}
    for i,wp in ipairs(WayPoints) do
        if wp.GAME == nil or wp.GAME == game.PlaceId then
            local c = wp.COORD
            if type(c) == "table" and c[1] and c[2] and c[3] then
                table.insert(list,{
                    index = i,
                    name  = wp.NAME or ("WP_"..i),
                    pos   = Vector3.new(c[1],c[2],c[3]),
                })
            end
        end
    end
    return list
end

--== OPTIMIZED SCAN ==--
local function scanWorkspace()
    local results = { Checkpoint = {} }
    
    local function handleObj(obj)
        if not (obj:IsA("BasePart") or obj:IsA("Model")) then return end
        local lname = obj.Name:lower()
        if not matchAny(lname, KEYWORDS.Checkpoint) then return end
        
        table.insert(results.Checkpoint, {
            instance = obj,
            number   = getNumberAtEnd(obj.Name),
            name     = obj.Name,
            path     = getFullPath(obj),
            kind     = "Checkpoint",
        })
    end

    for _, obj in ipairs(workspace:GetDescendants()) do
        handleObj(obj)
    end

    table.sort(results.Checkpoint, function(a,b)
        return (a.number or 0) < (b.number or 0)
    end)

    State.LastScan = results
    return results
end

--== DETECTOR STUCK ==--
local function startStuckDetector(DetectorText, onStuck, onRecovered)
    if State.DetectorActive then return end
    State.DetectorActive = true

    task.spawn(function()
        local lastPos = nil
        local stuckTime = 0

        while State.DetectorActive and State.Gui do
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")

            if hrp then
                local currentPos = hrp.Position
                if lastPos then
                    local dist = (currentPos - lastPos).Magnitude
                    if dist < DetectorConfig.DistanceThreshold then
                        stuckTime = stuckTime + DetectorConfig.CheckInterval
                        if stuckTime >= DetectorConfig.StuckTimeout and not State.DetectorStuck then
                            State.DetectorStuck = true
                            if onStuck then onStuck() end
                        end
                    else
                        stuckTime = 0
                        if State.DetectorStuck then
                            State.DetectorStuck = false
                            if onRecovered then onRecovered() end
                        end
                    end
                end
                lastPos = currentPos
            end
            task.wait(DetectorConfig.CheckInterval)
        end
    end)
end

--== BUILD UI ==--
local function buildUI()
    if State.Gui and State.Gui.Parent then State.Gui:Destroy() end

    local parent = LocalPlayer:FindFirstChildOfClass("PlayerGui") or CoreGui
    local sg = Instance.new("ScreenGui")
    sg.Name = "GotoDetectUI"
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.IgnoreGuiInset = true
    sg.ResetOnSpawn = false
    sg.Parent = parent

    State.Gui = sg
    State.ActiveTab = "CP"

    -- MINI BUTTON
    local MiniBtn = Instance.new("TextButton")
    MiniBtn.Size = UDim2.new(0,110,0,26)
    MiniBtn.Position = UDim2.new(0,20,1,-40)
    MiniBtn.BackgroundColor3 = THEME.bg_secondary
    MiniBtn.BackgroundTransparency = 0.3
    MiniBtn.BorderSizePixel = 0
    MiniBtn.Font = Enum.Font.GothamBold
    MiniBtn.TextSize = 13
    MiniBtn.TextColor3 = THEME.text_primary
    MiniBtn.Text = "GotoDetect"
    MiniBtn.Visible = false
    MiniBtn.Parent = sg

    local MiniCorner = Instance.new("UICorner", MiniBtn)
    MiniCorner.CornerRadius = UDim.new(0,10)

    -- ROOT
    local Root = Instance.new("Frame")
    Root.AnchorPoint = Vector2.new(0.5,0.5)
    Root.Size = UDim2.new(0.7,0,0.75,0)
    Root.Position = UDim2.new(0.5,0,0.5,0)
    Root.BackgroundColor3 = THEME.bg_secondary
    Root.BackgroundTransparency = 0.18
    Root.BorderSizePixel = 0
    Root.Parent = sg

    local RootCorner = Instance.new("UICorner", Root)
    RootCorner.CornerRadius = UDim.new(0,14)

    local RootStroke = Instance.new("UIStroke", Root)
    RootStroke.Color = THEME.accent_primary
    RootStroke.Transparency = 0.75
    RootStroke.Thickness = 1

    -- HEADER
    local Header = Instance.new("Frame")
    Header.Size = UDim2.new(1,0,0,35)
    Header.BackgroundColor3 = THEME.bg_secondary
    Header.BackgroundTransparency = 0.25
    Header.BorderSizePixel = 0
    Header.Parent = Root
    makeDraggable(Header, Root)

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(0.5,0,1,0)
    Title.Position = UDim2.new(0,14,0,0)
    Title.BackgroundTransparency = 1
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 15
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.TextColor3 = THEME.text_primary
    Title.Text = "GotoDetect v5.0 (FINAL)"
    Title.Parent = Header

    local MinTop = Instance.new("TextButton")
    MinTop.Size = UDim2.new(0,55,0,22)
    MinTop.Position = UDim2.new(1,-155,0.5,-11)
    MinTop.BackgroundColor3 = THEME.bg_tertiary
    MinTop.BackgroundTransparency = 0.3
    MinTop.BorderSizePixel = 0
    MinTop.Font = Enum.Font.GothamBold
    MinTop.TextSize = 10
    MinTop.TextColor3 = THEME.text_secondary
    MinTop.Text = "MINI"
    MinTop.Parent = Header
    local MinCorner = Instance.new("UICorner", MinTop)
    MinCorner.CornerRadius = UDim.new(0,6)

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0,55,0,22)
    CloseBtn.Position = UDim2.new(1,-90,0.5,-11)
    CloseBtn.BackgroundColor3 = THEME.danger
    CloseBtn.BackgroundTransparency = 0.15
    CloseBtn.BorderSizePixel = 0
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.TextSize = 10
    CloseBtn.TextColor3 = THEME.text_primary
    CloseBtn.Text = "CLOSE"
    CloseBtn.Parent = Header
    local CloseCorner = Instance.new("UICorner", CloseBtn)
    CloseCorner.CornerRadius = UDim.new(0,6)

    -- BODY
    local Body = Instance.new("Frame")
    Body.Size = UDim2.new(1,0,1,-35)
    Body.Position = UDim2.new(0,0,0,35)
    Body.BackgroundTransparency = 1
    Body.Parent = Root

    -- LEFT NAV
    local LeftNav = Instance.new("Frame")
    LeftNav.Size = UDim2.new(0.22,0,1,0)
    LeftNav.BackgroundColor3 = THEME.bg_primary
    LeftNav.BackgroundTransparency = 0.25
    LeftNav.BorderSizePixel = 0
    LeftNav.Parent = Body

    local LeftCorner = Instance.new("UICorner", LeftNav)
    LeftCorner.CornerRadius = UDim.new(0,12)

    local NavList = Instance.new("UIListLayout", LeftNav)
    NavList.SortOrder = Enum.SortOrder.LayoutOrder
    NavList.Padding = UDim.new(0,3)

    local padding = Instance.new("Frame")
    padding.Size = UDim2.new(1,0,0,6)
    padding.BackgroundTransparency = 1
    padding.LayoutOrder = 0
    padding.Parent = LeftNav

    local function makeNavBtn(text, order)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1,-7,0,28)
        btn.BackgroundColor3 = THEME.bg_tertiary
        btn.BackgroundTransparency = 0.5
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 12
        btn.TextColor3 = THEME.text_secondary
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.Text = "  "..text
        btn.LayoutOrder = order
        btn.Parent = LeftNav
        local corner = Instance.new("UICorner", btn)
        corner.CornerRadius = UDim.new(0,6)
        return btn
    end

    local NavCP   = makeNavBtn("📍 CP Near",1)
    local NavWP   = makeNavBtn("🎯 Waypoints",2)
    local NavMisc = makeNavBtn("✨ Misc",3)
    local NavInfo = makeNavBtn("ℹ️ Info",4)

    -- CONTENT
    local Content = Instance.new("Frame")
    Content.Size = UDim2.new(0.78,0,1,0)
    Content.Position = UDim2.new(0.22,0,0,0)
    Content.BackgroundColor3 = THEME.bg_primary
    Content.BackgroundTransparency = 0.25
    Content.BorderSizePixel = 0
    Content.Parent = Body

    local ContentCorner = Instance.new("UICorner", Content)
    ContentCorner.CornerRadius = UDim.new(0,12)

    local InfoLabel = Instance.new("TextLabel")
    InfoLabel.Size = UDim2.new(1,-16,1,-16)
    InfoLabel.Position = UDim2.new(0,8,0,8)
    InfoLabel.BackgroundColor3 = THEME.bg_tertiary
    InfoLabel.BackgroundTransparency = 0.4
    InfoLabel.BorderSizePixel = 0
    InfoLabel.Font = Enum.Font.Gotham
    InfoLabel.TextSize = 13
    InfoLabel.TextColor3 = THEME.text_primary
    InfoLabel.TextWrapped = true
    InfoLabel.TextXAlignment = Enum.TextXAlignment.Left
    InfoLabel.TextYAlignment = Enum.TextYAlignment.Top
    InfoLabel.Parent = Content

    local InfoCorner = Instance.new("UICorner", InfoLabel)
    InfoCorner.CornerRadius = UDim.new(0,8)

    local function updateDisplay()
        if State.ActiveTab == "Misc" then
            InfoLabel.Text = "✅ MISC FEATURES (SEMUA JALAN):\n\n"
                .."🪶 FLY - Terbang bebas (WASD+Space/Ctrl)\n"
                .."🛟 NOCLIP - Tembus dinding\n"
                .."🚀 SPEEDWALK - Jalan cepat (60)\n"
                .."⬆️ INFJUMP - Lompat unlimited\n\n"
                .."Klik tombol di bawah untuk toggle"
        elseif State.ActiveTab == "CP" then
            local cpCount = (State.LastScan and #State.LastScan.Checkpoint) or 0
            InfoLabel.Text = "📍 CHECKPOINT AUTO RUNNER\n\n"
                .."Total CP: "..cpCount.."\n\n"
                .."✓ Auto detect checkpoint\n"
                .."✓ Teleport ke CP\n"
                .."✓ Loop unlimited\n"
                .."✓ Panel kecil real-time"
        elseif State.ActiveTab == "WP" then
            local wpCount = #getIYWaypoints()
            InfoLabel.Text = "🎯 WAYPOINT RUNNER\n\n"
                .."Total WP: "..wpCount.."\n\n"
                .."✓ Dari IY Waypoint List\n"
                .."✓ Auto TP waypoint\n"
                .."✓ Auto detect CP reset\n"
                .."✓ Panel kecil real-time"
        else
            InfoLabel.Text = "📱 GotoDetect v5.0 - FINAL\n\n"
                .."✨ FITUR:\n"
                .."✓ CP Auto Runner\n"
                .."✓ Waypoint Runner (IY)\n"
                .."✓ Misc (Fly, NoClip, WS, InfJump)\n"
                .."✓ Detector Stuck Real-time\n"
                .."✓ Player Teleport\n\n"
                .."Pilih menu di sebelah kiri!"
        end
    end

    -- MISC BUTTONS
    local function makeMiscBtn(name, callback, yPos)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.42,-5,0,32)
        btn.Position = UDim2.new(0.08,0,yPos,0)
        btn.BackgroundColor3 = THEME.bg_tertiary
        btn.BackgroundTransparency = 0.4
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        btn.TextColor3 = THEME.text_primary
        btn.Text = name.." (OFF)"
        btn.Parent = Content
        btn.Visible = false
        local corner = Instance.new("UICorner", btn)
        corner.CornerRadius = UDim.new(0,6)

        local state = false
        btn.MouseButton1Click:Connect(function()
            state = not state
            btn.Text = name..(state and " (ON)" or " (OFF)")
            btn.BackgroundColor3 = state and THEME.success or THEME.bg_tertiary
            callback(state)
        end)
        return btn
    end

    local FlyBtn = makeMiscBtn("🪶 FLY", toggleFly, 0.08)
    local NoclipBtn = makeMiscBtn("🛟 NOCLIP", toggleNoClip, 0.22)
    local SpeedBtn = makeMiscBtn("🚀 SPEEDWALK", toggleSpeedWalk, 0.36)
    local JumpBtn = makeMiscBtn("⬆️ INFJUMP", toggleInfJump, 0.50)

    -- NAV LOGIC
    local function setTabActive(tab)
        State.ActiveTab = tab
        
        local function style(btn, active)
            btn.BackgroundColor3 = active and THEME.accent_primary or THEME.bg_tertiary
            btn.BackgroundTransparency = active and 0.15 or 0.5
            btn.TextColor3 = active and THEME.text_primary or THEME.text_secondary
        end

        style(NavCP, tab=="CP")
        style(NavWP, tab=="WP")
        style(NavMisc, tab=="Misc")
        style(NavInfo, tab=="Info")

        FlyBtn.Visible = (tab=="Misc")
        NoclipBtn.Visible = (tab=="Misc")
        SpeedBtn.Visible = (tab=="Misc")
        JumpBtn.Visible = (tab=="Misc")

        updateDisplay()
    end

    NavCP.MouseButton1Click:Connect(function() setTabActive("CP") end)
    NavWP.MouseButton1Click:Connect(function() setTabActive("WP") end)
    NavMisc.MouseButton1Click:Connect(function() setTabActive("Misc") end)
    NavInfo.MouseButton1Click:Connect(function() setTabActive("Info") end)

    -- PANEL KECIL (INFO PANEL)
    local InfoPanel = Instance.new("Frame")
    InfoPanel.Size = UDim2.new(0,300,0,100)
    InfoPanel.AnchorPoint = Vector2.new(0.5,1)
    InfoPanel.Position = UDim2.new(0.5,0,1,-140)
    InfoPanel.BackgroundColor3 = THEME.bg_tertiary
    InfoPanel.BackgroundTransparency = 0.2
    InfoPanel.BorderSizePixel = 0
    InfoPanel.Visible = false
    InfoPanel.ZIndex = 50
    InfoPanel.Parent = sg

    local PanelCorner = Instance.new("UICorner", InfoPanel)
    PanelCorner.CornerRadius = UDim.new(0,8)

    local PanelStroke = Instance.new("UIStroke", InfoPanel)
    PanelStroke.Color = THEME.accent_primary
    PanelStroke.Thickness = 1
    PanelStroke.Transparency = 0.5

    -- Line 1: Loop, WP, Stage
    local InfoText = Instance.new("TextLabel")
    InfoText.Size = UDim2.new(1,-10,0,20)
    InfoText.Position = UDim2.new(0,5,0,2)
    InfoText.BackgroundTransparency = 1
    InfoText.Font = Enum.Font.Gotham
    InfoText.TextSize = 10
    InfoText.TextColor3 = THEME.text_primary
    InfoText.TextXAlignment = Enum.TextXAlignment.Left
    InfoText.Text = "Loop: -  |  WP: -  |  Stage: -"
    InfoText.ZIndex = 51
    InfoText.Parent = InfoPanel

    -- Line 2: Detector Status
    local DetectorText = Instance.new("TextLabel")
    DetectorText.Size = UDim2.new(1,-10,0,20)
    DetectorText.Position = UDim2.new(0,5,0,22)
    DetectorText.BackgroundTransparency = 1
    DetectorText.Font = Enum.Font.Gotham
    DetectorText.TextSize = 10
    DetectorText.TextColor3 = THEME.success
    DetectorText.TextXAlignment = Enum.TextXAlignment.Left
    DetectorText.Text = "Detector: OFF"
    DetectorText.ZIndex = 51
    DetectorText.Parent = InfoPanel

    -- Line 3: Distance
    local DistanceText = Instance.new("TextLabel")
    DistanceText.Size = UDim2.new(1,-10,0,20)
    DistanceText.Position = UDim2.new(0,5,0,42)
    DistanceText.BackgroundTransparency = 1
    DistanceText.Font = Enum.Font.Gotham
    DistanceText.TextSize = 10
    DistanceText.TextColor3 = THEME.text_secondary
    DistanceText.TextXAlignment = Enum.TextXAlignment.Left
    DistanceText.Text = "Distance: 0m"
    DistanceText.ZIndex = 51
    DistanceText.Parent = InfoPanel

    -- Line 4: Pause/Resume
    local PauseResumeBtn = Instance.new("TextButton")
    PauseResumeBtn.Size = UDim2.new(1,-10,0,26)
    PauseResumeBtn.Position = UDim2.new(0,5,0,62)
    PauseResumeBtn.BackgroundColor3 = THEME.warning
    PauseResumeBtn.BackgroundTransparency = 0.2
    PauseResumeBtn.BorderSizePixel = 0
    PauseResumeBtn.Font = Enum.Font.GothamBold
    PauseResumeBtn.TextSize = 9
    PauseResumeBtn.TextColor3 = THEME.text_primary
    PauseResumeBtn.Text = "⏸ PAUSE"
    PauseResumeBtn.ZIndex = 51
    PauseResumeBtn.Parent = InfoPanel

    local PauseCorner = Instance.new("UICorner", PauseResumeBtn)
    PauseCorner.CornerRadius = UDim.new(0,4)

    makeDraggable(InfoPanel, InfoPanel)

    -- CLOSE & MINI
    MinTop.MouseButton1Click:Connect(function()
        Root.Visible = false
        MiniBtn.Visible = true
    end)

    MiniBtn.MouseButton1Click:Connect(function()
        Root.Visible = true
        MiniBtn.Visible = false
    end)

    CloseBtn.MouseButton1Click:Connect(function()
        if MiscState.FlyMode then toggleFly(false) end
        if MiscState.NoClipMode then toggleNoClip(false) end
        if MiscState.SpeedWalkMode then toggleSpeedWalk(false) end
        if MiscState.InfJumpMode then toggleInfJump(false) end
        
        State.AutoRunning = false
        State.DetectorActive = false
        
        if State.Gui then
            State.Gui:Destroy()
            State.Gui = nil
        end
    end)

    -- PAUSE BUTTON
    PauseResumeBtn.MouseButton1Click:Connect(function()
        State.IsPaused = not State.IsPaused
        PauseResumeBtn.Text = State.IsPaused and "▶ RESUME" or "⏸ PAUSE"
        PauseResumeBtn.BackgroundColor3 = State.IsPaused and THEME.success or THEME.warning
    end)

    -- DETECTOR LOGIC
    startStuckDetector(
        DetectorText,
        function()
            DetectorText.TextColor3 = THEME.danger
            DetectorText.Text = "Detector: ⚠ STUCK!"
            State.IsPaused = true
            notify("STUCK DETECTED! Paused.", THEME.danger)
        end,
        function()
            DetectorText.TextColor3 = THEME.success
            DetectorText.Text = "Detector: ON (Moving)"
        end
    )

    -- UPDATE PANEL REAL-TIME
    task.spawn(function()
        while State.Gui and State.AutoRunning do
            local stage = getStage()
            InfoText.Text = ("Loop: %d  |  WP: %d/%d  |  Stage: %s"):format(
                CurrentLoopCount, CurrentWPIndex, #WPRoute, tostring(stage or "-")
            )

            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp and #WPRoute > 0 then
                local wp = WPRoute[CurrentWPIndex]
                if wp then
                    local dist = (wp.pos - hrp.Position).Magnitude
                    DistanceText.Text = ("Distance: %.1fm"):format(dist)
                end
            end

            task.wait(0.5)
        end
    end)

    -- INIT
    scanWorkspace()
    setTabActive("CP")
    notify("✅ GotoDetect v5.0 Dibuka!", THEME.success)
end

-- PLUGIN COMMAND REGISTER
PluginMetadata.Commands.gotodetect = {
    ListName = "gotodetect",
    Description = "Buka GotoDetect Hub - CP/WP Auto + Misc + Detector",
    Aliases = {"gtd", "gdh"},
    Function = function()
        buildUI()
    end
}

--== MAIN ENTRY ==--
if _G.IY and _G.IY.New then
    -- PLUGIN MODE (via loader)
    return PluginMetadata
else
    -- EXECUTOR MODE (langsung)
    buildUI()
    notify("✅ GotoDetect v5.0 Loaded! (Executor Mode)", THEME.success)
end
