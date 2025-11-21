-- GotoDetect GPT Standalone v1
-- Jalankan langsung di executor (BUKAN format Infinite Yield plugin)

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UIS = game:GetService("UserInputService")

-- ================== KEYWORDS (default, bisa diubah di UI) ==================
local KEYWORDS = {
    Checkpoint = {"checkpoint","cp","stage","level"},
    Summit     = {"summit","goal","finish","end","peak","top"}
}

local State = {
    Gui         = nil,
    Minified    = false,
    ActiveTab   = "Checkpoint",
    LastScan    = nil,
    AutoRunning = false
}

-- ========================= UTILITIES =========================
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
    local char = LocalPlayer.Character
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

local function notify(text)
    local parent = LocalPlayer:FindFirstChildOfClass("PlayerGui") or game:GetService("CoreGui")

    local sg = Instance.new("ScreenGui")
    sg.Name = "GotoDetectNotify"
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0,260,0,28)
    lbl.Position = UDim2.new(0.5,-130,0.12,0)
    lbl.BackgroundColor3 = Color3.fromRGB(30,30,36)
    lbl.BackgroundTransparency = 0.2
    lbl.BorderSizePixel = 0
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 14
    lbl.TextColor3 = Color3.new(1,1,1)
    lbl.Text = text
    lbl.Parent = sg

    task.delay(1.3,function()
        if sg.Parent then sg:Destroy() end
    end)
end

local function makeDraggable(frame)
    local dragging = false
    local dragStart, startPos

    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos  = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- ========================= SCAN WORKSPACE =========================
local function scanWorkspace()
    local results = {
        Checkpoint = {},
        Summit     = {}
    }

    local function recurse(parent)
        for _,obj in ipairs(parent:GetChildren()) do
            if obj:IsA("BasePart") or obj:IsA("Model") then
                local lname = obj.Name:lower()

                if matchAny(lname, KEYWORDS.Checkpoint) then
                    table.insert(results.Checkpoint,{
                        instance = obj,
                        number   = getNumberAtEnd(obj.Name),
                        name     = obj.Name,
                        path     = getFullPath(obj)
                    })
                end
                if matchAny(lname, KEYWORDS.Summit) then
                    table.insert(results.Summit,{
                        instance = obj,
                        name     = obj.Name,
                        path     = getFullPath(obj)
                    })
                end
            end
            recurse(obj)
        end
    end

    recurse(workspace)

    table.sort(results.Checkpoint,function(a,b)
        local na,nb = a.number or 0, b.number or 0
        return na < nb
    end)

    State.LastScan = results
    return results
end

-- ========================= UI BUILD =========================
local function buildUI()
    if State.Gui and State.Gui.Parent then State.Gui:Destroy() end

    local parent = LocalPlayer:FindFirstChildOfClass("PlayerGui") or game:GetService("CoreGui")

    local sg = Instance.new("ScreenGui")
    sg.Name = "GotoDetectStandalone"
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent = parent
    State.Gui = sg

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0,340,0,220)
    frame.Position = UDim2.new(0.5,-170,0.2,0)
    frame.BackgroundColor3 = Color3.fromRGB(22,22,28)
    frame.BorderSizePixel = 0
    frame.Parent = sg
    makeDraggable(frame)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1,-60,0,24)
    title.Position = UDim2.new(0,8,0,0)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextColor3 = Color3.fromRGB(220,230,255)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "GotoDetect Standalone  (CP / Summit + Auto Loop)"
    title.Parent = frame

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0,24,0,20)
    closeBtn.Position = UDim2.new(1,-28,0,2)
    closeBtn.BackgroundColor3 = Color3.fromRGB(180,50,60)
    closeBtn.BorderSizePixel = 0
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.TextColor3 = Color3.new(1,1,1)
    closeBtn.Text = "X"
    closeBtn.Parent = frame
    closeBtn.MouseButton1Click:Connect(function()
        if State.Gui then State.Gui:Destroy() end
    end)

    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0,24,0,20)
    minBtn.Position = UDim2.new(1,-54,0,2)
    minBtn.BackgroundColor3 = Color3.fromRGB(34,34,44)
    minBtn.BorderSizePixel = 0
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 16
    minBtn.TextColor3 = Color3.fromRGB(120,170,230)
    minBtn.Text = "_"
    minBtn.Parent = frame

    local body = Instance.new("Frame")
    body.Size = UDim2.new(1,0,1,-24)
    body.Position = UDim2.new(0,0,0,24)
    body.BackgroundTransparency = 1
    body.Parent = frame

    local allContent = {}

    local function reg(obj)
        table.insert(allContent,obj)
        return obj
    end

    -- Top: Rescan + Edit Keywords + info
    local topBar = reg(Instance.new("Frame"))
    topBar.Size = UDim2.new(1,-16,0,38)
    topBar.Position = UDim2.new(0,8,0,0)
    topBar.BackgroundTransparency = 1
    topBar.Parent = body

    local scanBtn = reg(Instance.new("TextButton"))
    scanBtn.Size = UDim2.new(0,70,0,22)
    scanBtn.Position = UDim2.new(0,0,0,2)
    scanBtn.BackgroundColor3 = Color3.fromRGB(80,200,120)
    scanBtn.BorderSizePixel = 0
    scanBtn.Font = Enum.Font.GothamBold
    scanBtn.TextSize = 13
    scanBtn.TextColor3 = Color3.new(1,1,1)
    scanBtn.Text = "Rescan"
    scanBtn.Parent = topBar

    local kwBtn = reg(Instance.new("TextButton"))
    kwBtn.Size = UDim2.new(0,90,0,22)
    kwBtn.Position = UDim2.new(0,78,0,2)
    kwBtn.BackgroundColor3 = Color3.fromRGB(60,80,130)
    kwBtn.BorderSizePixel = 0
    kwBtn.Font = Enum.Font.Gotham
    kwBtn.TextSize = 11
    kwBtn.TextColor3 = Color3.new(1,1,1)
    kwBtn.Text = "Edit Keywords"
    kwBtn.Parent = topBar

    local info = reg(Instance.new("TextLabel"))
    info.Size = UDim2.new(1,-180,0,22)
    info.Position = UDim2.new(0,170,0,2)
    info.BackgroundTransparency = 1
    info.Font = Enum.Font.Gotham
    info.TextSize = 12
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.TextColor3 = Color3.fromRGB(200,210,230)
    info.Text = "Scan CP/Summit lalu bisa TP atau Run Auto Summit."
    info.Parent = topBar

    -- Auto row
    local autoRow = reg(Instance.new("Frame"))
    autoRow.Size = UDim2.new(1,-16,0,24)
    autoRow.Position = UDim2.new(0,8,0,38)
    autoRow.BackgroundTransparency = 1
    autoRow.Parent = body

    local delayLabel = reg(Instance.new("TextLabel"))
    delayLabel.Size = UDim2.new(0,60,0,18)
    delayLabel.Position = UDim2.new(0,0,0,4)
    delayLabel.BackgroundTransparency = 1
    delayLabel.Font = Enum.Font.Gotham
    delayLabel.TextSize = 11
    delayLabel.TextXAlignment = Enum.TextXAlignment.Left
    delayLabel.TextColor3 = Color3.fromRGB(200,210,230)
    delayLabel.Text = "Delay(s):"
    delayLabel.Parent = autoRow

    local delayBox = reg(Instance.new("TextBox"))
    delayBox.Size = UDim2.new(0,42,0,18)
    delayBox.Position = UDim2.new(0,60,0,4)
    delayBox.BackgroundColor3 = Color3.fromRGB(32,36,46)
    delayBox.BorderSizePixel = 0
    delayBox.Font = Enum.Font.Gotham
    delayBox.TextSize = 11
    delayBox.TextColor3 = Color3.fromRGB(220,235,255)
    delayBox.PlaceholderText = "0.4"
    delayBox.Text = ""
    delayBox.Parent = autoRow

    local loopLabel = reg(Instance.new("TextLabel"))
    loopLabel.Size = UDim2.new(0,50,0,18)
    loopLabel.Position = UDim2.new(0,108,0,4)
    loopLabel.BackgroundTransparency = 1
    loopLabel.Font = Enum.Font.Gotham
    loopLabel.TextSize = 11
    loopLabel.TextXAlignment = Enum.TextXAlignment.Left
    loopLabel.TextColor3 = Color3.fromRGB(200,210,230)
    loopLabel.Text = "Loop:"
    loopLabel.Parent = autoRow

    local loopBox = reg(Instance.new("TextBox"))
    loopBox.Size = UDim2.new(0,38,0,18)
    loopBox.Position = UDim2.new(0,150,0,4)
    loopBox.BackgroundColor3 = Color3.fromRGB(32,36,46)
    loopBox.BorderSizePixel = 0
    loopBox.Font = Enum.Font.Gotham
    loopBox.TextSize = 11
    loopBox.TextColor3 = Color3.fromRGB(220,235,255)
    loopBox.PlaceholderText = "1"
    loopBox.Text = ""
    loopBox.Parent = autoRow

    local autoBtn = reg(Instance.new("TextButton"))
    autoBtn.Size = UDim2.new(0,90,0,20)
    autoBtn.Position = UDim2.new(0,198,0,2)
    autoBtn.BackgroundColor3 = Color3.fromRGB(70,130,255)
    autoBtn.BorderSizePixel = 0
    autoBtn.Font = Enum.Font.GothamBold
    autoBtn.TextSize = 12
    autoBtn.TextColor3 = Color3.new(1,1,1)
    autoBtn.Text = "Run Auto Summit"
    autoBtn.Parent = autoRow

    local stopBtn = reg(Instance.new("TextButton"))
    stopBtn.Size = UDim2.new(0,40,0,20)
    stopBtn.Position = UDim2.new(1,-40,0,2)
    stopBtn.BackgroundColor3 = Color3.fromRGB(200,60,70)
    stopBtn.BorderSizePixel = 0
    stopBtn.Font = Enum.Font.GothamBold
    stopBtn.TextSize = 12
    stopBtn.TextColor3 = Color3.new(1,1,1)
    stopBtn.Text = "Stop"
    stopBtn.Parent = autoRow

    -- Tabs
    local tabs = reg(Instance.new("Frame"))
    tabs.Size = UDim2.new(1,-16,0,20)
    tabs.Position = UDim2.new(0,8,0,64)
    tabs.BackgroundTransparency = 1
    tabs.Parent = body

    local function makeTab(name,xScale)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0.5,-2,1,0)
        b.Position = UDim2.new(xScale,0,0,0)
        b.BackgroundColor3 = Color3.fromRGB(40,40,55)
        b.BorderSizePixel = 0
        b.Font = Enum.Font.GothamBold
        b.TextSize = 12
        b.TextColor3 = Color3.fromRGB(210,220,255)
        b.Text = name
        b.Parent = tabs
        return b
    end

    local tabCP = makeTab("Checkpoint",0)
    local tabSM = makeTab("Summit",0.5)
    reg(tabCP); reg(tabSM)

    local function setActiveTab(which)
        State.ActiveTab = which
        local function sel(btn,active)
            btn.BackgroundColor3 = active and Color3.fromRGB(80,110,190) or Color3.fromRGB(40,40,55)
        end
        sel(tabCP,which=="Checkpoint")
        sel(tabSM,which=="Summit")
    end
    setActiveTab("Checkpoint")

    -- Lists
    local listHolder = reg(Instance.new("Frame"))
    listHolder.Size = UDim2.new(1,-16,1,-90)
    listHolder.Position = UDim2.new(0,8,0,88)
    listHolder.BackgroundColor3 = Color3.fromRGB(28,28,34)
    listHolder.BorderSizePixel = 0
    listHolder.Parent = body

    local function makeList()
        local sf = Instance.new("ScrollingFrame")
        sf.Size = UDim2.new(1,0,1,0)
        sf.BackgroundTransparency = 1
        sf.BorderSizePixel = 0
        sf.ScrollBarThickness = 5
        sf.ScrollingEnabled = true
        sf.CanvasSize = UDim2.new(0,0,0,0)
        sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
        sf.Parent = listHolder

        local layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0,1)
        layout.Parent = sf

        return sf
    end

    local listCP = reg(makeList())
    local listSM = reg(makeList())

    local function updateListVisible()
        listCP.Visible = (State.ActiveTab=="Checkpoint")
        listSM.Visible = (State.ActiveTab=="Summit")
    end
    updateListVisible()

    tabCP.MouseButton1Click:Connect(function() setActiveTab("Checkpoint"); updateListVisible() end)
    tabSM.MouseButton1Click:Connect(function() setActiveTab("Summit");     updateListVisible() end)

    -- Keyword panel
    local kwFrame = Instance.new("Frame")
    kwFrame.Size = UDim2.new(0,260,0,110)
    kwFrame.Position = UDim2.new(0,40,0,40)
    kwFrame.BackgroundColor3 = Color3.fromRGB(18,18,24)
    kwFrame.BorderSizePixel = 0
    kwFrame.Visible = false
    kwFrame.Parent = frame
    reg(kwFrame)

    local kwTitle = Instance.new("TextLabel")
    kwTitle.Size = UDim2.new(1,-8,0,18)
    kwTitle.Position = UDim2.new(0,4,0,2)
    kwTitle.BackgroundTransparency = 1
    kwTitle.Font = Enum.Font.GothamBold
    kwTitle.TextSize = 12
    kwTitle.TextColor3 = Color3.fromRGB(220,230,255)
    kwTitle.TextXAlignment = Enum.TextXAlignment.Left
    kwTitle.Text = "Keywords (pisah koma)"
    kwTitle.Parent = kwFrame

    local function listToString(t) return table.concat(t,",") end
    local function stringToList(s)
        local out={}
        for tok in string.gmatch(s,"[^,]+") do
            tok = tok:lower():gsub("^%s+",""):gsub("%s+$","")
            if tok~="" then table.insert(out,tok) end
        end
        return out
    end

    local function mkKwRow(lblText,def,yOff)
        local lab = Instance.new("TextLabel")
        lab.Size = UDim2.new(0,70,0,18)
        lab.Position = UDim2.new(0,4,0,yOff)
        lab.BackgroundTransparency = 1
        lab.Font = Enum.Font.Gotham
        lab.TextSize = 11
        lab.TextXAlignment = Enum.TextXAlignment.Left
        lab.TextColor3 = Color3.fromRGB(200,210,230)
        lab.Text = lblText
        lab.Parent = kwFrame

        local box = Instance.new("TextBox")
        box.Size = UDim2.new(1,-78,0,18)
        box.Position = UDim2.new(0,74,0,yOff)
        box.BackgroundColor3 = Color3.fromRGB(28,28,36)
        box.BorderSizePixel = 0
        box.Font = Enum.Font.Gotham
        box.TextSize = 11
        box.TextColor3 = Color3.fromRGB(220,230,255)
        box.ClearTextOnFocus = false
        box.Text = def
        box.Parent = kwFrame
        return box
    end

    local cpBox = mkKwRow("Checkpoint", listToString(KEYWORDS.Checkpoint), 24)
    local smBox = mkKwRow("Summit",     listToString(KEYWORDS.Summit),     46)

    local applyBtn = Instance.new("TextButton")
    applyBtn.Size = UDim2.new(0,70,0,20)
    applyBtn.Position = UDim2.new(0,4,0,80)
    applyBtn.BackgroundColor3 = Color3.fromRGB(80,200,120)
    applyBtn.BorderSizePixel = 0
    applyBtn.Font = Enum.Font.GothamBold
    applyBtn.TextSize = 12
    applyBtn.TextColor3 = Color3.new(1,1,1)
    applyBtn.Text = "Apply"
    applyBtn.Parent = kwFrame

    local closeKw = Instance.new("TextButton")
    closeKw.Size = UDim2.new(0,70,0,20)
    closeKw.Position = UDim2.new(1,-74,0,80)
    closeKw.BackgroundColor3 = Color3.fromRGB(120,60,70)
    closeKw.BorderSizePixel = 0
    closeKw.Font = Enum.Font.GothamBold
    closeKw.TextSize = 12
    closeKw.TextColor3 = Color3.new(1,1,1)
    closeKw.Text = "Close"
    closeKw.Parent = kwFrame

    kwBtn.MouseButton1Click:Connect(function()
        kwFrame.Visible = not kwFrame.Visible
    end)
    closeKw.MouseButton1Click:Connect(function()
        kwFrame.Visible = false
    end)

    -- Minimize: hanya hide/show konten, tidak execute apa-apa
    minBtn.MouseButton1Click:Connect(function()
        State.Minified = not State.Minified
        for _,obj in ipairs(allContent) do
            obj.Visible = not State.Minified
        end
        if State.Minified then
            kwFrame.Visible = false
        end
    end)

    -- list helpers
    local function clearList(sf)
        for _,c in ipairs(sf:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end
    end

    local function addRow(sf,item)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1,0,0,34)
        row.BackgroundTransparency = 1
        row.Parent = sf

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1,-50,0,16)
        nameLabel.Position = UDim2.new(0,4,0,0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Font = Enum.Font.Gotham
        nameLabel.TextSize = 11
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        local extra = item.number and (" #"..tostring(item.number)) or ""
        nameLabel.Text = item.name..extra
        nameLabel.TextColor3 = Color3.fromRGB(220,230,255)
        nameLabel.Parent = row

        local pathLabel = Instance.new("TextLabel")
        pathLabel.Size = UDim2.new(1,-4,0,16)
        pathLabel.Position = UDim2.new(0,4,0,16)
        pathLabel.BackgroundTransparency = 1
        pathLabel.Font = Enum.Font.Gotham
        pathLabel.TextSize = 10
        pathLabel.TextXAlignment = Enum.TextXAlignment.Left
        pathLabel.TextTruncate = Enum.TextTruncate.AtEnd
        pathLabel.TextColor3 = Color3.fromRGB(180,190,210)
        pathLabel.Text = item.path
        pathLabel.Parent = row

        local tpBtn = Instance.new("TextButton")
        tpBtn.Size = UDim2.new(0,40,0,18)
        tpBtn.Position = UDim2.new(1,-42,0,8)
        tpBtn.BackgroundColor3 = Color3.fromRGB(70,130,255)
        tpBtn.BorderSizePixel = 0
        tpBtn.Font = Enum.Font.GothamBold
        tpBtn.TextSize = 10
        tpBtn.TextColor3 = Color3.new(1,1,1)
        tpBtn.Text = "TP"
        tpBtn.Parent = row

        tpBtn.MouseButton1Click:Connect(function()
            teleportTo(item.instance)
            notify("TP → "..item.name)
        end)
    end

    local function fillFromData(data)
        clearList(listCP); clearList(listSM)
        for _,it in ipairs(data.Checkpoint) do addRow(listCP,it) end
        for _,it in ipairs(data.Summit)     do addRow(listSM,it) end
        info.Text = "Checkpoint: "..#data.Checkpoint.." | Summit: "..#data.Summit
    end

    local function doScan()
        info.Text = "Scanning..."
        local data = scanWorkspace()
        fillFromData(data)
    end

    scanBtn.MouseButton1Click:Connect(doScan)
    doScan()

    updateListVisible()

    applyBtn.MouseButton1Click:Connect(function()
        KEYWORDS.Checkpoint = stringToList(cpBox.Text)
        KEYWORDS.Summit     = stringToList(smBox.Text)
        notify("Keywords updated, rescan...")
        doScan()
    end)

    autoBtn.MouseButton1Click:Connect(function()
        if State.AutoRunning then
            notify("Auto sudah berjalan")
            return
        end
        local data = State.LastScan or scanWorkspace()
        if #data.Checkpoint == 0 or #data.Summit == 0 then
            notify("Butuh minimal 1 CP & 1 Summit")
            return
        end
        local delay = tonumber(delayBox.Text) or 0.4
        local loops = tonumber(loopBox.Text)  or 1
        local summitTarget = data.Summit[1].instance

        State.AutoRunning = true
        notify("Auto Summit start x"..tostring(loops))

        task.spawn(function()
            for l=1,loops do
                if not State.AutoRunning then break end
                for _,cp in ipairs(data.Checkpoint) do
                    if not State.AutoRunning then break end
                    teleportTo(cp.instance)
                    task.wait(delay)
                end
                if not State.AutoRunning then break end
                teleportTo(summitTarget)
                notify("Summit loop "..tostring(l))
                task.wait(delay+0.3)
            end
            State.AutoRunning = false
            notify("Auto Summit selesai")
        end)
    end)

    stopBtn.MouseButton1Click:Connect(function()
        if State.AutoRunning then
            State.AutoRunning = false
            notify("Auto Summit dihentikan")
        else
            notify("Tidak ada auto yang berjalan")
        end
    end)
end

-- Jalankan UI langsung
buildUI()
notify("GotoDetect Standalone loaded")