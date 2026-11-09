--[[
    Wxnnxrx Hub 2.2 - MM2
    Original Luau client-side hub with mobile-friendly UI.

    Included:
      - Player ESP with role labels, highlights and distance
      - Coin and dropped-gun locator
      - Fly, Noclip, WalkSpeed, JumpPower and Infinite Jump
      - FullBright, Fog control and camera FOV
      - Teleport to a named player / Murderer / Sheriff
      - Experimental coin collection and dropped-gun approach
      - Sheriff target assist / auto shoot and murderer knife automation
      - Role alerts, rejoin, UI hide/show and cleanup

    Notes:
      - This is a client-side script. MM2 server validation controls rewards,
        weapon pickup, combat, wins and other server-authoritative actions.
      - Executor compatibility varies. Delta Android has not been runtime-tested.
      - No anti-detection, credential collection or obfuscation. Combat hooks only
        redirect aim data for recognized weapon calls when executor hooks exist.
]]

--// Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

--// Avoid duplicate GUIs
local GUI_NAME = "WxnnxrxHub22"
local oldGui
pcall(function()
    oldGui = (gethui and gethui() or CoreGui):FindFirstChild(GUI_NAME)
end)
if oldGui then
    pcall(function() oldGui:Destroy() end)
end

--// Runtime state
local running = true
local currentCharacter = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local currentHumanoid = currentCharacter:FindFirstChildOfClass("Humanoid")
local currentRoot = currentCharacter:FindFirstChild("HumanoidRootPart")

local State = {
    PlayerESP = false,
    ESP_Murderer = true,
    ESP_Sheriff = true,
    ESP_Innocent = true,
    ESP_Distance = true,
    CoinESP = false,
    GunESP = false,
    Fly = false,
    Noclip = false,
    InfiniteJump = false,
    FullBright = false,
    RemoveFog = false,
    AutoFarm = false,
    AutoGrabGun = false,
    RoleAlerts = true,
    NearMurdererAlert = true,
    AutoFarmCandy = false,
    SpinBot = false,
    BunnyHop = false,
    Spectate = false,
    DayMode = false,
    AntiAFK = false,
    SilentAim = false,
    KnifeSilentAim = false,
    AutoShoot = false,
    FastShoot = false,
    KillAura = false,
    KillAll = false,
    ShootMurderer = false,
}

local ESPObjects = {}
local CoinObjects = {}
local GunObjects = {}
local savedCollisions = {}
local flyVelocity, flyGyro
local originalSpeed, originalJump, originalFOV
local originalLighting = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    GlobalShadows = Lighting.GlobalShadows,
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    FogEnd = Lighting.FogEnd,
    FogStart = Lighting.FogStart,
}
local shutdown
local lastRole = "UNKNOWN"
local lastNearAlert = 0
local alertDistance = 35

--// Small helpers
local function safeDestroy(obj)
    if obj then pcall(function() obj:Destroy() end) end
end

local function make(className, parent, properties)
    local object = Instance.new(className)
    for property, value in pairs(properties or {}) do
        pcall(function() object[property] = value end)
    end
    object.Parent = parent
    return object
end

local function round(object, radius)
    make("UICorner", object, {CornerRadius = UDim.new(0, radius or 8)})
end

local function stroke(object, color, thickness, transparency)
    make("UIStroke", object, {
        Color = color or Color3.fromRGB(70, 75, 95),
        Thickness = thickness or 1,
        Transparency = transparency or 0.2,
    })
end

local function notify(title, message)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title,
            Text = message,
            Duration = 3,
        })
    end)
end

local function getCharacter(player)
    return player and player.Character
end

local function getRoot(player)
    local character = getCharacter(player)
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid(player)
    local character = getCharacter(player)
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function toolHasMarker(tool, keyword)
    if not tool or not tool:IsA("Tool") then return false end
    local lowerName = string.lower(tool.Name)
    if string.find(lowerName, keyword, 1, true) then return true end
    for _, descendant in ipairs(tool:GetDescendants()) do
        local childName = string.lower(descendant.Name)
        if keyword == "knife" and (string.find(childName, "knife", 1, true)
            or childName == "slashstart" or childName == "flingknife") then
            return true
        end
        if keyword == "gun" and (string.find(childName, "gunserver", 1, true)
            or childName == "shootgun" or childName == "shootstart") then
            return true
        end
    end
    return false
end

local function findTool(player, keyword)
    if not player then return nil end
    local character = player.Character
    local backpack = player:FindFirstChildOfClass("Backpack")
    if character then
        for _, child in ipairs(character:GetChildren()) do
            if child:IsA("Tool") and toolHasMarker(child, keyword) then return child end
        end
    end
    if backpack then
        for _, child in ipairs(backpack:GetChildren()) do
            if child:IsA("Tool") and toolHasMarker(child, keyword) then return child end
        end
    end
    return nil
end

local function getRole(player)
    if findTool(player, "knife") then return "MURDERER" end
    if findTool(player, "gun") then return "SHERIFF" end
    if player == LocalPlayer and not currentCharacter then return "UNKNOWN" end
    return "INNOCENT"
end

local function roleColor(role)
    if role == "MURDERER" then return Color3.fromRGB(255, 75, 80) end
    if role == "SHERIFF" then return Color3.fromRGB(75, 155, 255) end
    if role == "INNOCENT" then return Color3.fromRGB(85, 220, 135) end
    return Color3.fromRGB(220, 220, 230)
end

local function getMapCoinContainer()
    local direct = workspace:FindFirstChild("CoinContainer", true)
    if direct then return direct end
    return nil
end

local function getCandyContainer()
    return workspace:FindFirstChild("CandyContainer", true) or workspace:FindFirstChild("Candy", true)
end

local function findDroppedGun()
    local candidates = {"GunDrop", "Gun_Drop", "DroppedGun", "GunDropPart"}
    for _, name in ipairs(candidates) do
        local found = workspace:FindFirstChild(name, true)
        if found then return found end
    end
    return nil
end

local function getObjectPosition(object)
    if not object then return nil end
    if object:IsA("BasePart") then return object.Position end
    if object:IsA("Model") then
        local ok, pivot = pcall(function() return object:GetPivot() end)
        if ok then return pivot.Position end
    end
    return nil
end

local function getObjectAdornee(object)
    if not object then return nil end
    if object:IsA("BasePart") then return object end
    if object:IsA("Model") then
        return object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart", true)
    end
    return nil
end

--// Build GUI parent
local guiParent = PlayerGui
pcall(function()
    if gethui then
        guiParent = gethui()
    else
        guiParent = CoreGui
    end
end)

local ScreenGui = make("ScreenGui", guiParent, {
    Name = GUI_NAME,
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = true,
})

local accent = Color3.fromRGB(150, 100, 255)
local dark = Color3.fromRGB(18, 19, 27)
local panel = Color3.fromRGB(26, 28, 39)
local panel2 = Color3.fromRGB(34, 36, 50)
local textColor = Color3.fromRGB(240, 241, 250)
local muted = Color3.fromRGB(160, 165, 185)

local Main = make("Frame", ScreenGui, {
    Name = "Main",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.52),
    Size = UDim2.fromOffset(560, 390),
    BackgroundColor3 = dark,
    BorderSizePixel = 0,
})
round(Main, 12)
stroke(Main, Color3.fromRGB(75, 65, 115), 1.2, 0.1)

local Header = make("Frame", Main, {
    Name = "Header",
    Size = UDim2.new(1, 0, 0, 48),
    BackgroundColor3 = Color3.fromRGB(31, 27, 47),
    BorderSizePixel = 0,
})
round(Header, 12)

make("Frame", Header, {
    Position = UDim2.new(0, 0, 1, -12),
    Size = UDim2.new(1, 0, 0, 12),
    BackgroundColor3 = Color3.fromRGB(31, 27, 47),
    BorderSizePixel = 0,
})

make("TextLabel", Header, {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(14, 0),
    Size = UDim2.new(1, -130, 1, 0),
    Font = Enum.Font.GothamBold,
    Text = "WXNNXRX  HUB  2.0  •  MM2",
    TextColor3 = textColor,
    TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left,
})

local MinButton = make("TextButton", Header, {
    Position = UDim2.new(1, -78, 0, 9),
    Size = UDim2.fromOffset(28, 28),
    BackgroundColor3 = panel2,
    Text = "—",
    TextColor3 = textColor,
    Font = Enum.Font.GothamBold,
    TextSize = 17,
    AutoButtonColor = true,
})
round(MinButton, 7)

local CloseButton = make("TextButton", Header, {
    Position = UDim2.new(1, -42, 0, 9),
    Size = UDim2.fromOffset(28, 28),
    BackgroundColor3 = Color3.fromRGB(145, 55, 75),
    Text = "×",
    TextColor3 = textColor,
    Font = Enum.Font.GothamBold,
    TextSize = 20,
    AutoButtonColor = true,
})
round(CloseButton, 7)

local Sidebar = make("Frame", Main, {
    Position = UDim2.fromOffset(10, 58),
    Size = UDim2.new(0, 118, 1, -68),
    BackgroundColor3 = panel,
    BorderSizePixel = 0,
})
round(Sidebar, 9)

local SideLayout = make("UIListLayout", Sidebar, {
    Padding = UDim.new(0, 5),
    SortOrder = Enum.SortOrder.LayoutOrder,
})
make("UIPadding", Sidebar, {
    PaddingTop = UDim.new(0, 8),
    PaddingLeft = UDim.new(0, 7),
    PaddingRight = UDim.new(0, 7),
})

local ContentHost = make("Frame", Main, {
    Position = UDim2.fromOffset(138, 58),
    Size = UDim2.new(1, -148, 1, -68),
    BackgroundColor3 = panel,
    BorderSizePixel = 0,
})
round(ContentHost, 9)

local pages = {}
local tabButtons = {}
local activePage

local function createPage(name)
    local page = make("ScrollingFrame", ContentHost, {
        Name = name,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = accent,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Visible = false,
    })
    make("UIPadding", page, {
        PaddingTop = UDim.new(0, 12),
        PaddingBottom = UDim.new(0, 12),
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),
    })
    local layout = make("UIListLayout", page, {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        page.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 24)
    end)
    pages[name] = page

    local button = make("TextButton", Sidebar, {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = panel2,
        Text = name,
        TextColor3 = muted,
        Font = Enum.Font.GothamSemibold,
        TextSize = 12,
        AutoButtonColor = true,
    })
    round(button, 7)
    tabButtons[name] = button
    button.MouseButton1Click:Connect(function()
        for pageName, frame in pairs(pages) do
            frame.Visible = pageName == name
            tabButtons[pageName].BackgroundColor3 = pageName == name and Color3.fromRGB(72, 55, 110) or panel2
            tabButtons[pageName].TextColor3 = pageName == name and textColor or muted
        end
        activePage = page
    end)
    if not activePage then
        activePage = page
        page.Visible = true
        button.BackgroundColor3 = Color3.fromRGB(72, 55, 110)
        button.TextColor3 = textColor
    end
    return page
end

local function addSection(page, title)
    return make("TextLabel", page, {
        Size = UDim2.new(1, -2, 0, 25),
        BackgroundTransparency = 1,
        Text = string.upper(title),
        TextColor3 = accent,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
end

local function addLabel(page, value, height)
    local label = make("TextLabel", page, {
        Size = UDim2.new(1, -2, 0, height or 38),
        BackgroundColor3 = panel2,
        Text = value,
        TextColor3 = muted,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    round(label, 7)
    make("UIPadding", label, {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 8)})
    return label
end

local function addButton(page, title, callback)
    local button = make("TextButton", page, {
        Size = UDim2.new(1, -2, 0, 38),
        BackgroundColor3 = panel2,
        Text = title,
        TextColor3 = textColor,
        Font = Enum.Font.GothamSemibold,
        TextSize = 12,
        AutoButtonColor = true,
    })
    round(button, 7)
    button.MouseButton1Click:Connect(function()
        local ok, err = pcall(callback)
        if not ok then warn("[Wxnnxrx] " .. tostring(err)); notify("Wxnnxrx", "Ocurrió un error en esa acción.") end
    end)
    return button
end

local function addToggle(page, title, stateKey, callback)
    local button = make("TextButton", page, {
        Size = UDim2.new(1, -2, 0, 40),
        BackgroundColor3 = panel2,
        Text = "",
        AutoButtonColor = true,
    })
    round(button, 7)
    make("TextLabel", button, {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(1, -68, 1, 0),
        Text = title,
        TextColor3 = textColor,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    local indicator = make("Frame", button, {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(38, 20),
        BackgroundColor3 = State[stateKey] and accent or Color3.fromRGB(70, 72, 85),
    })
    round(indicator, 10)
    local knob = make("Frame", indicator, {
        Position = State[stateKey] and UDim2.new(1, -17, 0, 3) or UDim2.fromOffset(3, 3),
        Size = UDim2.fromOffset(14, 14),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
    })
    round(knob, 8)

    local function refresh()
        indicator.BackgroundColor3 = State[stateKey] and accent or Color3.fromRGB(70, 72, 85)
        knob.Position = State[stateKey] and UDim2.new(1, -17, 0, 3) or UDim2.fromOffset(3, 3)
    end
    button.MouseButton1Click:Connect(function()
        State[stateKey] = not State[stateKey]
        refresh()
        if callback then
            local ok, err = pcall(callback, State[stateKey])
            if not ok then warn("[Wxnnxrx] " .. tostring(err)) end
        end
    end)
    return button
end

local function addInput(page, title, placeholder, defaultText)
    local holder = make("Frame", page, {
        Size = UDim2.new(1, -2, 0, 61),
        BackgroundColor3 = panel2,
        BorderSizePixel = 0,
    })
    round(holder, 7)
    make("TextLabel", holder, {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(10, 3),
        Size = UDim2.new(1, -20, 0, 21),
        Text = title,
        TextColor3 = muted,
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    local box = make("TextBox", holder, {
        Position = UDim2.fromOffset(8, 27),
        Size = UDim2.new(1, -16, 0, 27),
        BackgroundColor3 = dark,
        Text = defaultText or "",
        PlaceholderText = placeholder or "Escribe aquí...",
        PlaceholderColor3 = muted,
        TextColor3 = textColor,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        ClearTextOnFocus = false,
    })
    round(box, 6)
    return box
end

--// Pages
local HomePage = createPage("Inicio")
local ESPPage = createPage("ESP")
local PlayerPage = createPage("Jugador")
local FarmPage = createPage("Farm")
local CombatPage = createPage("Alertas")
local TeleportPage = createPage("Teleport")
local VisualPage = createPage("Visuales")
local SettingsPage = createPage("Ajustes")
local CombatPlusPage = createPage("Combate+")
local TrollingPage = createPage("Troleo")
local ExtraPage = createPage("Extras")

--// Home
addSection(HomePage, "Bienvenido")
addLabel(HomePage, "Wxnnxrx Hub 2.2\nMM2 • Panel ampliado estilo Overdrive • Móvil", 53)
local roleLabel = addLabel(HomePage, "Tu rol: comprobando...", 34)
local statusLabel = addLabel(HomePage, "Estado: listo", 32)
addSection(HomePage, "Información")
addLabel(HomePage, "Las funciones locales se ejecutan en tu cliente. Monedas, armas, daño y victorias dependen de la validación del servidor MM2.", 58)
addButton(HomePage, "Actualizar mi rol", function()
    roleLabel.Text = "Tu rol: " .. getRole(LocalPlayer)
end)
addButton(HomePage, "Ocultar / mostrar interfaz (RightControl)", function()
    Main.Visible = not Main.Visible
end)

--// ESP
addSection(ESPPage, "Jugadores")
addToggle(ESPPage, "Activar Player ESP", "PlayerESP")
addToggle(ESPPage, "Mostrar Murderer", "ESP_Murderer")
addToggle(ESPPage, "Mostrar Sheriff", "ESP_Sheriff")
addToggle(ESPPage, "Mostrar Innocent", "ESP_Innocent")
addToggle(ESPPage, "Mostrar distancia", "ESP_Distance")
addSection(ESPPage, "Objetos")
addToggle(ESPPage, "Coin ESP", "CoinESP")
addToggle(ESPPage, "Dropped Gun ESP", "GunESP")
addLabel(ESPPage, "ESP basado en Highlight y BillboardGui. Los roles se reconocen cuando el cliente puede ver la herramienta Knife o Gun.", 48)

--// Player
addSection(PlayerPage, "Movimiento")
addToggle(PlayerPage, "Fly", "Fly", function(enabled)
    if enabled then
        if not currentRoot then State.Fly = false; notify("Fly", "No se encontró tu personaje."); return end
        safeDestroy(flyVelocity)
        safeDestroy(flyGyro)
        flyVelocity = make("BodyVelocity", currentRoot, {
            Name = "WxnnxrxFlyVelocity",
            MaxForce = Vector3.new(100000, 100000, 100000),
            Velocity = Vector3.zero,
            P = 25000,
        })
        flyGyro = make("BodyGyro", currentRoot, {
            Name = "WxnnxrxFlyGyro",
            MaxTorque = Vector3.new(100000, 100000, 100000),
            P = 25000,
            CFrame = Camera.CFrame,
        })
        notify("Fly", "Activado. Usa el joystick y el botón de salto.")
    else
        safeDestroy(flyVelocity); flyVelocity = nil
        safeDestroy(flyGyro); flyGyro = nil
        notify("Fly", "Desactivado.")
    end
end)
addToggle(PlayerPage, "Noclip", "Noclip", function(enabled)
    if not enabled then
        for part, canCollide in pairs(savedCollisions) do
            if part and part.Parent then pcall(function() part.CanCollide = canCollide end) end
        end
        table.clear(savedCollisions)
    end
end)
addToggle(PlayerPage, "Infinite Jump", "InfiniteJump")
local speedBox = addInput(PlayerPage, "WalkSpeed (16–100)", "Ejemplo: 28", "28")
addButton(PlayerPage, "Aplicar WalkSpeed", function()
    local value = math.clamp(tonumber(speedBox.Text) or 16, 16, 100)
    if currentHumanoid then currentHumanoid.WalkSpeed = value end
    notify("Jugador", "WalkSpeed aplicado: " .. value)
end)
local jumpBox = addInput(PlayerPage, "JumpPower (50–150)", "Ejemplo: 65", "65")
addButton(PlayerPage, "Aplicar JumpPower", function()
    local value = math.clamp(tonumber(jumpBox.Text) or 50, 50, 150)
    if currentHumanoid then
        pcall(function() currentHumanoid.UseJumpPower = true end)
        currentHumanoid.JumpPower = value
    end
    notify("Jugador", "JumpPower aplicado: " .. value)
end)
addButton(PlayerPage, "Restaurar movimiento", function()
    if currentHumanoid then
        currentHumanoid.WalkSpeed = originalSpeed or 16
        pcall(function() currentHumanoid.JumpPower = originalJump or 50 end)
    end
    State.Fly = false
    State.Noclip = false
    safeDestroy(flyVelocity); flyVelocity = nil
    safeDestroy(flyGyro); flyGyro = nil
    for part, canCollide in pairs(savedCollisions) do
        if part and part.Parent then pcall(function() part.CanCollide = canCollide end) end
    end
    table.clear(savedCollisions)
    notify("Jugador", "Movimiento restaurado.")
end)

--// Farm
addSection(FarmPage, "Recolección")
addToggle(FarmPage, "Auto Farm Coins (experimental)", "AutoFarm", function(enabled)
    if enabled then
        notify("Auto Farm", "Experimental: el servidor decide si recoge las monedas.")
    end
end)
addToggle(FarmPage, "Ir hacia Dropped Gun (experimental)", "AutoGrabGun", function(enabled)
    if enabled then notify("Gun", "Se intentará acercar al arma caída si aparece.") end
end)
addLabel(FarmPage, "El auto-farm mueve tu personaje hacia las monedas visibles. Puede fallar por validaciones, distancia o cambios de mapa.", 54)

--// Alerts
addSection(CombatPage, "Detección de roles")
addToggle(CombatPage, "Notificar cuando cambia mi rol", "RoleAlerts")
addToggle(CombatPage, "Avisar si Murderer está cerca", "NearMurdererAlert")
addLabel(CombatPage, "Esta pestaña detecta roles y proximidad. Las pruebas de combate están en Combate+.", 52)

--// Teleport
addSection(TeleportPage, "Teletransporte local")
local targetBox = addInput(TeleportPage, "Nombre del jugador", "Escribe parte del nombre...", "")
local function teleportToPlayer(target)
    local targetRoot = target and getRoot(target)
    if not targetRoot or not currentRoot then notify("Teleport", "No se encontró el jugador o tu personaje."); return end
    currentRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 3)
end
addButton(TeleportPage, "Teleport al jugador escrito", function()
    local query = string.lower(targetBox.Text)
    if query == "" then notify("Teleport", "Escribe un nombre primero."); return end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and string.find(string.lower(player.Name), query, 1, true) then
            teleportToPlayer(player)
            notify("Teleport", "Destino: " .. player.Name)
            return
        end
    end
    notify("Teleport", "No se encontró ese jugador.")
end)
addButton(TeleportPage, "Teleport al Murderer", function()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and getRole(player) == "MURDERER" then
            teleportToPlayer(player); return
        end
    end
    notify("Teleport", "No se detectó al Murderer.")
end)
addButton(TeleportPage, "Teleport al Sheriff", function()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and getRole(player) == "SHERIFF" then
            teleportToPlayer(player); return
        end
    end
    notify("Teleport", "No se detectó al Sheriff.")
end)
addButton(TeleportPage, "Teleport al arma caída", function()
    local gun = findDroppedGun()
    local pos = getObjectPosition(gun)
    if pos and currentRoot then currentRoot.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
    else notify("Teleport", "No se encontró un arma caída.") end
end)

--// Visuals
addSection(VisualPage, "Iluminación")
addToggle(VisualPage, "FullBright", "FullBright", function(enabled)
    if enabled then
        Lighting.Brightness = 3
        Lighting.ClockTime = 14
        Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.fromRGB(190, 190, 190)
        Lighting.OutdoorAmbient = Color3.fromRGB(190, 190, 190)
    else
        if originalLighting then
            for property, value in pairs(originalLighting) do pcall(function() Lighting[property] = value end) end
        end
    end
end)
addToggle(VisualPage, "Remove Fog", "RemoveFog", function(enabled)
    if enabled then
        Lighting.FogStart = 0
        Lighting.FogEnd = 100000
    elseif originalLighting then
        if originalLighting.FogEnd then Lighting.FogEnd = originalLighting.FogEnd end
        if originalLighting.FogStart then Lighting.FogStart = originalLighting.FogStart end
    end
end)
local fovBox = addInput(VisualPage, "Camera FOV (50–120)", "Ejemplo: 85", "85")
addButton(VisualPage, "Aplicar FOV", function()
    local value = math.clamp(tonumber(fovBox.Text) or 70, 50, 120)
    if Camera then Camera.FieldOfView = value end
    notify("Visuales", "FOV aplicado: " .. value)
end)
addButton(VisualPage, "Restaurar iluminación y FOV", function()
    if originalLighting then
        for property, value in pairs(originalLighting) do pcall(function() Lighting[property] = value end) end
    end
    if Camera then Camera.FieldOfView = originalFOV or 70 end
    State.FullBright = false
    State.RemoveFog = false
    notify("Visuales", "Valores originales restaurados cuando estaban disponibles.")
end)

--// Expanded combat controls. Implementations are installed below.
addSection(CombatPlusPage, "Combate • experimental")
addLabel(CombatPlusPage, "Son intentos reales desde el cliente: apuntado por objetivo, activación del arma/cuchillo y hooks opcionales del executor. MM2 puede rechazar impactos, alcance o cadencia.", 66)
addToggle(CombatPlusPage, "Silent Aim • Sheriff", "SilentAim")
addToggle(CombatPlusPage, "Knife Silent Aim • Murderer", "KnifeSilentAim")
addToggle(CombatPlusPage, "Auto Shoot • apunta al Murderer", "AutoShoot")
addToggle(CombatPlusPage, "Fast Shoot • auto-disparo rápido", "FastShoot")
addToggle(CombatPlusPage, "Kill Aura • cuchillo cercano", "KillAura")
addToggle(CombatPlusPage, "Kill All • intenta recorrer jugadores", "KillAll", function(enabled)
    if enabled then
        notify("Kill All", "Intento activado. Debes ser Murderer; el servidor puede bloquearlo.")
    end
end)
addToggle(CombatPlusPage, "Shoot Murderer • Sheriff", "ShootMurderer")
addLabel(CombatPlusPage, "Consejo: prueba primero Silent Aim y Auto Shoot como Sheriff; Kill Aura / Kill All solo intentan activar tu cuchillo como Murderer. No hay garantía de que Delta admita los hooks.", 68)

addSection(TrollingPage, "Espectador y movimiento")
local spectateBox = addInput(TrollingPage, "Jugador para espectar", "Nombre o parte del nombre", "")
local spectatingPlayer = nil
addButton(TrollingPage, "Espectar jugador", function()
    local query = string.lower(spectateBox.Text)
    if query == "" then notify("Spectate", "Escribe un nombre."); return end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and string.find(string.lower(player.Name), query, 1, true) then
            local humanoid = getHumanoid(player)
            if humanoid and Camera then
                spectatingPlayer = player
                Camera.CameraSubject = humanoid
                State.Spectate = true
                notify("Spectate", "Ahora observas a " .. player.Name)
                return
            end
        end
    end
    notify("Spectate", "No se encontró un jugador válido.")
end)
addButton(TrollingPage, "Dejar de espectar", function()
    spectatingPlayer = nil
    State.Spectate = false
    if Camera and currentHumanoid then Camera.CameraSubject = currentHumanoid end
    notify("Spectate", "Cámara restaurada.")
end)
addToggle(TrollingPage, "Spin Bot visual (local)", "SpinBot")
addLabel(TrollingPage, "Fling a otros jugadores y Fake Dead dependen de física replicada y validación del servidor; no se anuncian como funciones garantizadas.", 58)

addSection(ExtraPage, "Farm y utilidades")
addToggle(ExtraPage, "Auto Farm Candy (experimental)", "AutoFarmCandy", function(enabled) notify("Candy Farm", enabled and "Buscando caramelos visibles." or "Desactivado.") end)
addToggle(ExtraPage, "Bunny Hop", "BunnyHop")
addToggle(ExtraPage, "Anti-AFK", "AntiAFK", function(enabled) if enabled then notify("Anti-AFK", "Activado durante esta sesión.") end end)
addToggle(ExtraPage, "Day Mode (iluminación local)", "DayMode", function(enabled)
    if enabled then Lighting.ClockTime = 14; Lighting.Brightness = 2
    else Lighting.ClockTime = originalLighting.ClockTime; Lighting.Brightness = originalLighting.Brightness end
end)
addButton(ExtraPage, "Tercera persona", function()
    LocalPlayer.CameraMode = Enum.CameraMode.Classic
    LocalPlayer.CameraMinZoomDistance = 8
    LocalPlayer.CameraMaxZoomDistance = 18
    notify("Cámara", "Distancia de tercera persona ajustada.")
end)
addButton(ExtraPage, "Restaurar cámara", function()
    LocalPlayer.CameraMinZoomDistance = 0.5
    LocalPlayer.CameraMaxZoomDistance = 128
    if Camera and currentHumanoid then Camera.CameraSubject = currentHumanoid end
    spectatingPlayer = nil
    State.Spectate = false
end)
addLabel(ExtraPage, "Auto Win, God Mode real, munición infinita, Fake Role y skins del inventario no se pueden conceder desde el cliente: esos datos pertenecen al servidor.", 64)

--// Settings
addSection(SettingsPage, "Interfaz")
addButton(SettingsPage, "Ocultar / mostrar (RightControl)", function() Main.Visible = not Main.Visible end)
addButton(SettingsPage, "Rejoin servidor", function()
    notify("Rejoin", "Solicitando reconexión...")
    pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
end)
addButton(SettingsPage, "Cerrar Wxnnxrx Hub", function()
    if shutdown then shutdown() end
end)
addLabel(SettingsPage, "Wxnnxrx Hub 2.2 • LuaU • Panel ampliado", 32)

--// Responsive sizing
local function resizeUI()
    local viewport = Camera and Camera.ViewportSize or Vector2.new(900, 600)
    local width = math.clamp(viewport.X - 24, 300, 560)
    local height = math.clamp(viewport.Y - 90, 280, 390)
    Main.Size = UDim2.fromOffset(width, height)
    if width < 390 then
        Sidebar.Size = UDim2.new(0, 94, 1, -68)
        ContentHost.Position = UDim2.fromOffset(108, 58)
        ContentHost.Size = UDim2.new(1, -118, 1, -68)
        for _, button in pairs(tabButtons) do button.TextSize = 10 end
    else
        Sidebar.Size = UDim2.new(0, 118, 1, -68)
        ContentHost.Position = UDim2.fromOffset(138, 58)
        ContentHost.Size = UDim2.new(1, -148, 1, -68)
        for _, button in pairs(tabButtons) do button.TextSize = 12 end
    end
end
resizeUI()
if Camera then
    Camera:GetPropertyChangedSignal("ViewportSize"):Connect(resizeUI)
end

--// Drag support (mouse + touch)
do
    local dragging = false
    local dragStart, startPosition, dragInput
    Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = Main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    Header.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            Main.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X,
                startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
        end
    end)
end

MinButton.MouseButton1Click:Connect(function()
    local minimized = Sidebar.Visible
    Sidebar.Visible = not minimized
    ContentHost.Visible = not minimized
    Main.Size = minimized and UDim2.fromOffset(250, 48) or UDim2.fromOffset(math.clamp((Camera and Camera.ViewportSize.X or 560) - 24, 300, 560), math.clamp((Camera and Camera.ViewportSize.Y or 480) - 90, 280, 390))
    MinButton.Text = minimized and "+" or "—"
end)
CloseButton.MouseButton1Click:Connect(function()
    if shutdown then shutdown() end
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.RightControl then
        Main.Visible = not Main.Visible
    end
end)

--// Infinite jump
UserInputService.JumpRequest:Connect(function()
    if State.InfiniteJump and currentHumanoid then
        pcall(function() currentHumanoid:ChangeState(Enum.HumanoidStateType.Jumping) end)
    end
end)

--// Character refresh
LocalPlayer.CharacterAdded:Connect(function(character)
    currentCharacter = character
    currentHumanoid = character:WaitForChild("Humanoid", 10)
    currentRoot = character:WaitForChild("HumanoidRootPart", 10)
    if currentHumanoid then
        originalSpeed = currentHumanoid.WalkSpeed
        pcall(function() originalJump = currentHumanoid.JumpPower end)
    end
    safeDestroy(flyVelocity); flyVelocity = nil
    safeDestroy(flyGyro); flyGyro = nil
    if State.Fly and currentRoot then
        flyVelocity = make("BodyVelocity", currentRoot, {Name = "WxnnxrxFlyVelocity", MaxForce = Vector3.new(100000,100000,100000), Velocity = Vector3.zero, P = 25000})
        flyGyro = make("BodyGyro", currentRoot, {Name = "WxnnxrxFlyGyro", MaxTorque = Vector3.new(100000,100000,100000), P = 25000, CFrame = Camera.CFrame})
    end
end)

--// Save initial values
if currentHumanoid then
    originalSpeed = currentHumanoid.WalkSpeed
    pcall(function() originalJump = currentHumanoid.JumpPower end)
end
if Camera then originalFOV = Camera.FieldOfView end

--// ESP cleanup helpers
local function clearPlayerESP(player)
    local bundle = ESPObjects[player]
    if bundle then
        safeDestroy(bundle.highlight)
        safeDestroy(bundle.billboard)
        ESPObjects[player] = nil
    end
end

local function updatePlayerESP(player)
    if player == LocalPlayer then return end
    if not State.PlayerESP then clearPlayerESP(player); return end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local head = character and character:FindFirstChild("Head")
    if not character or not root or not head then clearPlayerESP(player); return end

    local role = getRole(player)
    local allowed = (role == "MURDERER" and State.ESP_Murderer)
        or (role == "SHERIFF" and State.ESP_Sheriff)
        or (role == "INNOCENT" and State.ESP_Innocent)
    if not allowed then clearPlayerESP(player); return end

    local bundle = ESPObjects[player]
    if not bundle or bundle.character ~= character then
        clearPlayerESP(player)
        local highlight = make("Highlight", character, {
            Name = "WxnnxrxPlayerESP",
            Adornee = character,
            FillColor = roleColor(role),
            OutlineColor = roleColor(role),
            FillTransparency = 0.78,
            OutlineTransparency = 0.05,
            DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
        })
        local billboard = make("BillboardGui", character, {
            Name = "WxnnxrxRoleESP",
            Adornee = head,
            AlwaysOnTop = true,
            Size = UDim2.fromOffset(180, 34),
            StudsOffset = Vector3.new(0, 2.5, 0),
        })
        local label = make("TextLabel", billboard, {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            TextColor3 = roleColor(role),
            TextStrokeTransparency = 0.25,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            Text = player.Name .. " • " .. role,
        })
        bundle = {highlight = highlight, billboard = billboard, label = label, character = character}
        ESPObjects[player] = bundle
    end

    local color = roleColor(role)
    bundle.highlight.FillColor = color
    bundle.highlight.OutlineColor = color
    local distanceText = ""
    if State.ESP_Distance and currentRoot then
        distanceText = " • " .. tostring(math.floor((root.Position - currentRoot.Position).Magnitude)) .. "m"
    end
    bundle.label.Text = player.Name .. " • " .. role .. distanceText
    bundle.label.TextColor3 = color
end

local function clearObjectESP(storage)
    for object, gui in pairs(storage) do
        safeDestroy(gui)
        storage[object] = nil
    end
end

--// Combat helpers: all actions are best-effort client interactions.
local CombatFOV = 850
local CombatMeleeRange = 17
local CombatPrediction = 0.12
local lastGunAction = 0
local lastKnifeAction = 0
local nextKillAllAt = 0
local killAllBusy = false
local CombatMouse = nil
pcall(function() CombatMouse = LocalPlayer:GetMouse() end)

local function isAliveTarget(player)
    if not player or player == LocalPlayer then return false end
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    return character ~= nil and humanoid ~= nil and humanoid.Health > 0 and root ~= nil
end

local function getAimPart(player)
    local character = player and player.Character
    if not character then return nil end
    return character:FindFirstChild("Head")
        or character:FindFirstChild("UpperTorso")
        or character:FindFirstChild("HumanoidRootPart")
end

local function getPredictedPosition(player)
    local part = getAimPart(player)
    if not part then return nil end
    local root = getRoot(player)
    local velocity = root and root.AssemblyLinearVelocity or Vector3.zero
    return part.Position + velocity * CombatPrediction
end

local function getClosestCombatTarget(roleFilter, requireOnScreen)
    if not Camera then Camera = workspace.CurrentCamera end
    if not Camera then return nil end
    local center = Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y * 0.5)
    local bestPlayer, bestDistance = nil, CombatFOV
    for _, player in ipairs(Players:GetPlayers()) do
        if isAliveTarget(player) and (not roleFilter or getRole(player) == roleFilter) then
            local part = getAimPart(player)
            if part then
                local screen, onScreen = Camera:WorldToViewportPoint(part.Position)
                if onScreen or not requireOnScreen then
                    local distance = (Vector2.new(screen.X, screen.Y) - center).Magnitude
                    if distance < bestDistance then
                        bestDistance = distance
                        bestPlayer = player
                    end
                end
            end
        end
    end
    return bestPlayer, bestDistance
end

local function getClosestPlayerByWorldDistance(maxRange)
    local bestPlayer, bestDistance = nil, maxRange or math.huge
    if not currentRoot then return nil end
    for _, player in ipairs(Players:GetPlayers()) do
        if isAliveTarget(player) then
            local root = getRoot(player)
            if root then
                local distance = (root.Position - currentRoot.Position).Magnitude
                if distance < bestDistance then
                    bestPlayer, bestDistance = player, distance
                end
            end
        end
    end
    return bestPlayer, bestDistance
end

local function equipCombatTool(keyword)
    local tool = findTool(LocalPlayer, keyword)
    if not tool then return nil end
    if tool.Parent ~= currentCharacter and currentHumanoid then
        pcall(function() currentHumanoid:EquipTool(tool) end)
        task.wait(0.05)
    end
    return tool
end

local function tryKnifeOnTarget(target, allowTeleport)
    if getRole(LocalPlayer) ~= "MURDERER" or not isAliveTarget(target) then return false end
    local character = target.Character
    local targetRoot = getRoot(target)
    local myRoot = currentRoot
    if not (character and targetRoot and myRoot and myRoot.Parent) then return false end
    if character:FindFirstChildOfClass("ForceField") then return false end

    local knife = equipCombatTool("knife")
    if not knife then return false end

    local distance = (targetRoot.Position - myRoot.Position).Magnitude
    if allowTeleport and distance > 10 then
        pcall(function()
            myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 2.4)
        end)
        task.wait(0.06)
        distance = (targetRoot.Position - myRoot.Position).Magnitude
    end
    if distance > CombatMeleeRange then return false end

    local handle = knife:FindFirstChild("Handle") or knife:FindFirstChildWhichIsA("BasePart", true)
    local fired = false
    pcall(function()
        knife:Activate()
        fired = true
    end)
    if handle and typeof(firetouchinterest) == "function" then
        pcall(function()
            firetouchinterest(targetRoot, handle, 0)
            firetouchinterest(targetRoot, handle, 1)
            fired = true
        end)
    end

    -- Compatibility fallback for MM2 builds exposing the older knife Events folder.
    local events = knife:FindFirstChild("Events")
    local stabRemote = events and events:FindFirstChild("KnifeStabbed")
    local touchRemote = events and events:FindFirstChild("HandleTouched")
    if stabRemote and stabRemote:IsA("RemoteEvent") then
        pcall(function()
            stabRemote:FireServer()
            if touchRemote and touchRemote:IsA("RemoteEvent") then
                touchRemote:FireServer(targetRoot)
            end
            fired = true
        end)
    end
    return fired
end

local function tryShootTarget(target)
    if getRole(LocalPlayer) ~= "SHERIFF" or not isAliveTarget(target) then return false end
    local gun = equipCombatTool("gun")
    if not gun then return false end
    local now = os.clock()
    local delay = State.FastShoot and 0.12 or 0.28
    if now - lastGunAction < delay then return false end
    lastGunAction = now
    local fired = false
    pcall(function()
        gun:Activate()
        fired = true
    end)
    return fired
end

-- Optional executor hooks: redirect only the game's own aim reads / combat calls.
local CombatHooksInstalled = false
local function installCombatHooks()
    if CombatHooksInstalled then return end
    if type(hookmetamethod) ~= "function" or type(newcclosure) ~= "function" then
        return
    end
    CombatHooksInstalled = true

    pcall(function()
        local oldIndex
        oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
            if self == CombatMouse and key == "Hit" then
                if State.SilentAim and getRole(LocalPlayer) == "SHERIFF" then
                    local target = getClosestCombatTarget("MURDERER", true)
                    local position = target and getPredictedPosition(target)
                    if position then return CFrame.new(position) end
                elseif State.KnifeSilentAim and getRole(LocalPlayer) == "MURDERER" then
                    local target = getClosestCombatTarget(nil, true)
                    local position = target and getPredictedPosition(target)
                    if position then return CFrame.new(position) end
                end
            elseif self == CombatMouse and key == "Target" then
                if State.SilentAim and getRole(LocalPlayer) == "SHERIFF" then
                    local target = getClosestCombatTarget("MURDERER", true)
                    local part = target and getAimPart(target)
                    if part then return part end
                elseif State.KnifeSilentAim and getRole(LocalPlayer) == "MURDERER" then
                    local target = getClosestCombatTarget(nil, true)
                    local part = target and getAimPart(target)
                    if part then return part end
                end
            end
            return oldIndex(self, key)
        end))
    end)

    pcall(function()
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local method = ""
            pcall(function() method = getnamecallmethod() end)
            local args = table.pack(...)
            local isInternalCall = false
            if type(checkcaller) == "function" then
                pcall(function() isInternalCall = checkcaller() end)
            end
            if not isInternalCall and typeof(self) == "Instance" then
                local remoteName = string.lower(self.Name)
                local aimPosition = nil
                if State.SilentAim and getRole(LocalPlayer) == "SHERIFF"
                    and (method == "InvokeServer" or method == "FireServer")
                    and (remoteName == "shootgun" or remoteName == "shootstart" or remoteName == "shoot") then
                    local target = getClosestCombatTarget("MURDERER", true)
                    aimPosition = target and getPredictedPosition(target)
                    if aimPosition then
                        if remoteName == "shootgun" and typeof(args[2]) == "Vector3" then
                            args[2] = aimPosition
                        elseif remoteName == "shootgun" and typeof(args[2]) == "CFrame" then
                            args[2] = CFrame.new(aimPosition)
                        else
                            for index = args.n, 1, -1 do
                                if typeof(args[index]) == "Vector3" then
                                    args[index] = aimPosition
                                    break
                                elseif typeof(args[index]) == "CFrame" then
                                    args[index] = CFrame.new(aimPosition)
                                    break
                                end
                            end
                        end
                    end
                elseif State.KnifeSilentAim and getRole(LocalPlayer) == "MURDERER"
                    and (method == "InvokeServer" or method == "FireServer")
                    and (string.find(remoteName, "throw", 1, true)
                        or string.find(remoteName, "flingknife", 1, true)) then
                    local target = getClosestCombatTarget(nil, true)
                    aimPosition = target and getPredictedPosition(target)
                    if aimPosition then
                        for index = 1, args.n do
                            if typeof(args[index]) == "Vector3" then
                                args[index] = aimPosition
                                break
                            elseif typeof(args[index]) == "CFrame" then
                                args[index] = CFrame.new(aimPosition)
                                break
                            end
                        end
                    end
                end
            end
            return oldNamecall(self, table.unpack(args, 1, args.n))
        end))
    end)
end

installCombatHooks()

local function runCombatAutomation()
    local now = os.clock()
    if State.KillAll and not killAllBusy and now >= nextKillAllAt then
        if getRole(LocalPlayer) ~= "MURDERER" then
            nextKillAllAt = now + 1.5
        else
            killAllBusy = true
            nextKillAllAt = now + 1.1
            task.spawn(function()
                local returnCFrame = currentRoot and currentRoot.CFrame
                for _, target in ipairs(Players:GetPlayers()) do
                    if not running or not State.KillAll then break end
                    if target ~= LocalPlayer and isAliveTarget(target) then
                        tryKnifeOnTarget(target, true)
                        task.wait(0.18)
                    end
                end
                if currentRoot and currentRoot.Parent and returnCFrame then
                    pcall(function() currentRoot.CFrame = returnCFrame end)
                end
                killAllBusy = false
            end)
        end
    end

    if State.KillAura and getRole(LocalPlayer) == "MURDERER" and now - lastKnifeAction >= 0.22 then
        local target = getClosestPlayerByWorldDistance(CombatMeleeRange)
        if target then
            local myRoot = currentRoot
            local targetRoot = getRoot(target)
            if myRoot and targetRoot and (targetRoot.Position - myRoot.Position).Magnitude <= CombatMeleeRange then
                lastKnifeAction = now
                tryKnifeOnTarget(target, false)
            end
        end
    end

    if (State.AutoShoot or State.FastShoot or State.ShootMurderer) and getRole(LocalPlayer) == "SHERIFF" then
        local target = getClosestCombatTarget("MURDERER", true)
        if target then tryShootTarget(target) end
    end
end

shutdown = function()
    if not running then return end
    running = false
    State.Fly = false
    State.Noclip = false
    State.AutoFarm = false
    State.AutoGrabGun = false
    State.AutoFarmCandy = false
    State.SpinBot = false
    State.BunnyHop = false
    State.Spectate = false
    State.AntiAFK = false
    State.DayMode = false
    State.SilentAim = false
    State.KnifeSilentAim = false
    State.AutoShoot = false
    State.FastShoot = false
    State.KillAura = false
    State.KillAll = false
    State.ShootMurderer = false
    safeDestroy(flyVelocity); flyVelocity = nil
    safeDestroy(flyGyro); flyGyro = nil
    for part, canCollide in pairs(savedCollisions) do
        if part and part.Parent then pcall(function() part.CanCollide = canCollide end) end
    end
    table.clear(savedCollisions)
    if currentHumanoid then
        pcall(function() currentHumanoid.WalkSpeed = originalSpeed or 16 end)
        pcall(function() currentHumanoid.JumpPower = originalJump or 50 end)
    end
    for _, bundle in pairs(ESPObjects) do
        safeDestroy(bundle.highlight)
        safeDestroy(bundle.billboard)
    end
    table.clear(ESPObjects)
    clearObjectESP(CoinObjects)
    clearObjectESP(GunObjects)
    for property, value in pairs(originalLighting) do
        pcall(function() Lighting[property] = value end)
    end
    if Camera then pcall(function() Camera.FieldOfView = originalFOV or 70 end) end
    safeDestroy(ScreenGui)
end

local function updateObjectESP(object, storage, name, color)
    local adornee = getObjectAdornee(object)
    if not adornee then
        safeDestroy(storage[object]); storage[object] = nil
        return
    end
    if not storage[object] then
        local billboard = make("BillboardGui", ScreenGui, {
            Name = name,
            Adornee = adornee,
            AlwaysOnTop = true,
            Size = UDim2.fromOffset(110, 25),
        })
        make("TextLabel", billboard, {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Text = name,
            TextColor3 = color,
            TextStrokeTransparency = 0.2,
            Font = Enum.Font.GothamBold,
            TextSize = 11,
        })
        storage[object] = billboard
    else
        storage[object].Adornee = adornee
    end
end

--// Main update loop: ESP, movement and alerts
task.spawn(function()
    local lastESPUpdate = 0
    local lastStatusUpdate = 0
    while running do
        local delta = RunService.Heartbeat:Wait()
        if currentCharacter and currentCharacter.Parent then
            currentHumanoid = currentCharacter:FindFirstChildOfClass("Humanoid")
            currentRoot = currentCharacter:FindFirstChild("HumanoidRootPart")
        end

        if State.Fly and currentRoot and currentHumanoid and flyVelocity and flyGyro then
            local move = currentHumanoid.MoveDirection * 55
            local vertical = 0
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) or currentHumanoid.Jump then vertical = 42 end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then vertical = -42 end
            flyVelocity.Velocity = Vector3.new(move.X, vertical, move.Z)
            if Camera then flyGyro.CFrame = Camera.CFrame end
        end

        if State.Noclip and currentCharacter then
            for _, part in ipairs(currentCharacter:GetDescendants()) do
                if part:IsA("BasePart") then
                    if savedCollisions[part] == nil then savedCollisions[part] = part.CanCollide end
                    part.CanCollide = false
                end
            end
        end

        runCombatAutomation()

        if os.clock() - lastESPUpdate >= 0.35 then
            lastESPUpdate = os.clock()
            for _, player in ipairs(Players:GetPlayers()) do
                updatePlayerESP(player)
            end

            if State.CoinESP then
                local container = getMapCoinContainer()
                local seen = {}
                if container then
                    for _, object in ipairs(container:GetDescendants()) do
                        if object:IsA("BasePart") then
                            seen[object] = true
                            updateObjectESP(object, CoinObjects, "COIN", Color3.fromRGB(255, 210, 70))
                        end
                    end
                end
                for object, billboard in pairs(CoinObjects) do
                    if not seen[object] then safeDestroy(billboard); CoinObjects[object] = nil end
                end
            else
                clearObjectESP(CoinObjects)
            end

            if State.GunESP then
                local gun = findDroppedGun()
                if gun then updateObjectESP(gun, GunObjects, "DROPPED GUN", Color3.fromRGB(90, 170, 255))
                else clearObjectESP(GunObjects) end
            else
                clearObjectESP(GunObjects)
            end
        end

        local role = getRole(LocalPlayer)
        if State.RoleAlerts and role ~= lastRole then
            if lastRole ~= "UNKNOWN" then notify("Cambio de rol", "Tu rol ahora es " .. role) end
            lastRole = role
        end

        if State.NearMurdererAlert and currentRoot and os.clock() - lastNearAlert > 4 then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and getRole(player) == "MURDERER" then
                    local root = getRoot(player)
                    if root and (root.Position - currentRoot.Position).Magnitude <= alertDistance then
                        lastNearAlert = os.clock()
                        notify("¡Murderer cerca!", player.Name .. " está cerca de ti.")
                        break
                    end
                end
            end
        end

        if os.clock() - lastStatusUpdate > 1.5 then
            lastStatusUpdate = os.clock()
            if roleLabel and roleLabel.Parent then roleLabel.Text = "Tu rol: " .. role end
            if statusLabel and statusLabel.Parent then statusLabel.Text = "Estado: " .. (State.AutoFarm and "Auto Farm activo" or "listo") end
        end
    end
end)

--// Experimental coin farm loop
task.spawn(function()
    while running do
        if State.AutoFarm and currentRoot then
            local container = getMapCoinContainer()
            if container then
                local coins = {}
                for _, object in ipairs(container:GetDescendants()) do
                    if object:IsA("BasePart") and object.Transparency < 1 then
                        table.insert(coins, object)
                    end
                end
                for _, coin in ipairs(coins) do
                    if not running or not State.AutoFarm then break end
                    if coin and coin.Parent and currentRoot and currentRoot.Parent then
                        currentRoot.CFrame = coin.CFrame * CFrame.new(0, 2, 0)
                        task.wait(0.28)
                    end
                end
            end
        end
        task.wait(0.35)
    end
end)

--// Experimental dropped-gun approach loop
task.spawn(function()
    while running do
        if State.AutoGrabGun and currentRoot then
            local gun = findDroppedGun()
            local pos = getObjectPosition(gun)
            if pos then
                currentRoot.CFrame = CFrame.new(pos + Vector3.new(0, 2.5, 0))
                task.wait(1.2)
            end
        end
        task.wait(0.35)
    end
end)

--// Experimental candy farm loop
 task.spawn(function()
    while running do
        if State.AutoFarmCandy and currentRoot then
            local container = getCandyContainer()
            if container then
                for _, candy in ipairs(container:GetDescendants()) do
                    if not running or not State.AutoFarmCandy then break end
                    if candy:IsA("BasePart") and candy.Transparency < 1 and currentRoot and currentRoot.Parent then
                        currentRoot.CFrame = candy.CFrame * CFrame.new(0, 2, 0)
                        task.wait(0.25)
                    end
                end
            end
        end
        task.wait(0.4)
    end
end)

--// Local spin and bunny-hop effects
local lastHop = 0
RunService.Heartbeat:Connect(function()
    if not running then return end
    if State.SpinBot and currentRoot then currentRoot.CFrame = currentRoot.CFrame * CFrame.Angles(0, math.rad(18), 0) end
    if State.BunnyHop and currentHumanoid and currentHumanoid.FloorMaterial ~= Enum.Material.Air and os.clock() - lastHop > 0.18 then
        lastHop = os.clock()
        currentHumanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

--// Anti-AFK
pcall(function()
    LocalPlayer.Idled:Connect(function()
        if State.AntiAFK and running then
            local VirtualUser = game:GetService("VirtualUser")
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    clearPlayerESP(player)
end)

notify("Wxnnxrx Hub 2.2", "Cargado. Panel ampliado listo.")
print("[Wxnnxrx Hub 2.2] Loaded successfully.")
