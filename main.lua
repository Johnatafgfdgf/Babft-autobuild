-- Babft-Autobuild
-- Clean-room, keyless loader.

local PLACE_ID = 537413528
local RAW_BASE = "https://raw.githubusercontent.com/Johnatafgfdgf/Babft-autobuild/main/"

if game.PlaceId ~= PLACE_ID then
    warn("[Babft-Autobuild] This loader is intended for Build A Boat For Treasure.")
    return
end

local ok, source = pcall(function()
    return game:HttpGet(RAW_BASE .. "src/autobuild.lua")
end)

if not ok or type(source) ~= "string" or #source < 10 then
    warn("[Babft-Autobuild] Failed to download src/autobuild.lua")
    return
end

local chunk, compileError = loadstring(source)
if not chunk then
    warn("[Babft-Autobuild] Compile error: " .. tostring(compileError))
    return
end

local success, runtimeError = pcall(chunk)
if not success then
    warn("[Babft-Autobuild] Runtime error: " .. tostring(runtimeError))
end
