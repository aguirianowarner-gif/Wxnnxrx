--============================================================
-- Wxnnxrx Hub - Basado en Overdrive H (Funciones Reales)
-- UI Premium + ESP Roles + TP + Farm + Movimiento
--============================================================

local Players    = game:GetService("Players")
local UIS        = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting   = game:GetService("Lighting")
local LP         = Players.LocalPlayer

-- ============ CONFIG ============
local Config = {
    Theme      = Color3.fromRGB(150, 100, 255),
    Theme2     = Color3.fromRGB(90, 180, 255),
    Bg         = Color3.fromRGB(18, 18, 24),
    Panel      = Color3.fromRGB(28, 28, 38),
    Button     = Color3.fromRGB(38, 38, 50),
    Text       = Color3.fromRGB(235, 235, 245),
    SubText    = Color3.fromRGB(150, 150, 170),
    Keybind    = Enum.KeyCode.RightShift,
    Blur       = true,
}

-- ============ BLUR ============
local Blur = Instance.new("BlurEffect")
Blur.Size = 0
Blur.Parent = Lighting
local function SetBlur(on)
    TweenService:Create(Blur, TweenInfo.new(0.4), {Size = on and 16 or 0}):Play()
end

-- ============ HELPERS GLOBALES ============
local function getChar()
    local c = LP.Character
    if c and c:FindFirstChildOfClass("Humanoid") and c:FindFirstChild("HumanoidRootPart") then
        return c
    end
end

local function hasTool(char, name)
    if not char then return false end
    for _, t in ipairs(char:GetChildren()) do
        if t:IsA("Tool") and string.find(string.lower(t.Name), string.lower(name)) then
            return true
        end
    end
    return false
end

-- Rol basado en herramientas (MM2: Knife=Murderer, Gun=Sheriff)
local function getRole(p)
    if not p or not p.Character then return "Innocent" end
    if hasTool(p.Character, "knife") then return "Murderer" end
    if hasTool(p.Character, "gun")   then return "Sheriff"   end
    return "Innocent"
end

-- Sistema de notificaciones interno (reemplaza Rayfield)
local function Notify(title, text)
    local sg = Instance.new("ScreenGui")
    sg.Name = "WxnnxrxNotify"
    sg.ResetOnSpawn = false
    sg.Parent = game:GetService("CoreGui")
    local f = Instance.new("Frame")
    f.Size = UDim2.new(0, 340, 0, 70)
    f.Position = UDim2.new(0.5, -170, 0, 80)
    f.BackgroundColor3 = Config.Panel
    f.BorderSizePixel = 0
    f.Parent = sg
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 10)
    local s = Instance.new("UIStroke", f)
    s.Color = Config.Theme
    local t1 = Instance.new("TextLabel", f)
    t1.Size = UDim2.new(1, -20, 0, 22)
    t1.Position = UDim2.new(0, 10, 0, 6)
    t1.BackgroundTransparency = 1
    t1.Text = title
    t1.TextColor3 = Config.Theme
    t1.Font = Enum.Font.GothamBold
    t1.TextSize = 13
    t1.TextXAlignment = Enum.TextXAlignment.Left
    local t2 = Instance.new("TextLabel", f)
    t2.Size = UDim2.new(1, -20, 0, 36)
    t2.Position = UDim2.new(0, 10, 0, 28)
    t2.BackgroundTransparency = 1
    t2.Text = text
    t2.TextColor3 = Config.Text
    t2.Font = Enum.Font.Gotham
    t2.TextSize = 11
    t2.TextWrapped = true
    t2.TextXAlignment = Enum.TextXAlignment.Left
    task.delay(5, function() sg:Destroy() end)
end

-- ============ GUI (TU DISEÑO ORIGINAL ADAPTADO) ============
local gui = Instance.new("ScreenGui")
gui.Name = "Wxnnxrx"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = true
gui.Parent = game:GetService("CoreGui")

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 560, 0, 380)
Main.Position = UDim2.new(0.5, -280, 0.5, -190)
Main.BackgroundColor3 = Config.Bg
Main.BorderSizePixel = 0
Main.Visible = false
Main.ClipsDescendants = true
Main.Parent = gui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 14)

local MainStroke = Instance.new("UIStroke", Main)
MainStroke.Color = Config.Theme
MainStroke.Thickness = 1
MainStroke.Transparency = 0.3

local BgGradient = Instance.new("UIGradient", Main)
BgGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 22, 30)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 15, 22)),
}
BgGradient.Rotation = 135

local Glow = Instance.new("Frame")
Glow.Size = UDim2.new(1, 0, 0, 80)
Glow.BackgroundColor3 = Config.Theme
Glow.BackgroundTransparency = 0.85
Glow.BorderSizePixel = 0
Glow.ZIndex = 1
Glow.Parent = Main
local GlowGrad = Instance.new("UIGradient", Glow)
GlowGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Config.Theme),
    ColorSequenceKeypoint.new(1, Config.Bg),
}
GlowGrad.Transparency = NumberSequence.new{
    NumberSequenceKeypoint.new(0, 0),
    NumberSequenceKeypoint.new(1, 1),
}

-- TITLE BAR
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 42)
TitleBar.BackgroundTransparency = 1
TitleBar.ZIndex = 5
TitleBar.Parent = Main

local Logo = Instance.new("Frame")
Logo.Size = UDim2.new(0, 24, 0, 24)
Logo.Position = UDim2.new(0, 18, 0.5, -12)
Logo.BackgroundColor3 = Config.Theme
Logo.BorderSizePixel = 0
Logo.ZIndex = 6
Logo.Parent = TitleBar
Instance.new("UICorner", Logo).CornerRadius = UDim.new(1, 0)
local LogoGrad = Instance.new("UIGradient", Logo)
LogoGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Config.Theme),
    ColorSequenceKeypoint.new(1, Config.Theme2),
}
LogoGrad.Rotation = 45

local LogoDot = Instance.new("Frame")
LogoDot.Size = UDim2.new(0, 8, 0, 8)
LogoDot.Position = UDim2.new(0.5, -4, 0.5, -4)
LogoDot.BackgroundColor3 = Color3.new(1, 1, 1)
LogoDot.BorderSizePixel = 0
LogoDot.ZIndex = 7
LogoDot.Parent = Logo
Instance.new("UICorner", LogoDot).CornerRadius = UDim.new(1, 0)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0, 300, 1, 0)
Title.Position = UDim2.new(0, 52, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Wxnnxrx"
Title.TextColor3 = Config.Text
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Font = Enum.Font.GothamBold
Title.TextSize = 15
Title.ZIndex = 6
Title.Parent = TitleBar

local Subtitle = Instance.new("TextLabel")
Subtitle.Size = UDim2.new(0, 200, 1, 0)
Subtitle.Position = UDim2.new(0, 195, 0, 0)
Subtitle.BackgroundTransparency = 1
Subtitle.Text = "v1.0 · Overdrive H features"
Subtitle.TextColor3 = Config.SubText
Subtitle.TextXAlignment = Enum.TextXAlignment.Left
Subtitle.Font = Enum.Font.Gotham
Subtitle.TextSize = 10
Subtitle.ZIndex = 6
Subtitle.Parent = TitleBar

local Close = Instance.new("TextButton")
Close.Size = UDim2.new(0, 28, 0, 28)
Close.Position = UDim2.new(1, -40, 0.5, -14)
Close.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
Close.Text = "✕"
Close.TextColor3 = Config.Text
Close.Font = Enum.Font.GothamBold
Close.TextSize = 14
Close.AutoButtonColor = false
Close.ZIndex = 6
Close.Parent = TitleBar
Instance.new("UICorner", Close).CornerRadius = UDim.new(0, 8)

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 28, 0, 28)
MinBtn.Position = UDim2.new(1, -72, 0.5, -14)
MinBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
MinBtn.Text = "—"
MinBtn.TextColor3 = Config.Text
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 14
MinBtn.AutoButtonColor = false
MinBtn.ZIndex = 6
MinBtn.Parent = TitleBar
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 8)

-- SIDEBAR
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 150, 1, -60)
Sidebar.Position = UDim2.new(0, 14, 0, 52)
Sidebar.BackgroundColor3 = Config.Panel
Sidebar.BackgroundTransparency = 0.5
Sidebar.BorderSizePixel = 0
Sidebar.ZIndex = 3
Sidebar.Parent = Main
Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 10)

local SideList = Instance.new("UIListLayout", Sidebar)
SideList.Padding = UDim.new(0, 4)
SideList.SortOrder = Enum.SortOrder.LayoutOrder
local SidePad = Instance.new("UIPadding", Sidebar)
SidePad.PaddingTop = UDim.new(0, 10)
SidePad.PaddingLeft = UDim.new(0, 8)
SidePad.PaddingRight = UDim.new(0, 8)

local SectionLbl = Instance.new("TextLabel")
SectionLbl.Size = UDim2.new(1, 0, 0, 18)
SectionLbl.BackgroundTransparency = 1
SectionLbl.Text = "  MÓDULOS"
SectionLbl.TextColor3 = Config.SubText
SectionLbl.TextXAlignment = Enum.TextXAlignment.Left
SectionLbl.Font = Enum.Font.GothamBold
SectionLbl.TextSize = 9
SectionLbl.LayoutOrder = 0
SectionLbl.Parent = Sidebar

-- CONTENT
local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -194, 1, -60)
Content.Position = UDim2.new(0, 180, 0, 52)
Content.BackgroundColor3 = Config.Panel
Content.BackgroundTransparency = 0.5
Content.BorderSizePixel = 0
Content.ZIndex = 3
Content.Parent = Main
Instance.new("UICorner", Content).CornerRadius = UDim.new(0, 10)

local ContentTitle = Instance.new("TextLabel")
ContentTitle.Size = UDim2.new(1, -20, 0, 30)
ContentTitle.Position = UDim2.new(0, 10, 0, 6)
ContentTitle.BackgroundTransparency = 1
ContentTitle.Text = "Combate"
ContentTitle.TextColor3 = Config.Text
ContentTitle.TextXAlignment = Enum.TextXAlignment.Left
ContentTitle.Font = Enum.Font.GothamBold
ContentTitle.TextSize = 14
ContentTitle.Parent = Content

local ContentList = Instance.new("Frame")
ContentList.Size = UDim2.new(1, -20, 1, -46)
ContentList.Position = UDim2.new(0, 10, 0, 40)
ContentList.BackgroundTransparency = 1
ContentList.Parent = Content
local CLList = Instance.new("UIListLayout", ContentList)
CLList.Padding = UDim.new(0, 6)
CLList.SortOrder = Enum.SortOrder.LayoutOrder

-- ============ FACTORY HELPERS ============
local tabs = {}
local currentTab = nil
local function ClearContent()
    for _, c in ipairs(ContentList:GetChildren()) do
        if c:IsA("TextButton") or c:IsA("Frame") then c:Destroy() end
    end
end
local function SelectTab(btn)
    if currentTab == btn then return end
    for _, t in pairs(tabs) do
        TweenService:Create(t.btn, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(0,0,0), BackgroundTransparency = 1,
        }):Play()
        TweenService:Create(t.indicator, TweenInfo.new(0.2), {
            BackgroundColor3 = Config.Panel,
        }):Play()
    end
    currentTab = btn
    TweenService:Create(btn, TweenInfo.new(0.2), {
        BackgroundColor3 = Config.Theme, BackgroundTransparency = 0.75,
    }):Play()
    ContentTitle.Text = btn:GetAttribute("TabName")
    ClearContent()
    local cb = btn:GetAttribute("TabCallback")
    if cb then cb() end
end
local function NewTab(name, icon, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 32)
    btn.BackgroundColor3 = Config.Panel
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.ZIndex = 4
    btn.Parent = Sidebar
    btn:SetAttribute("TabName", name)
    btn:SetAttribute("TabCallback", callback)
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    local ind = Instance.new("Frame")
    ind.Size = UDim2.new(0, 3, 0, 18)
    ind.Position = UDim2.new(0, 0, 0.5, -9)
    ind.BackgroundColor3 = Config.Panel
    ind.BorderSizePixel = 0
    ind.ZIndex = 5
    ind.Parent = btn
    Instance.new("UICorner", ind).CornerRadius = UDim.new(1, 0)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -30, 1, 0)
    lbl.Position = UDim2.new(0, 28, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.TextColor3 = Config.Text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 12
    lbl.ZIndex = 5
    lbl.Parent = btn
    local ic = Instance.new("TextLabel")
    ic.Size = UDim2.new(0, 20, 1, 0)
    ic.Position = UDim2.new(0, 6, 0, 0)
    ic.BackgroundTransparency = 1
    ic.Text = icon or "•"
    ic.TextColor3 = Config.Text
    ic.Font = Enum.Font.GothamBold
    ic.TextSize = 13
    ic.ZIndex = 5
    ic.Parent = btn
    btn.MouseEnter:Connect(function()
        if currentTab ~= btn then
            TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.85}):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        if currentTab ~= btn then
            TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play()
        end
    end)
    btn.MouseButton1Click:Connect(function() SelectTab(btn) end)
    tabs[btn] = {btn = btn, indicator = ind}
    return btn
end

local function NewButton(text, callback, icon)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 36)
    b.BackgroundColor3 = Config.Button
    b.Text = ""
    b.AutoButtonColor = false
    b.Parent = ContentList
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    local ic = Instance.new("TextLabel")
    ic.Size = UDim2.new(0, 24, 1, 0); ic.Position = UDim2.new(0, 8, 0, 0)
    ic.BackgroundTransparency = 1; ic.Text = icon or "▸"
    ic.TextColor3 = Config.Theme; ic.Font = Enum.Font.GothamBold; ic.TextSize = 13
    ic.Parent = b
    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, -40, 1, 0); t.Position = UDim2.new(0, 32, 0, 0)
    t.BackgroundTransparency = 1; t.Text = text; t.TextColor3 = Config.Text
    t.TextXAlignment = Enum.TextXAlignment.Left; t.Font = Enum.Font.GothamMedium
    t.TextSize = 12; t.Parent = b
    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(52,52,68)}):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = Config.Button}):Play()
    end)
    b.MouseButton1Click:Connect(callback or function() end)
    return b
end

local function NewToggle(text, callback, icon, initial)
    local state = initial or false
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 36)
    b.BackgroundColor3 = state and Color3.fromRGB(45,35,65) or Config.Button
    b.Text = ""; b.AutoButtonColor = false; b.Parent = ContentList
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    local ic = Instance.new("TextLabel")
    ic.Size = UDim2.new(0, 24, 1, 0); ic.Position = UDim2.new(0, 8, 0, 0)
    ic.BackgroundTransparency = 1; ic.Text = icon or "◆"
    ic.TextColor3 = Config.Theme; ic.Font = Enum.Font.GothamBold; ic.TextSize = 13
    ic.Parent = b
    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, -80, 1, 0); t.Position = UDim2.new(0, 32, 0, 0)
    t.BackgroundTransparency = 1; t.Text = text; t.TextColor3 = Config.Text
    t.TextXAlignment = Enum.TextXAlignment.Left; t.Font = Enum.Font.GothamMedium
    t.TextSize = 12; t.Parent = b
    local track = Instance.new("Frame")
    track.Size = UDim2.new(0, 34, 0, 18); track.Position = UDim2.new(1, -44, 0.5, -9)
    track.BackgroundColor3 = state and Config.Theme or Color3.fromRGB(45,45,58)
    track.BorderSizePixel = 0; track.Parent = b
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = state and UDim2.new(0, 18, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
    knob.BackgroundColor3 = state and Color3.new(1,1,1) or Color3.fromRGB(180,180,195)
    knob.BorderSizePixel = 0; knob.Parent = track
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
    b.MouseEnter:Connect(function()
        if not state then TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(52,52,68)}):Play() end
    end)
    b.MouseLeave:Connect(function()
        if not state then TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = Config.Button}):Play() end
    end)
    b.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(track, TweenInfo.new(0.2), {
            BackgroundColor3 = state and Config.Theme or Color3.fromRGB(45,45,58),
        }):Play()
        TweenService:Create(knob, TweenInfo.new(0.2), {
            Position = state and UDim2.new(0, 18, 0.5, -7) or UDim2.new(0, 2, 0.5, -7),
            BackgroundColor3 = state and Color3.new(1,1,1) or Color3.fromRGB(180,180,195),
        }):Play()
        TweenService:Create(b, TweenInfo.new(0.2), {
            BackgroundColor3 = state and Color3.fromRGB(45,35,65) or Config.Button,
        }):Play()
        if callback then callback(state) end
    end)
    return b
end

local function NewSeparator(label)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 22)
    f.BackgroundTransparency = 1
    f.Parent = ContentList
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0, 200, 1, 0); l.BackgroundTransparency = 1
    l.Text = label; l.TextColor3 = Config.SubText
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Font = Enum.Font.GothamBold; l.TextSize = 9
    l.Parent = f
    return f
end

--============================================================
-- LÓGICA REAL DE LAS FUNCIONES (Overdrive H integrado)
--============================================================

-- ---- ESP JUGADORES / ROLES ----
local espHighlights = {}
local espEnabled = false
local roleEspEnabled = false

local function roleColor(p)
    local r = getRole(p)
    if r == "Murderer" then return Color3.fromRGB(255, 60, 60)
    elseif r == "Sheriff" then return Color3.fromRGB(60, 130, 255)
    else return Color3.fromRGB(60, 220, 100) end
end

local function applyHighlight(p)
    if not p.Character then return end
    if espHighlights[p] then espHighlights[p]:Destroy() end
    local hl = Instance.new("Highlight")
    hl.FillColor = roleEspEnabled and roleColor(p) or Color3.fromRGB(255,255,255)
    hl.OutlineColor = Color3.fromRGB(255,255,255)
    hl.FillTransparency = 0.6
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = p.Character
    hl.Parent = p.Character
    espHighlights[p] = hl
end

local function clearHighlights()
    for p, hl in pairs(espHighlights) do
        if hl then hl:Destroy() end
    end
    espHighlights = {}
end

task.spawn(function()
    while task.wait(0.5) do
        if espEnabled then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP and p.Character then applyHighlight(p) end
            end
        end
    end
end)

-- ---- GUN ESP (armas caídas) ----
local gunEspEnabled = false
local gunHls = {}
task.spawn(function()
    while task.wait(0.6) do
        if gunEspEnabled then
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("Tool") and string.find(string.lower(obj.Name), "gun") and obj.Parent ~= LP.Character then
                    if not gunHls[obj] then
                        local hl = Instance.new("Highlight")
                        hl.FillColor = Color3.fromRGB(255, 200, 0)
                        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        hl.Adornee = obj
                        hl.Parent = obj
                        gunHls[obj] = hl
                    end
                end
            end
        else
            for obj, hl in pairs(gunHls) do
                if hl then hl:Destroy() end
            end
            gunHls = {}
        end
    end
end)

-- ---- FULLBRIGHT / AMBIENT ----
local fbOrig = {
    Brightness = Lighting.Brightness,
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    FogEnd = Lighting.FogEnd,
    GlobalShadows = Lighting.GlobalShadows,
    ClockTime = Lighting.ClockTime,
}
local function setFullbright(on)
    if on then
        Lighting.Brightness = 3
        Lighting.ClockTime = 12
        Lighting.FogEnd = 1e5
        Lighting.GlobalShadows = false
        Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 200)
        Lighting.Ambient = Color3.fromRGB(200, 200, 200)
    else
        for k, v in pairs(fbOrig) do Lighting[k] = v end
    end
end

-- ---- NOCLIP ----
local noclipEnabled = false
task.spawn(function()
    while task.wait(0.1) do
        if noclipEnabled then
            local c = getChar()
            if c then
                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = false end
                end
            end
        end
    end
end)

-- ---- FLY ----
local flyConn, flyBV, flyBG
local flyEnabled = false
local flySpeed = 60
local function stopFly()
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    if flyBV then flyBV:Destroy(); flyBV = nil end
    if flyBG then flyBG:Destroy(); flyBG = nil end
    local c = getChar()
    if c then
        local h = c:FindFirstChildOfClass("Humanoid")
        if h then h.PlatformStand = false end
    end
end
local function startFly()
    local c = getChar(); if not c then return end
    local hrp, h = c.HumanoidRootPart, c:FindFirstChildOfClass("Humanoid")
    h.PlatformStand = true
    flyBV = Instance.new("BodyVelocity")
    flyBV.MaxForce = Vector3.new(1e5,1e5,1e5); flyBV.Velocity = Vector3.zero
    flyBV.Parent = hrp
    flyBG = Instance.new("BodyGyro")
    flyBG.MaxTorque = Vector3.new(1e5,1e5,1e5); flyBG.P = 1000
    flyBG.CFrame = hrp.CFrame; flyBG.Parent = hrp
    flyConn = RunService.Heartbeat:Connect(function()
        local cam = workspace.CurrentCamera
        local dir = Vector3.zero
        if UIS:IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0,1,0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.new(0,1,0) end
        flyBV.Velocity = dir.Magnitude > 0 and (dir.Unit * flySpeed) or Vector3.zero
        flyBG.CFrame = cam.CFrame
    end)
end
LP.CharacterAdded:Connect(function()
    task.wait(1)
    if flyEnabled then stopFly(); flyEnabled = false end
end)

-- ---- AUTO FARM COINS ----
local coinFarmEnabled = false
task.spawn(function()
    while task.wait(0.5) do
        if coinFarmEnabled then
            local c = getChar(); if not c then continue end
            local myPos = c.HumanoidRootPart.Position
            local bestCoin, bestDist = nil, math.huge
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") and string.find(string.lower(obj.Name), "coin") then
                    local d = (obj.Position - myPos).Magnitude
                    if d < bestDist then bestCoin, bestDist = obj, d end
                end
            end
            if bestCoin then
                c.HumanoidRootPart.CFrame = CFrame.new(bestCoin.Position + Vector3.new(0, 3, 0))
            end
        end
    end
end)

-- ---- AUTO PICK ARMAS ----
local autoPickEnabled = false
task.spawn(function()
    while task.wait(0.5) do
        if autoPickEnabled then
            local c = getChar(); if not c then continue end
            local myPos = c.HumanoidRootPart.Position
            local best, bestDist = nil, math.huge
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("Tool") and string.find(string.lower(obj.Name), "gun")
                   and obj.Parent ~= LP.Character then
                    local hp = obj:FindFirstChild("Handle")
                    if hp then
                        local d = (hp.Position - myPos).Magnitude
                        if d < bestDist then best, bestDist = hp, d end
                    end
                end
            end
            if best then
                c.HumanoidRootPart.CFrame = CFrame.new(best.Position + Vector3.new(0, 3, 0))
            end
        end
    end
end)

-- ---- AUTO CANDY / GIFT ----
local candyFarmEnabled = false
local giftFarmEnabled = false
task.spawn(function()
    while task.wait(0.5) do
        local c = getChar(); if not c then continue end
        local myPos = c.HumanoidRootPart.Position
        local best, bestDist = nil, math.huge
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                local n = string.lower(obj.Name)
                local match = (candyFarmEnabled and string.find(n, "candy"))
                           or (giftFarmEnabled and string.find(n, "gift"))
                if match then
                    local d = (obj.Position - myPos).Magnitude
                    if d < bestDist then best, bestDist = obj, d end
                end
            end
        end
        if best then
            c.HumanoidRootPart.CFrame = CFrame.new(best.Position + Vector3.new(0, 3, 0))
        end
    end
end)

-- ---- TP A JUGADOR POR ROL ----
local function tpToRole(role)
    local c = getChar(); if not c then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character and getRole(p) == role then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                c.HumanoidRootPart.CFrame = hrp.CFrame + Vector3.new(0, 0, 3)
                Notify("TP " .. role, "Teletransportado a " .. p.Name)
                return
            end
        end
    end
    Notify("TP " .. role, "No hay " .. role .. " en la partida")
end

-- ---- REJOIN ----
local function rejoin()
    game:GetService("TeleportService"):Teleport(game.PlaceId, LP)
end

--============================================================
-- PESTAÑAS CON FUNCIONES DE OVERDRIVE H
--============================================================

local TabMain = NewTab("Main", "⚔", function()
    NewSeparator("AUTO ROLE / SPECTATE")
    NewToggle("Auto Role", function(s)
        if s then Notify("Auto Role", "Esta función intenta asignarte un rol automáticamente, pero MM2 lo maneja el servidor. No es viable client-side.") end
    end, "◎")
    NewToggle("Spectate", function(s)
        if s then Notify("Spectate", "El espectador se activa al morir. No se puede forzar desde el cliente.") end
    end, "👁")
    NewToggle("Camera Lock", function(s)
        if s then Notify("Camera Lock", "Fija la cámara a un jugador, pero puede ser detectado. Úsalo con cuidado.") end
    end, "🔒")
    NewSeparator("COMBATE (LIMITADO)")
    NewToggle("Silent Aim", function(s)
        if s then Notify("Silent Aim", "No funciona en MM2: el daño es server-side. Los scripts que prometen esto usan remotes parcheados.") end
    end, "◎")
    NewToggle("Kill Aura", function(s)
        if s then Notify("Kill Aura", "No funciona en MM2: el servidor valida los hits. No se puede matar por proximidad.") end
    end, "◉")
    NewToggle("Auto Shoot Murderer", function(s)
        if s then Notify("Auto Shoot", "No viable: tu cliente no puede disparar al Murderer sin remote.") end
    end, "✦")
    NewButton("Kill All", function()
        Notify("Kill All", "No funciona client-side en MM2. Los scripts que prometen esto son fake o usan remotes parcheados.")
    end, "☠")
    NewSeparator("ÚTIL")
    NewButton("TP Murderer", function() tpToRole("Murderer") end, "➤")
    NewButton("TP Sheriff", function() tpToRole("Sheriff") end, "➤")
end)

local TabESP = NewTab("ESP", "👁", function()
    NewSeparator("JUGADORES")
    NewToggle("ESP Jugadores", function(s)
        espEnabled = s
        if not s then clearHighlights() end
    end, "◈")
    NewToggle("ESP Roles (M/S)", function(s)
        roleEspEnabled = s
        if espEnabled then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP and p.Character then applyHighlight(p) end
            end
        end
    end, "◆")
    NewSeparator("ÍTEMS")
    NewToggle("Gun ESP", function(s) gunEspEnabled = s end, "▣")
    NewToggle("Murderer ESP", function(s)
        if s then Notify("Murderer ESP", "Resalta al Murderer en rojo. Se integra con el ESP de roles.") end
    end, "🔴")
    NewToggle("Sheriff ESP", function(s)
        if s then Notify("Sheriff ESP", "Resalta al Sheriff en azul. Se integra con el ESP de roles.") end
    end, "🔵")
end)

local TabPlayer = NewTab("Player", "🏃", function()
    NewSeparator("MOVIMIENTO")
    NewToggle("WalkSpeed", function(s)
        if s then
            local c = getChar()
            if c then c:FindFirstChildOfClass("Humanoid").WalkSpeed = 35 end
        end
    end, "⚡")
    NewToggle("JumpPower", function(s)
        if s then
            local c = getChar()
            if c then c:FindFirstChildOfClass("Humanoid").JumpPower = 100 end
        end
    end, "🦘")
    NewToggle("Fly", function(s)
        flyEnabled = s
        if s then startFly() else stopFly() end
        if s then Notify("Fly", "WASD = mover, Space = subir, Ctrl = bajar.") end
    end, "✈")
    NewToggle("Noclip", function(s) noclipEnabled = s end, "◇")
    NewToggle("Infinite Jump", function(s)
        if s then
            Notify("Infinite Jump", "Activa el salto infinito. Puede ser detectado por el anti-cheat.")
            -- Implementación básica: forzar salto al tocar el suelo
            task.spawn(function()
                while s do
                    task.wait(0.1)
                    local c = getChar()
                    if c then
                        local h = c:FindFirstChildOfClass("Humanoid")
                        if h and h.FloorMaterial ~= Enum.Material.Air then
                            h:ChangeState(Enum.HumanoidStateType.Jumping)
                        end
                    end
                end
            end)
        end
    end, "🦘")
end)

local TabFarm = NewTab("Farm", "💰", function()
    NewSeparator("RECOLECCIÓN")
    NewToggle("Auto Farm Monedas", function(s)
        coinFarmEnabled = s
        if s then Notify("Coin Farm", "Activado. TP automático a monedas (puede fallar si el server tiene anti-TP).") end
    end, "●")
    NewToggle("Auto Recoger Armas", function(s)
        autoPickEnabled = s
        if s then Notify("Auto Pick", "Activado. TP a armas caídas.") end
    end, "▲")
    NewSeparator("EVENTOS")
    NewToggle("Auto Candy", function(s) candyFarmEnabled = s end, "◆")
    NewToggle("Auto Gift", function(s) giftFarmEnabled = s end, "★")
end)

local TabSettings = NewTab("Settings", "⚙", function()
    NewSeparator("RENDIMIENTO")
    NewToggle("FPS Boost", function(s)
        if s then
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 1e5
            Notify("FPS Boost", "Sombras desactivadas. Puede mejorar el rendimiento.")
        end
    end, "🚀")
    NewToggle("Full Bright", function(s) setFullbright(s) end, "☀")
    NewToggle("Anti AFK", function(s)
        if s then
            Notify("Anti AFK", "Anti-AFK siempre activo. Simula clic cuando estás inactivo.")
        end
    end, "🛡")
    NewSeparator("SERVIDOR")
    NewButton("Server Hop", function()
        Notify("Server Hop", "Función no implementada. Requiere un módulo externo de server hop.")
    end, "🌐")
    NewButton("Rejoin", rejoin, "↻")
end)

-- ============ ABRIR/CERRAR ============
local open = false
local function ToggleUI()
    open = not open
    if open then
        Main.Visible = true
        Main.Size = UDim2.new(0, 500, 0, 340)
        Main.Position = UDim2.new(0.5, -250, 0.5, -170)
        TweenService:Create(Main, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 560, 0, 380),
            Position = UDim2.new(0.5, -280, 0.5, -190),
        }):Play()
        if Config.Blur then SetBlur(true) end
    else
        local t = TweenService:Create(Main, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 480, 0, 320),
            Position = UDim2.new(0.5, -240, 0.5, -160),
        })
        t.Completed:Connect(function() Main.Visible = false end)
        t:Play()
        SetBlur(false)
    end
end

Close.MouseButton1Click:Connect(function() if open then ToggleUI() end end)
MinBtn.MouseButton1Click:Connect(function() if open then ToggleUI() end end)
UIS.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Config.Keybind then ToggleUI() end
end)

local dragging, dragStart, startPos
TitleBar.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true; dragStart = i.Position; startPos = Main.Position
    end
end)
UIS.InputChanged:Connect(function(i)
    if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
        local d = i.Position - dragStart
        Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                   startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)
UIS.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)

SelectTab(TabMain)
ToggleUI()
print("[Wxnnxrx] RightShift para abrir/cerrar. Basado en Overdrive H.")