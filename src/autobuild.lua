--[[
    Babft-Autobuild
    Original clean-room implementation for Build A Boat For Treasure.
    No key system.

    Features:
      - Native mobile-friendly UI
      - Export current build to JSON
      - Import JSON blueprint
      - Save/load local blueprint files when executor file APIs exist
      - Copy JSON to clipboard when setclipboard exists
      - Place, scale, paint and transparency restoration
      - Progress display + cancel
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Data = LocalPlayer:WaitForChild("Data")
local BlocksRoot = workspace:WaitForChild("Blocks")

local APP_NAME = "BabftAutobuild"
local SAVE_DIR = "BabftAutobuild"
local BUILD_VERSION = 1

local state = {
    busy = false,
    cancel = false,
    delay = 0.05,
    status = "Ready",
}

local function notify(text)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "BABFT Autobuild",
            Text = tostring(text),
            Duration = 4,
        })
    end)
end

local function getCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getHumanoid()
    return getCharacter():FindFirstChildOfClass("Humanoid")
end

local function getTool(name)
    local character = getCharacter()
    local tool = character:FindFirstChild(name)
    if tool then
        return tool
    end

    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    local backpackTool = backpack and backpack:FindFirstChild(name)
    if not backpackTool then
        return nil
    end

    local humanoid = getHumanoid()
    if humanoid then
        pcall(function()
            humanoid:EquipTool(backpackTool)
        end)
        task.wait(0.08)
    end

    return character:FindFirstChild(name) or backpackTool
end

local function zoneCFrame(zone)
    if not zone then
        return nil
    end
    if zone:IsA("BasePart") then
        return zone.CFrame
    end
    if zone:IsA("Model") then
        return zone:GetPivot()
    end
    return nil
end

local function getPlayerZone(player)
    local teamColor = player.TeamColor
    for _, object in ipairs(workspace:GetChildren()) do
        local marker = object:FindFirstChild("TeamColor")
        if marker and marker.Value == teamColor and zoneCFrame(object) then
            return object
        end
    end
    return nil
end

local function getOwnFolder()
    return BlocksRoot:FindFirstChild(LocalPlayer.Name)
end

local function getMainPart(block)
    if not block then
        return nil
    end
    if block:IsA("BasePart") then
        return block
    end
    local ppart = block:FindFirstChild("PPart")
    if ppart and ppart:IsA("BasePart") then
        return ppart
    end
    return block:FindFirstChildWhichIsA("BasePart", true)
end

local function getInventoryValue(name)
    local item = Data:FindFirstChild(name)
    if item and item:IsA("ValueBase") and type(item.Value) == "number" then
        return item.Value
    end
    return 0
end

local function cframeToArray(cf)
    return {cf:GetComponents()}
end

local function arrayToCFrame(a)
    if type(a) ~= "table" or #a < 12 then
        return CFrame.new()
    end
    return CFrame.new(
        tonumber(a[1]) or 0, tonumber(a[2]) or 0, tonumber(a[3]) or 0,
        tonumber(a[4]) or 1, tonumber(a[5]) or 0, tonumber(a[6]) or 0,
        tonumber(a[7]) or 0, tonumber(a[8]) or 1, tonumber(a[9]) or 0,
        tonumber(a[10]) or 0, tonumber(a[11]) or 0, tonumber(a[12]) or 1
    )
end

local function vectorToArray(v)
    return {v.X, v.Y, v.Z}
end

local function arrayToVector3(a, fallback)
    fallback = fallback or Vector3.new(2, 2, 2)
    if type(a) ~= "table" then
        return fallback
    end
    return Vector3.new(
        tonumber(a[1]) or fallback.X,
        tonumber(a[2]) or fallback.Y,
        tonumber(a[3]) or fallback.Z
    )
end

local function colorToArray(c)
    return {c.R, c.G, c.B}
end

local function arrayToColor3(a)
    if type(a) ~= "table" then
        return Color3.new(1, 1, 1)
    end
    return Color3.new(
        math.clamp(tonumber(a[1]) or 1, 0, 1),
        math.clamp(tonumber(a[2]) or 1, 0, 1),
        math.clamp(tonumber(a[3]) or 1, 0, 1)
    )
end

local function placeBlock(name, worldCF, anchored)
    local zone = getPlayerZone(LocalPlayer)
    local zcf = zoneCFrame(zone)
    if not zone or not zcf then
        return false, "team zone not found"
    end

    local tool = getTool("BuildingTool")
    local rf = tool and tool:FindFirstChild("RF")
    if not rf or not rf:IsA("RemoteFunction") then
        return false, "BuildingTool.RF not found"
    end

    local args = {
        name,
        getInventoryValue(name),
        zone,
        zcf:ToObjectSpace(worldCF),
        anchored ~= false,
        worldCF,
        false,
    }

    local ok, result = pcall(function()
        return rf:InvokeServer(unpack(args))
    end)
    return ok, result
end

local function scaleBlock(block, targetCF, size)
    local tool = getTool("ScalingTool")
    local rf = tool and tool:FindFirstChild("RF")
    if not rf or not rf:IsA("RemoteFunction") then
        return false
    end
    return pcall(function()
        rf:InvokeServer(block, size, targetCF)
    end)
end

local function paintBlock(block, color)
    local tool = getTool("PaintingTool")
    local rf = tool and tool:FindFirstChild("RF")
    if not rf or not rf:IsA("RemoteFunction") then
        return false
    end
    return pcall(function()
        rf:InvokeServer({{block, color}})
    end)
end

local function setTransparency(block, transparency)
    transparency = math.clamp(tonumber(transparency) or 0, 0, 1)
    if transparency < 0.125 then
        return true
    end

    local tool = getTool("PropertiesTool")
    local rf = tool and tool:FindFirstChild("SetPropertieRF")
    if not rf or not rf:IsA("RemoteFunction") then
        return false
    end

    local steps = math.floor((transparency / 0.25) + 0.5)
    for _ = 1, math.clamp(steps, 0, 4) do
        pcall(function()
            rf:InvokeServer("Transparency", {block})
        end)
        task.wait(0.03)
    end
    return true
end

local function snapshotChildren(folder)
    local set = {}
    for _, child in ipairs(folder:GetChildren()) do
        set[child] = true
    end
    return set
end

local function waitForNewBlock(folder, expectedName, before, timeout)
    local deadline = os.clock() + (timeout or 3)
    repeat
        for _, child in ipairs(folder:GetChildren()) do
            if not before[child] and (child.Name == expectedName or getMainPart(child)) then
                return child
            end
        end
        task.wait(0.05)
    until os.clock() >= deadline or state.cancel
    return nil
end

local function captureBuild()
    local folder = getOwnFolder()
    local zone = getPlayerZone(LocalPlayer)
    local zcf = zoneCFrame(zone)
    if not folder or not zcf then
        return nil, "Your build folder or team zone was not found."
    end

    local blocks = {}
    for _, block in ipairs(folder:GetChildren()) do
        local part = getMainPart(block)
        if part then
            local relative = zcf:ToObjectSpace(part.CFrame)
            blocks[#blocks + 1] = {
                name = block.Name,
                cframe = cframeToArray(relative),
                size = vectorToArray(part.Size),
                color = colorToArray(part.Color),
                transparency = part.Transparency,
                anchored = part.Anchored,
            }
        end
    end

    table.sort(blocks, function(a, b)
        return a.name < b.name
    end)

    return {
        format = "babft-autobuild",
        version = BUILD_VERSION,
        createdAt = os.time(),
        author = LocalPlayer.Name,
        blockCount = #blocks,
        blocks = blocks,
    }
end

local function validateBlueprint(bp)
    if type(bp) ~= "table" then
        return false, "Blueprint is not a table."
    end
    if bp.format ~= "babft-autobuild" then
        return false, "Unsupported blueprint format."
    end
    if type(bp.blocks) ~= "table" then
        return false, "Blueprint has no blocks array."
    end
    if #bp.blocks > 20000 then
        return false, "Blueprint is too large."
    end
    return true
end

local function buildBlueprint(bp, onProgress)
    local valid, why = validateBlueprint(bp)
    if not valid then
        return false, why
    end
    if state.busy then
        return false, "A build is already running."
    end

    local folder = getOwnFolder()
    local zone = getPlayerZone(LocalPlayer)
    local zcf = zoneCFrame(zone)
    if not folder or not zcf then
        return false, "Your build folder or team zone was not found."
    end

    state.busy = true
    state.cancel = false

    local placed = 0
    local failed = 0
    local total = #bp.blocks

    for index, entry in ipairs(bp.blocks) do
        if state.cancel then
            break
        end

        if type(entry) == "table" and type(entry.name) == "string" then
            local relativeCF = arrayToCFrame(entry.cframe)
            local worldCF = zcf * relativeCF
            local before = snapshotChildren(folder)
            local ok = placeBlock(entry.name, worldCF, entry.anchored)

            if ok then
                local newBlock = waitForNewBlock(folder, entry.name, before, 3)
                if newBlock then
                    local targetSize = arrayToVector3(entry.size)
                    local targetColor = arrayToColor3(entry.color)
                    scaleBlock(newBlock, worldCF, targetSize)
                    paintBlock(newBlock, targetColor)
                    setTransparency(newBlock, entry.transparency)
                    placed += 1
                else
                    failed += 1
                end
            else
                failed += 1
            end
        else
            failed += 1
        end

        if onProgress then
            pcall(onProgress, index, total, placed, failed)
        end
        task.wait(state.delay)
    end

    local cancelled = state.cancel
    state.busy = false
    state.cancel = false

    if cancelled then
        return false, string.format("Cancelled. Placed %d/%d blocks.", placed, total)
    end
    return true, string.format("Done. Placed %d/%d blocks, %d failed.", placed, total, failed)
end

local function ensureSaveDir()
    if not makefolder or not isfolder then
        return false
    end
    if not isfolder(SAVE_DIR) then
        pcall(makefolder, SAVE_DIR)
    end
    return isfolder(SAVE_DIR)
end

local function sanitizeFileName(name)
    name = tostring(name or "build")
    name = name:gsub("[^%w%-%_ ]", "")
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then
        name = "build"
    end
    return name:sub(1, 60)
end

local function saveBlueprintFile(name, json)
    if not writefile or not ensureSaveDir() then
        return false, "Executor file API is unavailable."
    end
    local path = SAVE_DIR .. "/" .. sanitizeFileName(name) .. ".json"
    local ok, err = pcall(writefile, path, json)
    return ok, ok and path or tostring(err)
end

local function loadBlueprintFile(name)
    if not readfile or not isfile then
        return nil, "Executor file API is unavailable."
    end
    local path = SAVE_DIR .. "/" .. sanitizeFileName(name) .. ".json"
    if not isfile(path) then
        return nil, "File not found: " .. path
    end
    local ok, content = pcall(readfile, path)
    if not ok then
        return nil, tostring(content)
    end
    return content, path
end

-- UI ------------------------------------------------------------------------

pcall(function()
    local old = CoreGui:FindFirstChild(APP_NAME)
    if old then old:Destroy() end
    old = PlayerGui:FindFirstChild(APP_NAME)
    if old then old:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = APP_NAME
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false

local parentTarget = PlayerGui
if gethui then
    local ok, hui = pcall(gethui)
    if ok and hui then parentTarget = hui end
end
gui.Parent = parentTarget

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(390, 510)
main.Position = UDim2.new(0.5, -195, 0.5, -255)
main.BackgroundColor3 = Color3.fromRGB(18, 20, 27)
main.BorderSizePixel = 0
main.Parent = gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 16)
mainCorner.Parent = main

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(72, 79, 105)
stroke.Transparency = 0.25
stroke.Thickness = 1
stroke.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -88, 0, 50)
title.Position = UDim2.fromOffset(18, 4)
title.BackgroundTransparency = 1
title.Text = "BABFT Autobuild"
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
title.TextSize = 21
title.TextColor3 = Color3.fromRGB(245, 247, 255)
title.Parent = main

local badge = Instance.new("TextLabel")
badge.Size = UDim2.fromOffset(58, 24)
badge.Position = UDim2.new(1, -132, 0, 16)
badge.BackgroundColor3 = Color3.fromRGB(76, 99, 255)
badge.Text = "KEYLESS"
badge.Font = Enum.Font.GothamBold
badge.TextSize = 10
badge.TextColor3 = Color3.new(1,1,1)
badge.Parent = main
Instance.new("UICorner", badge).CornerRadius = UDim.new(1, 0)

local minimize = Instance.new("TextButton")
minimize.Size = UDim2.fromOffset(38, 38)
minimize.Position = UDim2.new(1, -46, 0, 10)
minimize.BackgroundColor3 = Color3.fromRGB(34, 37, 48)
minimize.Text = "−"
minimize.Font = Enum.Font.GothamBold
minimize.TextSize = 22
minimize.TextColor3 = Color3.fromRGB(230, 233, 245)
minimize.Parent = main
Instance.new("UICorner", minimize).CornerRadius = UDim.new(0, 10)

local divider = Instance.new("Frame")
divider.Size = UDim2.new(1, -28, 0, 1)
divider.Position = UDim2.fromOffset(14, 55)
divider.BackgroundColor3 = Color3.fromRGB(52, 56, 72)
divider.BorderSizePixel = 0
divider.Parent = main

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -28, 1, -74)
content.Position = UDim2.fromOffset(14, 64)
content.BackgroundTransparency = 1
content.Parent = main

local function makeLabel(text, y, height)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, height or 22)
    l.Position = UDim2.fromOffset(0, y)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Font = Enum.Font.GothamMedium
    l.TextSize = 13
    l.TextColor3 = Color3.fromRGB(180, 187, 210)
    l.Parent = content
    return l
end

local function makeBox(placeholder, y, height)
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, 0, 0, height)
    box.Position = UDim2.fromOffset(0, y)
    box.BackgroundColor3 = Color3.fromRGB(27, 30, 40)
    box.BorderSizePixel = 0
    box.PlaceholderText = placeholder
    box.PlaceholderColor3 = Color3.fromRGB(118, 125, 148)
    box.Text = ""
    box.ClearTextOnFocus = false
    box.MultiLine = height > 50
    box.TextWrapped = false
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.TextYAlignment = Enum.TextYAlignment.Top
    box.Font = Enum.Font.Code
    box.TextSize = 12
    box.TextColor3 = Color3.fromRGB(225, 230, 245)
    box.Parent = content
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 10)
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 10)
    pad.PaddingRight = UDim.new(0, 10)
    pad.PaddingTop = UDim.new(0, 8)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.Parent = box
    return box
end

local function makeButton(text, xScale, xOffset, y, widthScale, widthOffset)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(widthScale, widthOffset, 0, 38)
    b.Position = UDim2.new(xScale, xOffset, 0, y)
    b.BackgroundColor3 = Color3.fromRGB(48, 55, 78)
    b.BorderSizePixel = 0
    b.Text = text
    b.Font = Enum.Font.GothamSemibold
    b.TextSize = 13
    b.TextColor3 = Color3.fromRGB(242, 244, 252)
    b.Parent = content
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
    return b
end

makeLabel("Blueprint JSON", 0)
local jsonBox = makeBox("Paste a BABFT Autobuild JSON blueprint here...", 24, 190)

makeLabel("Save name", 224)
local nameBox = makeBox("my-build", 247, 38)
nameBox.MultiLine = false
nameBox.TextYAlignment = Enum.TextYAlignment.Center
nameBox.Font = Enum.Font.Gotham

local exportButton = makeButton("Export current", 0, 0, 295, 0.49, 0)
local buildButton = makeButton("Build JSON", 0.51, 0, 295, 0.49, 0)
buildButton.BackgroundColor3 = Color3.fromRGB(76, 99, 255)

local saveButton = makeButton("Save file", 0, 0, 341, 0.32, 0)
local loadButton = makeButton("Load file", 0.34, 0, 341, 0.32, 0)
local cancelButton = makeButton("Cancel", 0.68, 0, 341, 0.32, 0)
cancelButton.BackgroundColor3 = Color3.fromRGB(108, 48, 61)

local delayLabel = makeLabel("Block delay: 0.05s", 389)
local delayBox = makeBox("0.05", 411, 34)
delayBox.Size = UDim2.fromOffset(86, 34)
delayBox.MultiLine = false
delayBox.TextYAlignment = Enum.TextYAlignment.Center
delayBox.Text = "0.05"
delayBox.Font = Enum.Font.Gotham

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -98, 0, 34)
status.Position = UDim2.fromOffset(98, 411)
status.BackgroundColor3 = Color3.fromRGB(27, 30, 40)
status.BorderSizePixel = 0
status.Text = "Ready"
status.TextXAlignment = Enum.TextXAlignment.Left
status.Font = Enum.Font.GothamMedium
status.TextSize = 12
status.TextColor3 = Color3.fromRGB(182, 218, 188)
status.Parent = content
Instance.new("UICorner", status).CornerRadius = UDim.new(0, 10)
local statusPad = Instance.new("UIPadding")
statusPad.PaddingLeft = UDim.new(0, 10)
statusPad.Parent = status

local minimized = false
minimize.MouseButton1Click:Connect(function()
    minimized = not minimized
    content.Visible = not minimized
    divider.Visible = not minimized
    main.Size = minimized and UDim2.fromOffset(390, 58) or UDim2.fromOffset(390, 510)
    minimize.Text = minimized and "+" or "−"
end)

-- Dragging
local dragging = false
local dragStart
local startPos
local dragInput

main.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if input.Position.Y <= main.AbsolutePosition.Y + 58 then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end
end)

main.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input == dragInput then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local function setStatus(text, good)
    status.Text = tostring(text)
    status.TextColor3 = good == false and Color3.fromRGB(244, 169, 169) or Color3.fromRGB(182, 218, 188)
end

delayBox.FocusLost:Connect(function()
    local n = tonumber(delayBox.Text)
    if not n then n = state.delay end
    n = math.clamp(n, 0, 2)
    state.delay = n
    delayBox.Text = string.format("%.2f", n)
    delayLabel.Text = "Block delay: " .. string.format("%.2fs", n)
end)

exportButton.MouseButton1Click:Connect(function()
    if state.busy then
        setStatus("Wait for the current build.", false)
        return
    end
    setStatus("Scanning your build...")
    task.spawn(function()
        local bp, err = captureBuild()
        if not bp then
            setStatus(err, false)
            return
        end
        local ok, json = pcall(function()
            return HttpService:JSONEncode(bp)
        end)
        if not ok then
            setStatus("JSON encode failed.", false)
            return
        end
        jsonBox.Text = json
        if setclipboard then
            pcall(setclipboard, json)
            setStatus(string.format("Exported %d blocks + copied.", #bp.blocks))
        else
            setStatus(string.format("Exported %d blocks.", #bp.blocks))
        end
    end)
end)

buildButton.MouseButton1Click:Connect(function()
    if state.busy then
        setStatus("A build is already running.", false)
        return
    end
    local text = jsonBox.Text
    if text == "" then
        setStatus("Paste or load a blueprint first.", false)
        return
    end

    local ok, bp = pcall(function()
        return HttpService:JSONDecode(text)
    end)
    if not ok then
        setStatus("Invalid JSON.", false)
        return
    end

    task.spawn(function()
        local success, message = buildBlueprint(bp, function(i, total, placed, failed)
            setStatus(string.format("%d/%d • placed %d • failed %d", i, total, placed, failed), failed == 0)
        end)
        setStatus(message, success)
        notify(message)
    end)
end)

saveButton.MouseButton1Click:Connect(function()
    if jsonBox.Text == "" then
        setStatus("Nothing to save.", false)
        return
    end
    local ok, result = saveBlueprintFile(nameBox.Text, jsonBox.Text)
    setStatus(ok and ("Saved: " .. result) or result, ok)
end)

loadButton.MouseButton1Click:Connect(function()
    local contentText, result = loadBlueprintFile(nameBox.Text)
    if not contentText then
        setStatus(result, false)
        return
    end
    jsonBox.Text = contentText
    setStatus("Loaded: " .. result)
end)

cancelButton.MouseButton1Click:Connect(function()
    if not state.busy then
        setStatus("Nothing is running.", false)
        return
    end
    state.cancel = true
    setStatus("Cancelling...")
end)

notify("Loaded. No key required.")
setStatus("Ready • no key required")
