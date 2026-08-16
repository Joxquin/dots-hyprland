-- This file sources other files in `hyprland` and `custom` folders
-- You wanna add your stuff in files in `custom`

-- Internal stuff --
require("hyprland.lib")
require("hyprland.services")

if HOME then
    package.path = package.path .. ";" .. HOME .. "/.config/hypr/?.lua;" .. HOME .. "/.config/hypr/?/init.lua"
end

-- Environment variables --
require("hyprland.env")
if is_file_exists(HOME .. "/.config/hypr/custom/env.lua") then
    dofile(HOME .. "/.config/hypr/custom/env.lua")
end

-- Default configurations --
require("hyprland.execs")
require("hyprland.general")
require("hyprland.rules")
require("hyprland.colors")
require("hyprland.keybinds")

-- Custom configurations --
if is_file_exists(HOME .. "/.config/hypr/custom/execs.lua") then
    dofile(HOME .. "/.config/hypr/custom/execs.lua")
end
if is_file_exists(HOME .. "/.config/hypr/custom/general.lua") then
    dofile(HOME .. "/.config/hypr/custom/general.lua")
end
if is_file_exists(HOME .. "/.config/hypr/custom/rules.lua") then
    dofile(HOME .. "/.config/hypr/custom/rules.lua")
end
if is_file_exists(HOME .. "/.config/hypr/custom/keybinds.lua") then
    dofile(HOME .. "/.config/hypr/custom/keybinds.lua")
end

-- nwg-displays support --
if is_file_exists(HOME .. "/.config/hypr/workspaces.lua") then
    dofile(HOME .. "/.config/hypr/workspaces.lua")
end
if is_file_exists(HOME .. "/.config/hypr/monitors.lua") then
    dofile(HOME .. "/.config/hypr/monitors.lua")
end

-- Shell overrides --
require("hyprland.shellOverrides.main")
