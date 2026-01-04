if _G.AiScript_Cleanup then
    _G.AiScript_Cleanup()
end

local BrainURL_RU = "https://raw.githubusercontent.com/zyphralex/AI-Script-RB/refs/heads/main/brain_RU.json"
local BrainURL_EN = "https://raw.githubusercontent.com/zyphralex/AI-Script-RB/refs/heads/main/brain_EN.json" 

local ConfigFile = "quwy_ai_config.json"

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local HttpService = game:GetService("HttpService")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local RootPart = Character:WaitForChild("HumanoidRootPart")

local Config = {
    Name = "quwy",
    GlobalRange = 1200,
    StuckThreshold = 2.5,
    JumpCheckDist = 4,
    Language = "RU",
    ShowGreetingHint = false
}

local CurrentBrainURL = BrainURL_RU

local function SaveSettings()
    if writefile then
        pcall(function()
            writefile(ConfigFile, HttpService:JSONEncode(Config))
        end)
    end
end

local function LoadSettings()
    if isfile and isfile(ConfigFile) then
        local s, r = pcall(function() return readfile(ConfigFile) end)
        if s then
            local s2, d = pcall(function() return HttpService:JSONDecode(r) end)
            if s2 and d then
                if d.Name then Config.Name = d.Name end
                if d.GlobalRange then Config.GlobalRange = d.GlobalRange end
                if d.Language then Config.Language = d.Language end
                if d.ShowGreetingHint ~= nil then Config.ShowGreetingHint = d.ShowGreetingHint end
            end
        end
    end
    
    if Config.Language == "EN" then
        CurrentBrainURL = BrainURL_EN
    else
        CurrentBrainURL = BrainURL_RU
    end
end
LoadSettings()

local State = {
    Enabled = false,
    Mode = "Wander",
    Target = nil,
    WingmanTarget = nil,
    IsMoving = false,
    CurrentStatus = "Idle"
}

local BrainData = {}
local Connections = {}
local LastHintTime = 0
local LastChatTime = 0
local CharacterSize = {Radius = 2, Height = 5}

local BackupBrain = {
    greeting={triggers={"hello", "hi", "привет", "хай"}, responses={"..."}},
    system_phrases={
        wingman_start={"..."}, wingman_greetings={"Hi"}, target_search_start={"..."},
        target_found={"!"}, target_lost={"?"}, player_not_found={"?"}, stop_confirm={"."}
    }
}

local UIText = {
    RU = {
        control = "Управление",
        commands = "Команды",
        settings = "Настройки",
        info = "Инфо",
        activate = "Включить ИИ",
        activated = "ИИ: ОНЛАЙН",
        reload = "Обновить БД",
        hint = "Подсказка",
        hintOn = "Подсказка: ВКЛ",
        status = "Статус",
        offline = "Оффлайн",
        online = "Онлайн",
        mode = "Режим",
        target = "Цель",
        none = "Нет",
        botName = "Имя бота:",
        wanderRange = "Радиус:",
        language = "Язык чата:",
        findFriend = "Найти друга",
        followMe = "Иди за мной",
        stop = "Стоп",
        dance = "Танцуй",
        jump = "Прыгай",
        sit = "Сядь",
        standUp = "Встань",
        spin = "Крутись",
        findPlayer = "Найти игрока",
        enterName = "Введите ник...",
        search = "Искать"
    },
    EN = {
        control = "Control",
        commands = "Commands",
        settings = "Settings",
        info = "Info",
        activate = "Activate AI",
        activated = "AI: ONLINE",
        reload = "Reload Brain DB",
        hint = "Greeting Hint",
        hintOn = "Hint: ON",
        status = "Status",
        offline = "Offline",
        online = "Online",
        mode = "Mode",
        target = "Target",
        none = "None",
        botName = "Bot Name:",
        wanderRange = "Wander Range:",
        language = "Chat Language:",
        findFriend = "Find Friend",
        followMe = "Follow Me",
        stop = "Stop",
        dance = "Dance",
        jump = "Jump",
        sit = "Sit",
        standUp = "Stand Up",
        spin = "Spin",
        findPlayer = "Find Player",
        enterName = "Enter nickname...",
        search = "Search"
    }
}

local function GetText(key)
    local lang = Config.Language == "EN" and "EN" or "RU"
    return UIText[lang][key] or UIText["EN"][key] or key
end

local Theme = {
    Background = Color3.fromRGB(15, 15, 20),
    Element = Color3.fromRGB(25, 25, 30),
    Accent = Color3.fromRGB(140, 80, 255),
    Text = Color3.fromRGB(245, 245, 245),
    SubText = Color3.fromRGB(140, 140, 140),
    Red = Color3.fromRGB(255, 70, 70),
    Green = Color3.fromRGB(70, 255, 120),
    Yellow = Color3.fromRGB(255, 200, 50)
}

if CoreGui:FindFirstChild("QUWY_AI_UI") then
    CoreGui.QUWY_AI_UI:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "QUWY_AI_UI"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.ResetOnSpawn = false

local NotifContainer = Instance.new("Frame")
NotifContainer.Parent = ScreenGui
NotifContainer.BackgroundTransparency = 1
NotifContainer.Position = UDim2.new(0.5, -100, 0.05, 0)
NotifContainer.Size = UDim2.new(0, 200, 0, 40)
NotifContainer.ZIndex = 500

local function Notify(text)
    local F = Instance.new("Frame")
    F.Parent = NotifContainer
    F.BackgroundColor3 = Theme.Element
    F.Size = UDim2.new(0, 0, 0, 30)
    F.Position = UDim2.new(0.5, 0, 0, 0)
    F.AnchorPoint = Vector2.new(0.5, 0)
    F.BorderSizePixel = 0
    Instance.new("UICorner", F).CornerRadius = UDim.new(0, 6)
    local S = Instance.new("UIStroke", F); S.Color = Theme.Accent; S.Thickness = 1
    local L = Instance.new("TextLabel", F)
    L.BackgroundTransparency = 1; L.Size = UDim2.new(1, 0, 1, 0); L.Font = Enum.Font.GothamMedium
    L.Text = text; L.TextColor3 = Theme.Text; L.TextSize = 12; L.TextTransparency = 1
    TweenService:Create(F, TweenInfo.new(0.3), {Size = UDim2.new(0, 180, 0, 30)}):Play()
    task.wait(0.1)
    TweenService:Create(L, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
    task.wait(2)
    TweenService:Create(L, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
    local out = TweenService:Create(F, TweenInfo.new(0.3), {Size = UDim2.new(0, 0, 0, 30)})
    out:Play()
    out.Completed:Wait()
    F:Destroy()
end

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Parent = ScreenGui
Main.BackgroundColor3 = Theme.Background
Main.Position = UDim2.new(0.5, -260, 0.5, -180)
Main.Size = UDim2.new(0, 520, 0, 360)
Main.BorderSizePixel = 0
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 8)
local MainStroke = Instance.new("UIStroke", Main); MainStroke.Color = Theme.Element; MainStroke.Thickness = 1

local TopBar = Instance.new("Frame")
TopBar.Parent = Main; TopBar.BackgroundTransparency = 1; TopBar.Size = UDim2.new(1, 0, 0, 40)

local Title = Instance.new("TextLabel")
Title.Parent = TopBar; Title.BackgroundTransparency = 1; Title.Position = UDim2.new(0, 15, 0, 0); Title.Size = UDim2.new(0, 100, 1, 0)
Title.Font = Enum.Font.GothamBold; Title.Text = "QUWY AI"; Title.TextColor3 = Theme.Text; Title.TextSize = 16; Title.TextXAlignment = Enum.TextXAlignment.Left

local BetaLabel = Instance.new("TextLabel")
BetaLabel.Parent = TopBar; BetaLabel.BackgroundTransparency = 1; BetaLabel.Position = UDim2.new(0, 95, 0, 0); BetaLabel.Size = UDim2.new(0, 100, 1, 0)
BetaLabel.Font = Enum.Font.GothamBold; BetaLabel.Text = "PUBLIC BETA"; BetaLabel.TextColor3 = Theme.Yellow; BetaLabel.TextSize = 10; BetaLabel.TextXAlignment = Enum.TextXAlignment.Left

local CloseBtn = Instance.new("TextButton")
CloseBtn.Parent = TopBar; CloseBtn.BackgroundTransparency = 1; CloseBtn.Position = UDim2.new(1, -30, 0, 0); CloseBtn.Size = UDim2.new(0, 30, 1, 0)
CloseBtn.Font = Enum.Font.GothamMedium; CloseBtn.Text = "×"; CloseBtn.TextColor3 = Theme.SubText; CloseBtn.TextSize = 20

local MinBtn = Instance.new("TextButton")
MinBtn.Parent = TopBar; MinBtn.BackgroundTransparency = 1; MinBtn.Position = UDim2.new(1, -60, 0, 0); MinBtn.Size = UDim2.new(0, 30, 1, 0)
MinBtn.Font = Enum.Font.GothamMedium; MinBtn.Text = "−"; MinBtn.TextColor3 = Theme.SubText; MinBtn.TextSize = 20

local Sidebar = Instance.new("Frame")
Sidebar.Parent = Main; Sidebar.BackgroundTransparency = 1; Sidebar.Position = UDim2.new(0, 0, 0, 40); Sidebar.Size = UDim2.new(0, 120, 1, -40)
local SideList = Instance.new("UIListLayout", Sidebar); SideList.HorizontalAlignment = Enum.HorizontalAlignment.Center; SideList.SortOrder = Enum.SortOrder.LayoutOrder; SideList.Padding = UDim.new(0, 5)
local SidePad = Instance.new("UIPadding", Sidebar); SidePad.PaddingTop = UDim.new(0, 15)

local PageContainer = Instance.new("Frame")
PageContainer.Parent = Main; PageContainer.BackgroundTransparency = 1; PageContainer.Position = UDim2.new(0, 120, 0, 40); PageContainer.Size = UDim2.new(1, -120, 1, -40)

local TabButtons = {}
local Pages = {}

local function CreateTabBtn(text, key)
    local B = Instance.new("TextButton"); B.Parent = Sidebar; B.BackgroundColor3 = Theme.Background; B.Size = UDim2.new(0, 100, 0, 30)
    B.Font = Enum.Font.GothamMedium; B.Text = text; B.TextColor3 = Theme.SubText; B.TextSize = 13; B.Name = key
    Instance.new("UICorner", B).CornerRadius = UDim.new(0, 4)
    TabButtons[key] = B
    return B
end

local Tab1 = CreateTabBtn(GetText("control"), "control")
local Tab2 = CreateTabBtn(GetText("commands"), "commands")
local Tab3 = CreateTabBtn(GetText("settings"), "settings")
local Tab4 = CreateTabBtn(GetText("info"), "info")

local Page1 = Instance.new("Frame", PageContainer); Page1.Size = UDim2.new(1,0,1,0); Page1.BackgroundTransparency = 1; Page1.Name = "control"
local Page2 = Instance.new("Frame", PageContainer); Page2.Size = UDim2.new(1,0,1,0); Page2.BackgroundTransparency = 1; Page2.Visible = false; Page2.Name = "commands"
local Page3 = Instance.new("Frame", PageContainer); Page3.Size = UDim2.new(1,0,1,0); Page3.BackgroundTransparency = 1; Page3.Visible = false; Page3.Name = "settings"
local Page4 = Instance.new("Frame", PageContainer); Page4.Size = UDim2.new(1,0,1,0); Page4.BackgroundTransparency = 1; Page4.Visible = false; Page4.Name = "info"

Pages = {control = Page1, commands = Page2, settings = Page3, info = Page4}

local function SwitchTab(btn, page)
    for _, t in pairs(TabButtons) do t.TextColor3 = Theme.SubText; t.BackgroundColor3 = Theme.Background end
    for _, p in pairs(Pages) do p.Visible = false end
    btn.TextColor3 = Theme.Accent; btn.BackgroundColor3 = Theme.Element; page.Visible = true
end
SwitchTab(Tab1, Page1)
Tab1.MouseButton1Click:Connect(function() SwitchTab(Tab1, Page1) end)
Tab2.MouseButton1Click:Connect(function() SwitchTab(Tab2, Page2) end)
Tab3.MouseButton1Click:Connect(function() SwitchTab(Tab3, Page3) end)
Tab4.MouseButton1Click:Connect(function() SwitchTab(Tab4, Page4) end)

local DynamicUIElements = {}

local function CreateToggleButton(text, textOn, parent, x, y, initialState, callback, key)
    local B = Instance.new("TextButton"); B.Parent = parent; B.BackgroundColor3 = Theme.Element; B.Position = UDim2.new(0, x, 0, y); B.Size = UDim2.new(0, 175, 0, 35)
    B.Font = Enum.Font.GothamMedium; B.TextColor3 = Theme.Text; B.TextSize = 12; B.AutoButtonColor = false
    Instance.new("UICorner", B).CornerRadius = UDim.new(0, 4)
    local S = Instance.new("UIStroke", B); S.Color = Theme.Element; S.Thickness = 1; S.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    local Toggled = initialState or false
    
    local function UpdateVisual()
        B.Text = Toggled and textOn or text
        if Toggled then
            B.BackgroundColor3 = Color3.fromRGB(25,25,25)
            S.Color = Theme.Accent
            B.TextColor3 = Theme.Accent
        else
            B.BackgroundColor3 = Theme.Element
            S.Color = Theme.Element
            B.TextColor3 = Theme.Text
        end
    end
    
    UpdateVisual()
    
    B.MouseButton1Click:Connect(function()
        Toggled = not Toggled
        UpdateVisual()
        callback(Toggled, B)
    end)
    
    if key then
        DynamicUIElements[key] = {button = B, textKey = text, textOnKey = textOn, update = UpdateVisual, getToggled = function() return Toggled end}
    end
    
    return B
end

local function CreateClickButton(text, parent, x, y, w, h, callback)
    local B = Instance.new("TextButton"); B.Parent = parent; B.BackgroundColor3 = Theme.Element; B.Position = UDim2.new(0, x, 0, y); B.Size = UDim2.new(0, w or 175, 0, h or 35)
    B.Font = Enum.Font.GothamMedium; B.Text = text; B.TextColor3 = Theme.Text; B.TextSize = 12
    Instance.new("UICorner", B).CornerRadius = UDim.new(0, 4)
    local S = Instance.new("UIStroke", B); S.Color = Theme.Element; S.Thickness = 1
    B.MouseButton1Click:Connect(function()
        TweenService:Create(B, TweenInfo.new(0.1), {BackgroundColor3 = Theme.Accent}):Play()
        task.wait(0.1)
        TweenService:Create(B, TweenInfo.new(0.1), {BackgroundColor3 = Theme.Element}):Play()
        callback()
    end)
    return B
end

local function CreateInput(placeholder, defaultText, parent, x, y, w, callback)
    local F = Instance.new("Frame"); F.Parent = parent; F.BackgroundColor3 = Theme.Element; F.Position = UDim2.new(0, x, 0, y); F.Size = UDim2.new(0, w or 175, 0, 35)
    Instance.new("UICorner", F).CornerRadius = UDim.new(0, 4)
    local TB = Instance.new("TextBox"); TB.Parent = F; TB.BackgroundTransparency = 1; TB.Size = UDim2.new(1, 0, 1, 0)
    TB.Font = Enum.Font.GothamMedium; TB.Text = defaultText; TB.PlaceholderText = placeholder; TB.TextColor3 = Theme.SubText; TB.TextSize = 12
    TB.FocusLost:Connect(function(enterPressed)
        if enterPressed or TB.Text ~= "" then
            callback(TB.Text)
            TB.TextColor3 = Theme.Accent
        end
    end)
    return TB, F
end

local function CalculateCharacterSize()
    if not Character then return end
    local hrp = Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local minBound, maxBound = Character:GetBoundingBox()
    local size = maxBound - minBound
    
    CharacterSize.Radius = math.max(size.X, size.Z) / 2 + 0.5
    CharacterSize.Height = size.Y + 1
end

local function LoadBrain()
    local success, result = pcall(function() return game:HttpGet(CurrentBrainURL) end)
    if success then
        local decodeSuccess, decoded = pcall(function() return HttpService:JSONDecode(result) end)
        if decodeSuccess then 
            BrainData = decoded
            Notify("Brain Loaded (".. Config.Language ..")")
        else
            Notify("Brain Decode Error")
            BrainData = BackupBrain
        end
    else
        Notify("Brain Load Error. Using Backup.")
        BrainData = BackupBrain
    end
end
task.spawn(LoadBrain)

local function GetSysPhrase(key)
    if BrainData and BrainData.system_phrases and BrainData.system_phrases[key] then
        local list = BrainData.system_phrases[key]
        return list[math.random(1, #list)]
    end
    return "..."
end

local function GetCategoryResponse(categoryName)
    if BrainData and BrainData[categoryName] and BrainData[categoryName].responses then
        local list = BrainData[categoryName].responses
        return list[math.random(1, #list)]
    end
    return "..."
end

local ActivateBtnRef
ActivateBtnRef = CreateToggleButton(GetText("activate"), GetText("activated"), Page1, 10, 15, false, function(s, btn)
    State.Enabled = s
    if s then 
        State.Mode = "Wander"
        CalculateCharacterSize()
        if Humanoid then Humanoid:MoveTo(RootPart.Position) end
        Notify("AI Activated")
    else 
        State.Mode = "Idle"
        State.Target = nil
        State.WingmanTarget = nil
        State.IsMoving = false
        if Humanoid then Humanoid:MoveTo(RootPart.Position) end
        Notify("AI Deactivated")
    end
end, "activate")

local ReloadBtnRef = CreateClickButton(GetText("reload"), Page1, 195, 15, 175, 35, function()
    LoadBrain()
end)
DynamicUIElements["reload"] = {button = ReloadBtnRef, textKey = "reload"}

local HintBtnRef = CreateToggleButton(GetText("hint"), GetText("hintOn"), Page1, 10, 60, Config.ShowGreetingHint, function(s, btn)
    Config.ShowGreetingHint = s
    SaveSettings()
    Notify(s and "Hint Enabled" or "Hint Disabled")
end, "hint")

local StatusLbl = Instance.new("TextLabel", Page1)
StatusLbl.BackgroundTransparency = 1; StatusLbl.Position = UDim2.new(0, 10, 0, 110); StatusLbl.Size = UDim2.new(0, 360, 0, 20)
StatusLbl.Font = Enum.Font.GothamBold; StatusLbl.TextColor3 = Theme.Red; StatusLbl.TextSize = 14; StatusLbl.TextXAlignment = Enum.TextXAlignment.Left
StatusLbl.Name = "StatusLbl"

local ModeLbl = Instance.new("TextLabel", Page1)
ModeLbl.BackgroundTransparency = 1; ModeLbl.Position = UDim2.new(0, 10, 0, 135); ModeLbl.Size = UDim2.new(0, 360, 0, 20)
ModeLbl.Font = Enum.Font.Gotham; ModeLbl.TextColor3 = Theme.SubText; ModeLbl.TextSize = 12; ModeLbl.TextXAlignment = Enum.TextXAlignment.Left
ModeLbl.Name = "ModeLbl"

local TargetLbl = Instance.new("TextLabel", Page1)
TargetLbl.BackgroundTransparency = 1; TargetLbl.Position = UDim2.new(0, 10, 0, 155); TargetLbl.Size = UDim2.new(0, 360, 0, 20)
TargetLbl.Font = Enum.Font.Gotham; TargetLbl.TextColor3 = Theme.SubText; TargetLbl.TextSize = 12; TargetLbl.TextXAlignment = Enum.TextXAlignment.Left
TargetLbl.Name = "TargetLbl"

local SizeLbl = Instance.new("TextLabel", Page1)
SizeLbl.BackgroundTransparency = 1; SizeLbl.Position = UDim2.new(0, 10, 0, 175); SizeLbl.Size = UDim2.new(0, 360, 0, 20)
SizeLbl.Font = Enum.Font.Gotham; SizeLbl.TextColor3 = Theme.SubText; SizeLbl.TextSize = 11; SizeLbl.TextXAlignment = Enum.TextXAlignment.Left
SizeLbl.Text = string.format("Character Size: R=%.1f H=%.1f", CharacterSize.Radius, CharacterSize.Height)

local CommandButtons = {}

local function CreateCommandButton(textKey, x, y, callback)
    local B = CreateClickButton(GetText(textKey), Page2, x, y, 115, 40, callback)
    CommandButtons[textKey] = B
    return B
end

CreateCommandButton("findFriend", 10, 15, function()
    if not State.Enabled then Notify("AI is OFF"); return end
    State.Mode = "Wingman"
    State.WingmanTarget = nil
    local response = GetCategoryResponse("wingman_command")
    SendChat(response)
end)

CreateCommandButton("followMe", 135, 15, function()
    if not State.Enabled then Notify("AI is OFF"); return end
    State.Mode = "Follow"
    State.Target = Character
    local response = GetCategoryResponse("follow_command")
    SendChat(response)
    Notify("Following you")
end)

CreateCommandButton("stop", 260, 15, function()
    if not State.Enabled then Notify("AI is OFF"); return end
    State.Mode = "Wander"
    State.Target = nil
    State.WingmanTarget = nil
    local response = GetCategoryResponse("stop_command")
    SendChat(response)
end)

CreateCommandButton("dance", 10, 65, function()
    if not State.Enabled then Notify("AI is OFF"); return end
    if Humanoid then
        task.spawn(function()
            for i = 1, math.random(3, 6) do
                if not State.Enabled then break end
                Humanoid.Jump = true
                task.wait(0.5)
                if RootPart then
                    RootPart.CFrame = RootPart.CFrame * CFrame.Angles(0, math.rad(90), 0)
                end
                task.wait(0.3)
            end
        end)
        local response = GetCategoryResponse("fun_dance")
        SendChat(response)
    end
end)

CreateCommandButton("jump", 135, 65, function()
    if not State.Enabled then Notify("AI is OFF"); return end
    if Humanoid then
        Humanoid.Jump = true
        SendChat("!")
    end
end)

CreateCommandButton("spin", 260, 65, function()
    if not State.Enabled then Notify("AI is OFF"); return end
    if RootPart then
        task.spawn(function()
            for i = 1, 8 do
                if not State.Enabled or not RootPart then break end
                RootPart.CFrame = RootPart.CFrame * CFrame.Angles(0, math.rad(45), 0)
                task.wait(0.1)
            end
        end)
        SendChat("@_@")
    end
end)

CreateCommandButton("sit", 10, 115, function()
    if not State.Enabled then Notify("AI is OFF"); return end
    if Humanoid then
        Humanoid.Sit = true
        local response = GetCategoryResponse("sit_response")
        SendChat(response)
    end
end)

CreateCommandButton("standUp", 135, 115, function()
    if not State.Enabled then Notify("AI is OFF"); return end
    if Humanoid then
        Humanoid.Sit = false
        Humanoid.Jump = true
        local response = GetCategoryResponse("getout_command")
        SendChat(response)
    end
end)

local FindPlayerLabel = Instance.new("TextLabel", Page2)
FindPlayerLabel.BackgroundTransparency = 1; FindPlayerLabel.Position = UDim2.new(0, 10, 0, 170); FindPlayerLabel.Size = UDim2.new(0, 200, 0, 20)
FindPlayerLabel.Font = Enum.Font.GothamBold; FindPlayerLabel.TextColor3 = Theme.SubText; FindPlayerLabel.TextSize = 12; FindPlayerLabel.TextXAlignment = Enum.TextXAlignment.Left
FindPlayerLabel.Name = "FindPlayerLabel"
DynamicUIElements["findPlayerLabel"] = {label = FindPlayerLabel, textKey = "findPlayer"}

local PlayerSearchInput, PlayerSearchFrame = CreateInput(GetText("enterName"), "", Page2, 10, 193, 200, function() end)
DynamicUIElements["searchInput"] = {input = PlayerSearchInput, placeholderKey = "enterName"}

local SearchBtn = CreateClickButton(GetText("search"), Page2, 220, 193, 80, 35, function()
    if not State.Enabled then Notify("AI is OFF"); return end
    local targetName = PlayerSearchInput.Text
    if targetName == "" then return end
    
    local found = nil
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            if string.find(p.Name:lower(), targetName:lower()) or string.find(p.DisplayName:lower(), targetName:lower()) then
                found = p
                break
            end
        end
    end
    
    if found then
        State.Mode = "TargetSearch"
        State.Target = found
        local phrase = GetSysPhrase("target_search_start")
        if string.find(phrase, "%%s") then
            SendChat(string.format(phrase, found.DisplayName))
        else
            SendChat(phrase .. " " .. found.DisplayName)
        end
        Notify("Searching: " .. found.DisplayName)
        PlayerSearchInput.Text = ""
    else
        SendChat(GetSysPhrase("player_not_found"))
        Notify("Player not found")
    end
end)
DynamicUIElements["searchBtn"] = {button = SearchBtn, textKey = "search"}

local NameLabel = Instance.new("TextLabel", Page3)
NameLabel.BackgroundTransparency = 1; NameLabel.Position = UDim2.new(0, 10, 0, 0); NameLabel.Size = UDim2.new(0, 175, 0, 15)
NameLabel.Font = Enum.Font.Gotham; NameLabel.TextColor3 = Theme.SubText; NameLabel.TextSize = 11; NameLabel.TextXAlignment = Enum.TextXAlignment.Left
NameLabel.Name = "NameLabel"
DynamicUIElements["nameLabel"] = {label = NameLabel, textKey = "botName"}

CreateInput("Bot name...", Config.Name, Page3, 10, 18, 175, function(txt)
    if txt ~= "" then
        Config.Name = string.lower(txt)
        SaveSettings()
        Notify("Saved: " .. txt)
    end
end)

local RangeLabel = Instance.new("TextLabel", Page3)
RangeLabel.BackgroundTransparency = 1; RangeLabel.Position = UDim2.new(0, 195, 0, 0); RangeLabel.Size = UDim2.new(0, 175, 0, 15)
RangeLabel.Font = Enum.Font.Gotham; RangeLabel.TextColor3 = Theme.SubText; RangeLabel.TextSize = 11; RangeLabel.TextXAlignment = Enum.TextXAlignment.Left
RangeLabel.Name = "RangeLabel"
DynamicUIElements["rangeLabel"] = {label = RangeLabel, textKey = "wanderRange"}

CreateInput("Range...", tostring(Config.GlobalRange), Page3, 195, 18, 175, function(txt)
    local n = tonumber(txt)
    if n and n > 0 then 
        Config.GlobalRange = n 
        SaveSettings()
        Notify("Saved: " .. txt)
    end
end)

local LangLabel = Instance.new("TextLabel", Page3)
LangLabel.BackgroundTransparency = 1; LangLabel.Position = UDim2.new(0, 10, 0, 65); LangLabel.Size = UDim2.new(0, 200, 0, 20)
LangLabel.Font = Enum.Font.GothamBold; LangLabel.TextColor3 = Theme.SubText; LangLabel.TextSize = 12; LangLabel.TextXAlignment = Enum.TextXAlignment.Left
LangLabel.Name = "LangLabel"
DynamicUIElements["langLabel"] = {label = LangLabel, textKey = "language"}

local BtnRU = Instance.new("TextButton", Page3)
BtnRU.BackgroundColor3 = Theme.Element; BtnRU.Position = UDim2.new(0, 10, 0, 88); BtnRU.Size = UDim2.new(0, 80, 0, 30)
BtnRU.Font = Enum.Font.GothamBold; BtnRU.Text = "RU"; BtnRU.TextColor3 = Theme.Text; BtnRU.TextSize = 12
Instance.new("UICorner", BtnRU).CornerRadius = UDim.new(0, 4)
local StrokeRU = Instance.new("UIStroke", BtnRU); StrokeRU.Color = Theme.Element; StrokeRU.Thickness = 1

local BtnEN = Instance.new("TextButton", Page3)
BtnEN.BackgroundColor3 = Theme.Element; BtnEN.Position = UDim2.new(0, 100, 0, 88); BtnEN.Size = UDim2.new(0, 80, 0, 30)
BtnEN.Font = Enum.Font.GothamBold; BtnEN.Text = "EN"; BtnEN.TextColor3 = Theme.Text; BtnEN.TextSize = 12
Instance.new("UICorner", BtnEN).CornerRadius = UDim.new(0, 4)
local StrokeEN = Instance.new("UIStroke", BtnEN); StrokeEN.Color = Theme.Element; StrokeEN.Thickness = 1

local function UpdateAllUIText()
    for key, btn in pairs(TabButtons) do
        btn.Text = GetText(key)
    end
    
    for key, btn in pairs(CommandButtons) do
        btn.Text = GetText(key)
    end
    
    for key, data in pairs(DynamicUIElements) do
        if data.button and data.textKey then
            if data.textOnKey then
                local isToggled = data.getToggled and data.getToggled()
                data.button.Text = isToggled and GetText(data.textOnKey) or GetText(data.textKey)
            else
                data.button.Text = GetText(data.textKey)
            end
        elseif data.label and data.textKey then
            data.label.Text = GetText(data.textKey)
        elseif data.input and data.placeholderKey then
            data.input.PlaceholderText = GetText(data.placeholderKey)
        end
    end
end

local function UpdateLangButtons()
    if Config.Language == "RU" then
        BtnRU.BackgroundColor3 = Theme.Accent
        StrokeRU.Color = Theme.Accent
        BtnEN.BackgroundColor3 = Theme.Element
        StrokeEN.Color = Theme.Element
    else
        BtnEN.BackgroundColor3 = Theme.Accent
        StrokeEN.Color = Theme.Accent
        BtnRU.BackgroundColor3 = Theme.Element
        StrokeRU.Color = Theme.Element
    end
    UpdateAllUIText()
end
UpdateLangButtons()

local function SetLang(lang)
    Config.Language = lang
    if lang == "EN" then
        CurrentBrainURL = BrainURL_EN
    else
        CurrentBrainURL = BrainURL_RU
    end
    SaveSettings()
    UpdateLangButtons()
    LoadBrain()
end

BtnRU.MouseButton1Click:Connect(function() SetLang("RU") end)
BtnEN.MouseButton1Click:Connect(function() SetLang("EN") end)

local SettingsNote = Instance.new("TextLabel", Page3)
SettingsNote.BackgroundTransparency = 1; SettingsNote.Position = UDim2.new(0, 10, 0, 130); SettingsNote.Size = UDim2.new(1, -20, 0, 150)
SettingsNote.Font = Enum.Font.Gotham; SettingsNote.TextColor3 = Theme.SubText; SettingsNote.TextSize = 11; SettingsNote.TextWrapped = true; SettingsNote.TextXAlignment = Enum.TextXAlignment.Left; SettingsNote.TextYAlignment = Enum.TextYAlignment.Top
SettingsNote.Text = "Settings are saved automatically.\nPress Enter after typing.\n\nBot Name - trigger word in chat\nWander Range - max distance for random walking\n\nAI calculates character size for better pathfinding.\nSupports: walking, swimming, climbing, jumping"

local AboutTitle = Instance.new("TextLabel", Page4)
AboutTitle.BackgroundTransparency = 1; AboutTitle.Size = UDim2.new(1, 0, 0, 50); AboutTitle.Position = UDim2.new(0, 0, 0.02, 0)
AboutTitle.Font = Enum.Font.FredokaOne; AboutTitle.Text = "QUWY AI"; AboutTitle.TextColor3 = Theme.Accent; AboutTitle.TextSize = 42

local BetaLabelInfo = Instance.new("TextLabel", Page4)
BetaLabelInfo.BackgroundTransparency = 1; BetaLabelInfo.Size = UDim2.new(1, 0, 0, 20); BetaLabelInfo.Position = UDim2.new(0, 0, 0.02, 45)
BetaLabelInfo.Font = Enum.Font.GothamBold; BetaLabelInfo.Text = "PUBLIC BETA"; BetaLabelInfo.TextColor3 = Theme.Yellow; BetaLabelInfo.TextSize = 14

local VersionLbl = Instance.new("TextLabel", Page4)
VersionLbl.BackgroundTransparency = 1; VersionLbl.Size = UDim2.new(1, 0, 0, 20); VersionLbl.Position = UDim2.new(0, 0, 0.02, 65)
VersionLbl.Font = Enum.Font.Gotham; VersionLbl.Text = "v3.0 | Universal AI Bot"; VersionLbl.TextColor3 = Theme.SubText; VersionLbl.TextSize = 12

local function CreateLinkBtn(text, url, yPos)
    local Btn = Instance.new("TextButton", Page4)
    Btn.BackgroundColor3 = Theme.Element; Btn.Position = UDim2.new(0.5, -100, 0.45, yPos); Btn.Size = UDim2.new(0, 200, 0, 32)
    Btn.Font = Enum.Font.GothamMedium; Btn.Text = text; Btn.TextColor3 = Theme.Text; Btn.TextSize = 12
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 16)
    local S = Instance.new("UIStroke", Btn); S.Color = Theme.Accent; S.Thickness = 1
    Btn.MouseButton1Click:Connect(function() 
        if setclipboard then 
            setclipboard(url)
            Notify("Link Copied!") 
        else 
            Notify("No Clipboard Support") 
        end 
    end)
    return Btn
end

CreateLinkBtn("Telegram: QLogovo", "https://t.me/QLogovo", -20)
CreateLinkBtn("Discord Server", "https://discord.gg/9wCEUewSbN", 20)
CreateLinkBtn("GitHub Repository", "https://github.com/zyphralex/AI-Script-RB", 60)

local Circle = Instance.new("TextButton")
Circle.Parent = ScreenGui
Circle.BackgroundColor3 = Theme.Background
Circle.Size = UDim2.new(0, 45, 0, 45)
Circle.Position = UDim2.new(0.05, 0, 0.1, 0)
Circle.Text = "Q"
Circle.Font = Enum.Font.GothamBold
Circle.TextColor3 = Theme.Accent
Circle.TextSize = 22
Circle.Visible = false
Circle.AutoButtonColor = true
local CC = Instance.new("UICorner", Circle); CC.CornerRadius = UDim.new(1, 0)
local CS = Instance.new("UIStroke", Circle); CS.Color = Theme.Accent; CS.Thickness = 1.5; CS.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local function EnableUniversalDrag(frame, handle)
    local dragging, dragStart, startPos
    
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)
    
    handle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            local newPos = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            TweenService:Create(frame, TweenInfo.new(0.05), {Position = newPos}):Play()
        end
    end)
end

EnableUniversalDrag(Main, TopBar)
EnableUniversalDrag(Circle, Circle)

local function CleanAndClose()
    State.Enabled = false
    for _, c in pairs(Connections) do 
        pcall(function() c:Disconnect() end) 
    end
    Connections = {}
    ScreenGui:Destroy()
    _G.AiScript_Cleanup = nil
end
_G.AiScript_Cleanup = CleanAndClose

CloseBtn.MouseButton1Click:Connect(CleanAndClose)

MinBtn.MouseButton1Click:Connect(function() 
    Main.Visible = false
    Circle.Visible = true
    Circle.Size = UDim2.new(0,0,0,0)
    TweenService:Create(Circle, TweenInfo.new(0.4, Enum.EasingStyle.Back), {Size = UDim2.new(0,45,0,45)}):Play()
end)

Circle.MouseButton1Click:Connect(function() 
    Circle.Visible = false
    Main.Visible = true
    Main.Size = UDim2.new(0,0,0,0)
    TweenService:Create(Main, TweenInfo.new(0.4, Enum.EasingStyle.Back), {Size = UDim2.new(0, 520, 0, 360)}):Play()
end)

Main.Size = UDim2.new(0,0,0,0)
TweenService:Create(Main, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 520, 0, 360)}):Play()

function SendChat(msg)
    if not msg or msg == "" then return end
    
    local currentTime = tick()
    if currentTime - LastChatTime < 1.5 then
        task.wait(1.5 - (currentTime - LastChatTime))
    end
    LastChatTime = tick()
    
    task.spawn(function()
        task.wait(math.random() * 0.5 + 0.3)
        pcall(function()
            if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
                local channel = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
                if channel then channel:SendAsync(msg) end
            else
                local chatEvents = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
                if chatEvents then
                    local sayMsg = chatEvents:FindFirstChild("SayMessageRequest")
                    if sayMsg then sayMsg:FireServer(msg, "All") end
                end
            end
        end)
    end)
end

local function FindPlayerByName(nameFragment)
    if not nameFragment or nameFragment == "" then return nil end
    nameFragment = nameFragment:lower():gsub("^%s+", ""):gsub("%s+$", "")
    
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local pName = p.Name:lower()
            local pDisplay = p.DisplayName:lower()
            if string.find(pName, nameFragment) or string.find(pDisplay, nameFragment) then
                return p
            end
        end
    end
    return nil
end

local function IsGreetingMessage(message)
    if not BrainData or not BrainData.greeting then return false end
    local cleanMsg = message:lower()
    for _, trigger in pairs(BrainData.greeting.triggers or {}) do
        if string.find(cleanMsg, trigger:lower()) then
            return true
        end
    end
    return false
end

local function HandleChat(player, message)
    if not State.Enabled then return end
    if player == LocalPlayer then return end
    if not message or message == "" then return end
    
    local cleanMsg = message:lower():gsub("[%p%c]", " ")
    
    if not string.find(cleanMsg, Config.Name:lower()) then return end

    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") and RootPart then
        local lookPos = Vector3.new(player.Character.HumanoidRootPart.Position.X, RootPart.Position.Y, player.Character.HumanoidRootPart.Position.Z)
        RootPart.CFrame = CFrame.new(RootPart.Position, lookPos)
    end
    
    if string.find(cleanMsg, "найди") or string.find(cleanMsg, "find") then
        local targetName = string.match(cleanMsg, "найди%s+(.+)") or string.match(cleanMsg, "find%s+(.+)")
        
        if targetName then
            targetName = targetName:gsub("^%s+", ""):gsub("%s+$", "")
            
            if string.find(targetName, "друг") or string.find(targetName, "friend") or string.find(targetName, "парн") or string.find(targetName, "девуш") then
                State.Mode = "Wingman"
                State.WingmanTarget = nil
                SendChat(GetSysPhrase("wingman_start"))
                return
            end

            local found = FindPlayerByName(targetName)
            if found then
                State.Mode = "TargetSearch"
                State.Target = found
                local phrase = GetSysPhrase("target_search_start")
                if string.find(phrase, "%%s") then
                    SendChat(string.format(phrase, found.DisplayName))
                else
                    SendChat(phrase .. " " .. found.DisplayName)
                end
            else
                SendChat(GetSysPhrase("player_not_found"))
            end
        end
        return
    end

    if string.find(cleanMsg, "иди к") or string.find(cleanMsg, "иди ко") or string.find(cleanMsg, "go to") or string.find(cleanMsg, "come to") or string.find(cleanMsg, "come here") or string.find(cleanMsg, "follow") or string.find(cleanMsg, "за мной") or string.find(cleanMsg, "ко мне") or string.find(cleanMsg, "сюда") then
        State.Mode = "Follow"
        State.Target = player.Character
        SendChat(GetCategoryResponse("follow_command"))
        return
    end

    if string.find(cleanMsg, "стоп") or string.find(cleanMsg, "stop") or string.find(cleanMsg, "хватит") or string.find(cleanMsg, "enough") or string.find(cleanMsg, "стой") or string.find(cleanMsg, "wait") or string.find(cleanMsg, "жди") then
        State.Mode = "Wander"
        State.Target = nil
        State.WingmanTarget = nil
        SendChat(GetSysPhrase("stop_confirm"))
        return
    end

    if string.find(cleanMsg, "прыгай") or string.find(cleanMsg, "jump") or string.find(cleanMsg, "прыгни") then
        if Humanoid then
            Humanoid.Jump = true
            SendChat("!")
        end
        return
    end

    if string.find(cleanMsg, "танцуй") or string.find(cleanMsg, "dance") or string.find(cleanMsg, "party") then
        if Humanoid then
            task.spawn(function()
                for i = 1, math.random(3, 6) do
                    if not State.Enabled then break end
                    Humanoid.Jump = true
                    task.wait(0.5)
                    if RootPart then
                        RootPart.CFrame = RootPart.CFrame * CFrame.Angles(0, math.rad(90), 0)
                    end
                    task.wait(0.3)
                end
            end)
            SendChat(GetCategoryResponse("fun_dance"))
        end
        return
    end

    if string.find(cleanMsg, "сядь") or string.find(cleanMsg, "sit") or string.find(cleanMsg, "сиди") or string.find(cleanMsg, "присядь") then
        if Humanoid then
            Humanoid.Sit = true
            SendChat(GetCategoryResponse("sit_response"))
        end
        return
    end

    if string.find(cleanMsg, "встань") or string.find(cleanMsg, "stand") or string.find(cleanMsg, "вставай") or string.find(cleanMsg, "get up") or string.find(cleanMsg, "вылазь") or string.find(cleanMsg, "слезь") then
        if Humanoid and Humanoid.Sit then
            Humanoid.Sit = false
            Humanoid.Jump = true
            SendChat(GetCategoryResponse("getout_command"))
        end
        return
    end

    if string.find(cleanMsg, "крутись") or string.find(cleanMsg, "spin") or string.find(cleanMsg, "покрутись") then
        if RootPart then
            task.spawn(function()
                for i = 1, 8 do
                    if not State.Enabled or not RootPart then break end
                    RootPart.CFrame = RootPart.CFrame * CFrame.Angles(0, math.rad(45), 0)
                    task.wait(0.1)
                end
            end)
            SendChat("@_@")
        end
        return
    end
    
    local foundResponse = false
    for categoryName, categoryData in pairs(BrainData) do
        if categoryName ~= "system_phrases" and type(categoryData) == "table" then
            local triggers = categoryData.triggers
            if triggers and type(triggers) == "table" then
                for _, trigger in pairs(triggers) do
                    if string.find(cleanMsg, trigger:lower()) then
                        local responses = categoryData.responses
                        if responses and #responses > 0 then
                            local reply = responses[math.random(1, #responses)]
                            SendChat(reply)
                        end
                        
                        if categoryName == "greeting" and Config.ShowGreetingHint then
                            local currentTime = tick()
                            if currentTime - LastHintTime > 30 then
                                LastHintTime = currentTime
                                task.spawn(function()
                                    task.wait(2.5)
                                    local hintMsg
                                    if Config.Language == "EN" then
                                        hintMsg = "Write '" .. Config.Name .. "' at the beginning of your message to talk to me."
                                    else
                                        hintMsg = "Пишите '" .. Config.Name .. "' в начале сообщения, чтобы общаться со мной."
                                    end
                                    SendChat(hintMsg)
                                end)
                            end
                        end
                        
                        local action = categoryData.action
                        if action == "follow" then
                            State.Mode = "Follow"
                            State.Target = player.Character
                        elseif action == "stop" then
                            State.Mode = "Wander"
                            State.Target = nil
                            State.WingmanTarget = nil
                        elseif action == "wingman" then
                            State.Mode = "Wingman"
                            State.WingmanTarget = nil
                        elseif action == "getout" then
                            if Humanoid and Humanoid.Sit then 
                                Humanoid.Sit = false
                                Humanoid.Jump = true 
                            end
                        end
                        
                        foundResponse = true
                        break
                    end
                end
            end
        end
        if foundResponse then break end
    end
    
    if not foundResponse then 
        local unknownPhrases = {"?", "hmm?", "...", "what?"}
        SendChat(unknownPhrases[math.random(1, #unknownPhrases)]) 
    end
end

local function ConnectPlayerChat(plr)
    if plr == LocalPlayer then return end
    local conn = plr.Chatted:Connect(function(msg) 
        HandleChat(plr, msg) 
    end)
    table.insert(Connections, conn)
end

table.insert(Connections, Players.PlayerAdded:Connect(function(plr) 
    ConnectPlayerChat(plr) 
end))

for _, plr in pairs(Players:GetPlayers()) do 
    ConnectPlayerChat(plr) 
end

local function UpdateCharacter()
    Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    Humanoid = Character:WaitForChild("Humanoid", 10)
    RootPart = Character:WaitForChild("HumanoidRootPart", 10)
    
    if not Humanoid or not RootPart then return end
    
    CalculateCharacterSize()
    
    local seatedConn = Humanoid.Seated:Connect(function(active)
        if not State.Enabled then return end
        if active then 
            State.IsMoving = false
            State.CurrentStatus = "Seated"
            task.spawn(function()
                while Humanoid and Humanoid.Sit and State.Enabled do
                    local waitTime = math.random(15, 40)
                    task.wait(waitTime)
                    if Humanoid and Humanoid.Sit and State.Enabled then
                        if math.random() > 0.3 then 
                            Humanoid.Sit = false
                            Humanoid.Jump = true
                            if RootPart then
                                local escapeDir = RootPart.CFrame.LookVector * 15
                                RootPart.AssemblyLinearVelocity = escapeDir + Vector3.new(0, 15, 0)
                                Humanoid:MoveTo(RootPart.Position + escapeDir)
                            end
                            task.wait(2)
                            break
                        end
                    end
                end
            end)
        else 
            State.CurrentStatus = "Active" 
        end
    end)
    table.insert(Connections, seatedConn)
end

UpdateCharacter()
table.insert(Connections, LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    UpdateCharacter()
end))

task.spawn(function()
    while task.wait(0.3) do
        if State.Enabled then
            StatusLbl.Text = GetText("status") .. ": " .. GetText("online")
            StatusLbl.TextColor3 = Theme.Green
            ModeLbl.Text = GetText("mode") .. ": " .. State.Mode
            
            local targetName = GetText("none")
            if State.Target and State.Target.Parent then
                if State.Target:IsA("Player") then
                    targetName = State.Target.Name
                elseif State.Target:IsA("Model") and State.Target:FindFirstChild("HumanoidRootPart") then
                    targetName = State.Target.Name
                end
            elseif State.WingmanTarget and State.WingmanTarget.Parent then
                targetName = State.WingmanTarget.Name
            end
            TargetLbl.Text = GetText("target") .. ": " .. targetName
            SizeLbl.Text = string.format("Character Size: R=%.1f H=%.1f", CharacterSize.Radius, CharacterSize.Height)
        else
            StatusLbl.Text = GetText("status") .. ": " .. GetText("offline")
            StatusLbl.TextColor3 = Theme.Red
            ModeLbl.Text = GetText("mode") .. ": Idle"
            TargetLbl.Text = GetText("target") .. ": " .. GetText("none")
        end
    end
end)

local function CanFitThrough(position, direction, distance)
    if not RootPart then return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {Character}
    
    local rightOffset = RootPart.CFrame.RightVector * CharacterSize.Radius
    local upOffset = Vector3.new(0, CharacterSize.Height / 2, 0)
    
    local checkPoints = {
        position,
        position + rightOffset,
        position - rightOffset,
        position + upOffset,
        position - upOffset * 0.5
    }
    
    for _, point in pairs(checkPoints) do
        local ray = workspace:Raycast(point, direction * distance, params)
        if ray then
            return false
        end
    end
    
    return true
end

local function IsPathBlocked(targetPos)
    if not RootPart then return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {Character}
    
    local dir = targetPos - RootPart.Position
    if dir.Magnitude < 1 then return false end
    
    local ray = workspace:Raycast(RootPart.Position, dir.Unit * math.min(dir.Magnitude, 100), params)
    if ray then return true end
    
    return not CanFitThrough(RootPart.Position, dir.Unit, math.min(dir.Magnitude, 10))
end

local function CheckForObstacles()
    if not RootPart or not Humanoid then return end
    local lookVector = RootPart.CFrame.LookVector
    local startPos = RootPart.Position - Vector3.new(0, 1, 0)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {Character}
    
    local frontCheck = Config.JumpCheckDist + CharacterSize.Radius
    local ray = workspace:Raycast(startPos, lookVector * frontCheck, params)
    
    if ray then
        local highRay = workspace:Raycast(startPos + Vector3.new(0, CharacterSize.Height * 0.7, 0), lookVector * frontCheck, params)
        if not highRay then 
            Humanoid.Jump = true 
        else
            local sideCheckDist = CharacterSize.Radius + 2
            local rightRay = workspace:Raycast(startPos, (lookVector + RootPart.CFrame.RightVector).Unit * sideCheckDist, params)
            local leftRay = workspace:Raycast(startPos, (lookVector - RootPart.CFrame.RightVector).Unit * sideCheckDist, params)
            
            if rightRay and not leftRay then
                Humanoid:Move(Vector3.new(-1, 0, 0), true)
            elseif leftRay and not rightRay then
                Humanoid:Move(Vector3.new(1, 0, 0), true)
            else
                Humanoid:Move(Vector3.new(0, 0, -1), true)
                task.wait(0.3)
                local newDir = math.random() > 0.5 and 1 or -1
                Humanoid:Move(Vector3.new(newDir, 0, 0), true)
            end
        end
    end
end

local function UnstuckAction()
    if not Humanoid or not RootPart then return end
    Humanoid:MoveTo(RootPart.Position - RootPart.CFrame.LookVector * (CharacterSize.Radius * 4))
    task.wait(0.5)
    local sideDir = math.random() > 0.5 and 1 or -1
    Humanoid:Move(Vector3.new(sideDir, 0, 0), true) 
    task.wait(0.8)
    Humanoid.Jump = true
end

local function MoveToPoint(destination)
    if not Humanoid or not RootPart then return false end
    if Humanoid.Sit then return false end
    State.IsMoving = true
    
    if not IsPathBlocked(destination) then
        Humanoid:MoveTo(destination)
        
        local timer = 0
        repeat
            task.wait(0.1)
            timer = timer + 0.1
            if not RootPart then State.IsMoving = false; return false end
            if (RootPart.Position - destination).Magnitude < 4 then
                State.IsMoving = false
                return true
            end
        until timer > 8 or (Humanoid and Humanoid.Sit)
    end
    
    local path = PathfindingService:CreatePath({
        AgentRadius = CharacterSize.Radius, 
        AgentHeight = CharacterSize.Height, 
        AgentCanJump = true, 
        AgentCanClimb = true,
        WaypointSpacing = 4,
        Costs = { Water = 1.0, Plastic = 1 }
    })
    
    local success, _ = pcall(function() path:ComputeAsync(RootPart.Position, destination) end)
    
    if success and path.Status == Enum.PathStatus.Success then
        local waypoints = path:GetWaypoints()
        for i, waypoint in pairs(waypoints) do
            if not State.Enabled then State.IsMoving = false; return false end
            if not Humanoid or not RootPart then State.IsMoving = false; return false end
            if Humanoid.Sit then State.IsMoving = false; return false end
            
            if State.Mode == "Follow" and State.Target then
                local targetRoot = State.Target:FindFirstChild("HumanoidRootPart")
                if targetRoot and (targetRoot.Position - destination).Magnitude > 20 then 
                    State.IsMoving = false
                    return false 
                end
            elseif (State.Mode == "Wingman" and State.WingmanTarget) or (State.Mode == "TargetSearch" and State.Target) then
                local t = State.WingmanTarget or State.Target
                if t and t.Character then
                    local tRoot = t.Character:FindFirstChild("HumanoidRootPart")
                    if tRoot and (tRoot.Position - destination).Magnitude > 15 then 
                        State.IsMoving = false
                        return false 
                    end
                end
            end

            if waypoint.Action == Enum.PathWaypointAction.Jump then Humanoid.Jump = true end
            Humanoid:MoveTo(waypoint.Position)
            local moveTimer = 0
            local stuckTimer = 0
            local lastPos = RootPart.Position
            repeat
                local dt = RunService.Heartbeat:Wait()
                moveTimer = moveTimer + dt
                if not Humanoid or not RootPart then State.IsMoving = false; return false end
                
                if Humanoid:GetState() == Enum.HumanoidStateType.Swimming then
                    if waypoint.Position.Y > RootPart.Position.Y + 2 then Humanoid.Jump = true end
                end
                
                if Humanoid:GetState() == Enum.HumanoidStateType.Climbing then
                    Humanoid:Move(Vector3.new(0, 1, 0), false)
                end
                
                CheckForObstacles()
                
                if moveTimer > 0.5 then
                    if (RootPart.Position - lastPos).Magnitude < 0.5 then
                        stuckTimer = stuckTimer + dt
                        if stuckTimer > 1 then Humanoid.Jump = true end
                    else
                        stuckTimer = 0
                        lastPos = RootPart.Position
                    end
                end
                
                if RootPart.Position.Y < -300 then State.IsMoving = false; return false end
            until (RootPart.Position - waypoint.Position).Magnitude < 4 or stuckTimer > Config.StuckThreshold or Humanoid.Sit
            
            if stuckTimer > Config.StuckThreshold then
                UnstuckAction()
                State.IsMoving = false
                return false
            end
        end
    else
        UnstuckAction()
        State.IsMoving = false
        return false
    end
    State.IsMoving = false
    return true
end

local function FindNewFriend()
    if not RootPart then return nil end
    local candidates = {}
    local myPos = RootPart.Position
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local dist = (p.Character.HumanoidRootPart.Position - myPos).Magnitude
            table.insert(candidates, {plr = p, dist = dist})
        end
    end
    table.sort(candidates, function(a, b) return a.dist < b.dist end)
    if #candidates > 0 then return candidates[1].plr end
    return nil
end

task.spawn(function()
    while task.wait(0.25) do
        local success, err = pcall(function()
            if not State.Enabled then return end
            if not Character or not Character.Parent then return end
            if not Humanoid or not RootPart then return end
            if Humanoid.Sit then return end
            
            if not State.IsMoving then
                if State.Mode == "Follow" and State.Target then
                    local targetRoot = State.Target:FindFirstChild("HumanoidRootPart")
                    if targetRoot and State.Target.Parent then
                        local dist = (RootPart.Position - targetRoot.Position).Magnitude
                        if dist > 8 then MoveToPoint(targetRoot.Position) end
                    else
                        State.Target = nil
                        State.Mode = "Wander"
                    end
                
                elseif State.Mode == "TargetSearch" then
                    if State.Target and State.Target.Parent and State.Target.Character then
                        local targetRoot = State.Target.Character:FindFirstChild("HumanoidRootPart")
                        if targetRoot then
                            local targetPos = targetRoot.Position
                            local dist = (RootPart.Position - targetPos).Magnitude
                            if dist > 8 then
                                local s = MoveToPoint(targetPos)
                                if not s then State.Target = nil; State.Mode = "Wander" end
                            else
                                local lookPos = Vector3.new(targetPos.X, RootPart.Position.Y, targetPos.Z)
                                RootPart.CFrame = CFrame.new(RootPart.Position, lookPos)
                                SendChat(GetSysPhrase("target_found"))
                                task.wait(2)
                                State.Mode = "Wander"
                                State.Target = nil
                            end
                        else
                            State.Mode = "Wander"
                            State.Target = nil
                        end
                    else
                        State.Mode = "Wander"
                        SendChat(GetSysPhrase("target_lost"))
                        State.Target = nil
                    end

                elseif State.Mode == "Wingman" then
                    if not State.WingmanTarget then
                        local friend = FindNewFriend()
                        if friend then
                            State.WingmanTarget = friend
                            Notify("Target: " .. friend.DisplayName)
                        else
                            State.Mode = "Wander"
                        end
                    elseif State.WingmanTarget and State.WingmanTarget.Parent and State.WingmanTarget.Character then
                        local targetRoot = State.WingmanTarget.Character:FindFirstChild("HumanoidRootPart")
                        if targetRoot then
                            local targetPos = targetRoot.Position
                            local dist = (RootPart.Position - targetPos).Magnitude
                            
                            if dist > 8 then
                                local s = MoveToPoint(targetPos)
                                if not s then State.WingmanTarget = nil end
                            else
                                local lookPos = Vector3.new(targetPos.X, RootPart.Position.Y, targetPos.Z)
                                RootPart.CFrame = CFrame.new(RootPart.Position, lookPos)
                                
                                SendChat(GetSysPhrase("wingman_greetings"))
                                
                                task.wait(3)
                                State.WingmanTarget = nil
                                State.Mode = "Wander"
                            end
                        else
                            State.WingmanTarget = nil
                        end
                    else
                        State.WingmanTarget = nil
                        State.Mode = "Wander"
                    end

                elseif State.Mode == "Wander" then
                    local rx = math.random(-Config.GlobalRange, Config.GlobalRange)
                    local rz = math.random(-Config.GlobalRange, Config.GlobalRange)
                    local potentialDest = RootPart.Position + Vector3.new(rx, 0, rz)
                    local params = RaycastParams.new()
                    params.FilterType = Enum.RaycastFilterType.Exclude
                    params.FilterDescendantsInstances = {Character}
                    local ray = workspace:Raycast(potentialDest + Vector3.new(0,500,0), Vector3.new(0,-1000,0), params)
                    if ray then 
                        MoveToPoint(ray.Position)
                    end
                    State.IsMoving = false
                end
            end
        end)
        
        if not success then
            State.IsMoving = false
        end
    end
end)

Notify("QUWY AI v3.0 Loaded!")
