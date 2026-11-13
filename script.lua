repeat task.wait() until game:IsLoaded()

local env = getgenv()

-- Remove previous instance (also one still running under the old SussyHub name)
for _, key in ipairs({ "BSSLarpUnload", "SussyHubUnload" }) do
    if env[key] then
        pcall(env[key])
    end
    env[key] = nil
end

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local plr = Players.LocalPlayer
local character = plr.Character or plr.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local root = character:WaitForChild("HumanoidRootPart")

-- Setup (only keep this if you trust/own this file)
loadstring(game:HttpGet("https://raw.githubusercontent.com/twootoXx/Roblox-Scripts/Helpers/refs/heads/main/SetUp.luau"))()

-- Obsidian UI Library (consider pinning a specific commit instead of "main")
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/main/Library.lua"))()

-- Movement settings
-- Read the game's own values so we don't overwrite them
local originalWalkSpeed = humanoid.WalkSpeed
local originalJumpPower = humanoid.JumpPower
local defaultWalkSpeed = math.clamp(math.floor(originalWalkSpeed + 0.5), 0, 200)
local defaultJumpPower = math.clamp(math.floor(originalJumpPower + 0.5), 0, 200)

-- nil means "the user never changed it, leave the game's value alone"
local walkSpeedValue = nil
local jumpPowerValue = nil

-- Flight variables
local flying = false
local flightSpeed = 100
local flightSmoothness = 8
local flightConnection
local bodyVelocity
local bodyGyro
local currentVelocity = Vector3.zero

-- Connections
local cursorConnection
local characterConnection

-- Apply movement settings (only the ones the user changed)
local function applyMovementSettings(char)
    local hum = char:WaitForChild("Humanoid", 10)
    if not hum then return end

    if walkSpeedValue ~= nil then
        hum.WalkSpeed = walkSpeedValue
    end

    if jumpPowerValue ~= nil then
        hum.UseJumpPower = true
        hum.JumpPower = jumpPowerValue
    end
end

-- Keep the Fly toggle in the UI matching the real flight state
local function syncFlyToggle()
    local toggle = Library.Toggles and Library.Toggles.FlyToggle
    if toggle and toggle.Value ~= flying then
        pcall(function()
            toggle:SetValue(flying)
        end)
    end
end

-- Stop flight
local function stopFlying()
    if flightConnection then
        flightConnection:Disconnect()
        flightConnection = nil
    end

    if bodyVelocity then
        bodyVelocity:Destroy()
        bodyVelocity = nil
    end

    if bodyGyro then
        bodyGyro:Destroy()
        bodyGyro = nil
    end

    local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.PlatformStand = false
    end

    flying = false
    currentVelocity = Vector3.zero

    syncFlyToggle()
end

-- Start/stop flight
local function setFlying(state)
    if state == flying then return end

    if not state then
        stopFlying()
        return
    end

    character = plr.Character
    humanoid = character and character:FindFirstChildOfClass("Humanoid")
    root = character and character:FindFirstChild("HumanoidRootPart")

    if not humanoid or not root then
        syncFlyToggle()
        return
    end

    flying = true
    humanoid.PlatformStand = true

    bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bodyVelocity.Velocity = Vector3.zero
    bodyVelocity.Parent = root

    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bodyGyro.P = 90000
    bodyGyro.CFrame = root.CFrame
    bodyGyro.Parent = root

    flightConnection = RunService.RenderStepped:Connect(function(dt)
        if not flying or not root or not root.Parent then
            stopFlying()
            return
        end

        local camera = workspace.CurrentCamera
        if not camera then return end

        local moveDirection = Vector3.zero

        -- Don't fly while typing in chat or a UI text box
        if not UserInputService:GetFocusedTextBox() then
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                moveDirection += camera.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                moveDirection -= camera.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                moveDirection -= camera.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                moveDirection += camera.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                moveDirection += Vector3.yAxis
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                moveDirection -= Vector3.yAxis
            end
        end

        if moveDirection.Magnitude > 0 then
            moveDirection = moveDirection.Unit
        end

        local targetVelocity = moveDirection * flightSpeed
        local alpha = math.clamp(dt * flightSmoothness, 0, 1)

        currentVelocity = currentVelocity:Lerp(targetVelocity, alpha)
        bodyVelocity.Velocity = currentVelocity

        -- Face the camera's horizontal direction only (no tilting up/down)
        local look = camera.CFrame.LookVector
        local flat = Vector3.new(look.X, 0, look.Z)
        if flat.Magnitude > 0.01 then
            bodyGyro.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
        end
    end)
end

-- Respawn support
characterConnection = plr.CharacterAdded:Connect(function(char)
    character = char
    humanoid = char:WaitForChild("Humanoid")
    root = char:WaitForChild("HumanoidRootPart")

    stopFlying() -- also switches the Fly toggle off in the UI
    applyMovementSettings(char)
end)

-- Cleanup (runs whenever the library unloads, however it gets closed)
local function cleanup()
    stopFlying()

    pcall(function()
        RunService:UnbindFromRenderStep("BSSLarpFakeStats")
    end)

    if cursorConnection then
        cursorConnection:Disconnect()
        cursorConnection = nil
    end

    if characterConnection then
        characterConnection:Disconnect()
        characterConnection = nil
    end

    -- Give the game its own movement values back
    local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        if walkSpeedValue ~= nil then
            hum.WalkSpeed = originalWalkSpeed
        end
        if jumpPowerValue ~= nil then
            hum.JumpPower = originalJumpPower
        end
    end

    UserInputService.MouseIconEnabled = true
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
end

Library:OnUnload(cleanup)

-- Lets a re-execute remove this instance
env.BSSLarpUnload = function()
    Library:Unload()
end

-- Create window
local Window = Library:CreateWindow({
    Title = "BSSLarp",
    Footer = "v1.0.0",
    ToggleKeybind = Enum.KeyCode.LeftAlt,
    Center = true,
    AutoShow = true,
    ShowCustomCursor = false
})

Library.ShowCustomCursor = false

-- Tabs
local InfoTab = Window:AddTab("Info")
local MainTab = Window:AddTab("Main")
local SettingsTab = Window:AddTab("Settings")

-- Groupboxes
local infoBox = InfoTab:AddLeftGroupbox("Script Info")
local discordBox = InfoTab:AddRightGroupbox("Discord")
local mainBox = MainTab:AddLeftGroupbox("Main")
local scriptBox = SettingsTab:AddLeftGroupbox("Script")

-- Info tab
infoBox:AddLabel("BSSLarp")
infoBox:AddLabel("Version: 1.0.0")
infoBox:AddLabel("Made for Roblox")

discordBox:AddButton({
    Text = "Copy Discord Invite",
    Func = function()
        if setclipboard then
            setclipboard("https://discord.gg/") -- TODO: put your real invite here
        end
    end,
    DoubleClick = false
})

-- Main tab
mainBox:AddButton({
    Text = "Click to see what happens",
    Func = function()
        -- Go through the toggle so the UI always matches the real state
        local toggle = Library.Toggles.FlyToggle
        toggle:SetValue(not toggle.Value)
    end,
    DoubleClick = false
})

-- Fly toggle
mainBox:AddToggle("FlyToggle", {
    Text = "Fly",
    Default = false,
    Callback = function(Value)
        setFlying(Value)
    end
}):AddKeyPicker("FlyKeybind", {
    Default = "F",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Fly Keybind"
})

-- WalkSpeed slider
mainBox:AddSlider("WalkSpeedSlider", {
    Text = "WalkSpeed",
    Default = defaultWalkSpeed,
    Min = 0,
    Max = 200,
    Rounding = 0,
    Callback = function(Value)
        -- Ignore the initial default so the game's own value isn't overwritten
        if walkSpeedValue == nil and Value == defaultWalkSpeed then return end

        walkSpeedValue = Value

        local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = Value
        end
    end
})

-- JumpPower slider
mainBox:AddSlider("JumpPowerSlider", {
    Text = "JumpPower",
    Default = defaultJumpPower,
    Min = 0,
    Max = 200,
    Rounding = 0,
    Callback = function(Value)
        if jumpPowerValue == nil and Value == defaultJumpPower then return end

        jumpPowerValue = Value

        local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.UseJumpPower = true
            hum.JumpPower = Value
        end
    end
})

-- Fake stats (VISUAL ONLY: changes the text on YOUR screen, not your real values)
local HttpService = game:GetService("HttpService")

local SAVE_FOLDER = "BSSLarp"
local LABELS_FILE = SAVE_FOLDER .. "/labels.json"

local fakeStats = {}
local savedPaths = {}

-- Remember which labels were found, so they come back after a reload
pcall(function()
    if makefolder and isfolder and not isfolder(SAVE_FOLDER) then
        makefolder(SAVE_FOLDER)
    end

    if isfile and readfile and isfile(LABELS_FILE) then
        local data = HttpService:JSONDecode(readfile(LABELS_FILE))
        if typeof(data) == "table" then
            savedPaths = data
        end
    end
end)

local function savePaths()
    pcall(function()
        if writefile then
            writefile(LABELS_FILE, HttpService:JSONEncode(savedPaths))
        end
    end)
end

-- ---------- number helpers (numbers are handled as text, so there's no size limit) ----------

local function normalizeText(text)
    return (tostring(text):gsub("[%s,]", "")):lower()
end

local function cleanDigits(raw)
    local digits = (tostring(raw):gsub("%D", ""))
    return (digits:gsub("^0+", ""))
end

local function formatNumber(raw)
    local digits = cleanDigits(raw)
    if digits == "" then
        digits = "0"
    end
    if #digits > 30 then
        digits = string.rep("9", 30)
    end

    local formatted = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (formatted:gsub("^,", ""))
end

-- Adds two whole numbers given as text
local function bigAdd(a, b)
    a = cleanDigits(a)
    b = cleanDigits(b)
    if a == "" then a = "0" end
    if b == "" then b = "0" end

    local result = {}
    local carry = 0
    local i, j = #a, #b

    while i > 0 or j > 0 or carry > 0 do
        local sum = carry

        if i > 0 then
            sum += tonumber(a:sub(i, i))
            i -= 1
        end
        if j > 0 then
            sum += tonumber(b:sub(j, j))
            j -= 1
        end

        table.insert(result, sum % 10)
        carry = sum // 10
    end

    return table.concat(result):reverse()
end

-- First number in a piece of text ("1,234 / 5,000" -> 1234)
local function parseFirstNumber(text)
    local num = text:match("%d[%d,]*")
    return num and tonumber((num:gsub(",", ""))) or nil
end

-- ---------- finding labels ----------

-- A path that survives reloads. Each step stores the name AND which same-named
-- sibling it is, because this game has lots of UI elements with identical names.
local function getPath(obj)
    local steps = {}
    local current = obj

    while current and current ~= game do
        local parent = current.Parent
        if not parent then return nil end

        local index = 0
        for _, sibling in ipairs(parent:GetChildren()) do
            if sibling.Name == current.Name then
                index += 1
                if sibling == current then break end
            end
        end

        table.insert(steps, 1, { name = current.Name, index = index })
        current = parent
    end

    return steps
end

local function resolvePath(steps)
    local obj = game

    for _, step in ipairs(steps) do
        local nextObj = nil
        local count = 0

        for _, child in ipairs(obj:GetChildren()) do
            if child.Name == step.name then
                count += 1
                if count == step.index then
                    nextObj = child
                    break
                end
            end
        end

        if not nextObj then return nil end
        obj = nextObj
    end

    return obj
end

local function makeEntry(obj)
    local text = obj.Text
    return {
        label = obj,
        -- keeps the " / 5,000" max part if there is one
        suffix = text:match("%s*/.*$") or "",
        lastReal = parseFirstNumber(text),
        lastWritten = nil
    }
end

-- Looks the saved labels up again (new script run, or the game rebuilt its UI)
local function resolveStatLabels(stat)
    table.clear(stat.labels)

    for _, path in ipairs(stat.paths) do
        if typeof(path) == "table" then
            local obj = resolvePath(path)
            if obj
                and (obj:IsA("TextLabel") or obj:IsA("TextButton"))
                and obj.Text:match("%d") then
                table.insert(stat.labels, makeEntry(obj))
            end
        end
    end
end

-- ---------- following what you really collect ----------

-- Called when the game changed the label text since we last wrote it (= the real value)
local function trackReal(stat, entry)
    local real = parseFirstNumber(entry.label.Text)
    if not real then return end

    if entry.lastReal and stat.track and entry == stat.labels[1] then
        local change = real - entry.lastReal

        if change > 0 then
            -- you collected something: the fake number goes up by the same amount
            stat.value = bigAdd(stat.value, string.format("%.0f", change))

            if stat.cap and (tonumber(stat.value) or 0) > (tonumber(stat.cap) or 0) then
                stat.value = stat.cap
            end

            stat.dirty = true
        elseif stat.resetOnDrop and entry.lastReal > 0 and -change >= entry.lastReal * 0.5 then
            -- pollen got converted into honey: start from empty again
            stat.value = "0"
            stat.dirty = true
        end
    end

    entry.lastReal = real
end

-- Shows the current fake value in the textbox too, so it gets saved
local function syncValueBox(stat)
    local option = Library.Options and Library.Options[stat.id .. "FakeInput"]
    if option then
        stat.syncing = true
        pcall(function()
            option:SetValue(stat.value)
        end)
        stat.syncing = false
    end
end

-- ---------- the UI for one stat ----------

local function createFakeStat(id, title, placeholder, opts)
    opts = opts or {}

    local stat = {
        id = id,
        labels = {},
        enabled = false,
        value = "0",
        cap = nil,
        hasCap = opts.capacity == true,
        resetOnDrop = opts.capacity == true,
        finderText = "",
        paths = typeof(savedPaths[id]) == "table" and savedPaths[id] or {},
        track = true,
        dirty = false,
        syncing = false,
        lastSync = 0,
        lastResolve = 0
    }
    table.insert(fakeStats, stat)

    local box = MainTab:AddRightGroupbox(title)

    local function notify(text)
        Library:Notify({
            Title = title,
            Description = text,
            Time = 5
        })
    end

    -- Finds every label showing the number you typed (or "number/max")
    local function findLabels()
        local target = normalizeText(stat.finderText)
        if target == "" then
            notify("Type your current " .. id:lower() .. " exactly as shown on screen first.")
            return
        end

        local gui = plr:FindFirstChildOfClass("PlayerGui")
        if not gui then return end

        local found = {}

        for _, obj in ipairs(gui:GetDescendants()) do
            if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                local text = normalizeText(obj.Text)

                -- matches "1234" or "1234/5000"
                if text == target or text:sub(1, #target + 1) == target .. "/" then
                    table.insert(found, obj)
                    print("[BSSLarp] " .. id .. " label found:", obj:GetFullName())
                end
            end
        end

        if #found == 0 then
            notify("No label matched. Turn the fake off, then type the number exactly as shown, right when you click.")
            return
        end

        -- Use the labels we just found directly, and save paths for the next script run
        table.clear(stat.labels)
        stat.paths = {}

        for _, obj in ipairs(found) do
            table.insert(stat.labels, makeEntry(obj))

            local path = getPath(obj)
            if path then
                table.insert(stat.paths, path)
            end
        end

        savedPaths[id] = stat.paths
        savePaths()

        local note = ""
        if stat.hasCap and not found[1].Text:find("/", 1, true) then
            note = " This label has no '/ max' part, so the fake max capacity has nothing to replace here."
        end

        notify("Found " .. #found .. " label(s), saved for next time." .. note)
    end

    box:AddLabel("Visual only, just you see it")

    box:AddInput(id .. "FinderInput", {
        Text = "Current " .. id:lower() .. " (as shown)",
        Default = "",
        Placeholder = placeholder,
        Callback = function(Value)
            stat.finderText = Value
        end
    })

    box:AddButton({
        Text = "Find " .. id:lower() .. " label",
        Func = findLabels,
        DoubleClick = false
    })

    box:AddInput(id .. "FakeInput", {
        Text = "Fake " .. id:lower() .. " value",
        Default = "",
        Placeholder = "e.g. 1000000000000000000",
        Callback = function(Value)
            if stat.syncing then return end
            stat.value = Value
        end
    })

    if stat.hasCap then
        box:AddInput(id .. "CapInput", {
            Text = "Fake max capacity",
            Default = "",
            Placeholder = "e.g. 5000000",
            Callback = function(Value)
                local digits = cleanDigits(Value)
                stat.cap = digits ~= "" and digits or nil
            end
        })
    end

    box:AddToggle(id .. "FakeToggle", {
        Text = "Show fake " .. id:lower(),
        Default = false,
        Callback = function(Value)
            stat.enabled = Value
        end
    })

    box:AddToggle(id .. "TrackToggle", {
        Text = "Add what I collect",
        Default = true,
        Callback = function(Value)
            stat.track = Value
        end
    })
end

-- ---------- per-frame update ----------

-- Runs after the game's own UI updates so our text wins
pcall(function()
    RunService:UnbindFromRenderStep("BSSLarpFakeStats")
end)

RunService:BindToRenderStep("BSSLarpFakeStats", Enum.RenderPriority.Last.Value + 1, function()
    for _, stat in ipairs(fakeStats) do
        if stat.enabled then
            -- No labels yet (new script run, or the game rebuilt its UI): look them up again
            if #stat.labels == 0 and #stat.paths > 0 and os.clock() - stat.lastResolve > 1 then
                stat.lastResolve = os.clock()
                resolveStatLabels(stat)
            end

            -- 1) if the game changed a label since we wrote it, that is the real value
            for i = #stat.labels, 1, -1 do
                local entry = stat.labels[i]
                if entry.label.Parent then
                    if entry.label.Text ~= entry.lastWritten then
                        trackReal(stat, entry)
                    end
                else
                    table.remove(stat.labels, i)
                end
            end

            -- 2) the number we show (never above the fake max capacity, if you set one)
            local value = stat.value
            if stat.cap and (tonumber(value) or 0) > (tonumber(stat.cap) or 0) then
                value = stat.cap
            end

            local valueText = formatNumber(value)
            local capText = stat.cap and formatNumber(stat.cap) or nil

            for _, entry in ipairs(stat.labels) do
                local suffix = entry.suffix
                if capText and suffix ~= "" then
                    suffix = (suffix:gsub("%d[%d,]*", capText))
                end

                local text = valueText .. suffix
                entry.lastWritten = text
                entry.label.Text = text
            end

            -- 3) show collected progress in the textbox now and then (so it also gets saved)
            if stat.dirty and os.clock() - stat.lastSync > 2 then
                stat.dirty = false
                stat.lastSync = os.clock()
                syncValueBox(stat)
            end
        else
            -- off: forget what we tracked, so turning it on again starts fresh
            for _, entry in ipairs(stat.labels) do
                entry.lastReal = nil
                entry.lastWritten = nil
            end
        end
    end
end)

createFakeStat("Honey", "Fake Honey", "e.g. 1,234,567")
createFakeStat("Pollen", "Fake Pollen", "e.g. 1,234", { capacity = true })

-- Settings tab
scriptBox:AddButton({
    Text = "Show Mouse Cursor",
    Func = function()
        Library.ShowCustomCursor = false
        UserInputService.MouseIconEnabled = true
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    end,
    DoubleClick = false
})

-- Menu keybind
scriptBox:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", {
    Default = "LeftAlt",
    NoUI = true,
    Text = "Menu keybind"
})

Library.ToggleKeybind = Library.Options.MenuKeybind

-- Restore cursor when the menu key is pressed (follows the rebindable key)
cursorConnection = UserInputService.InputBegan:Connect(function(input)
    local menuKey = Library.Options.MenuKeybind and Library.Options.MenuKeybind.Value
    if menuKey and input.KeyCode.Name == menuKey then
        UserInputService.MouseIconEnabled = true
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    end
end)

-- Unload button
scriptBox:AddButton({
    Text = "Unload BSSLarp",
    Func = function()
        Library:Unload()
        env.BSSLarpUnload = nil
    end,
    DoubleClick = false
})

-- Settings persistence: saves automatically, loads when the script runs
local persistOk, persistErr = pcall(function()
    local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/main/addons/SaveManager.lua"))()

    local ignored = {
        MenuKeybind = true,       -- same as the Obsidian docs example
        FlyToggle = true,         -- don't start flying on every execute
        HoneyFinderInput = true,  -- these only hold what you typed to find a label
        PollenFinderInput = true
    }

    SaveManager:SetLibrary(Library)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({ "MenuKeybind", "FlyToggle", "HoneyFinderInput", "PollenFinderInput" })
    SaveManager:SetFolder("BSSLarp")
    SaveManager:BuildConfigSection(SettingsTab)

    -- First run: make "default" the config that loads automatically
    local autoName = SaveManager:GetAutoloadConfig()
    if not autoName or autoName == "none" then
        SaveManager:Save("default")
        SaveManager:SaveAutoloadConfig("default")
    end

    SaveManager:LoadAutoloadConfig()

    -- Autosave a second after the last change (hooked after the load above, so loading doesn't trigger it)
    local saveToken = 0

    local function queueSave()
        saveToken += 1
        local token = saveToken

        task.delay(1, function()
            if token ~= saveToken or Library.Unloaded then return end

            local name = SaveManager:GetAutoloadConfig()
            if not name or name == "none" then
                name = "default"
                SaveManager:SaveAutoloadConfig(name)
            end

            pcall(SaveManager.Save, SaveManager, name)
        end)
    end

    local function hook(controls)
        for idx, control in pairs(controls) do
            if type(idx) == "string"
                and not ignored[idx]
                and not idx:find("^SaveManager_")
                and control.OnChanged then
                pcall(function()
                    control:OnChanged(queueSave)
                end)
            end
        end
    end

    hook(Library.Options)
    hook(Library.Toggles)
end)

if not persistOk then
    warn("[BSSLarp] Settings saving is unavailable: " .. tostring(persistErr))
end

-- Apply movement values only if the user changed them
applyMovementSettings(plr.Character)
