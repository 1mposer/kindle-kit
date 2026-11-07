--[[
kindle-kit: one-time reading setup.

Runs once on the next KOReader start, then sets a flag and never touches your
settings again. Change anything afterwards in the menus as usual.
To run it again, delete "kindlekit_setup_v1" from settings.reader.lua.
--]]
local KEY = "kindlekit_setup_v1"
local S = G_reader_settings
if not S or S:isTrue(KEY) then return end

local lfs = require("libs/libkoreader-lfs")
local DataStorage = require("datastorage")
local data = DataStorage:getDataDir()
local function isdir(p) return lfs.attributes(p, "mode") == "directory" end
local function isfile(p) return lfs.attributes(p, "mode") == "file" end

-- Library view: Project: Title replaces Cover browser.
if isdir(data .. "/plugins/projecttitle.koplugin") then
    local pd = S:readSetting("plugins_disabled") or {}
    pd.coverbrowser = true
    pd.projecttitle = nil
    S:saveSetting("plugins_disabled", pd)
end

-- The library is the home screen.
local lib = "/mnt/us/documents/Library"
if isdir(lib) then
    S:saveSetting("home_dir", lib)
    S:saveSetting("lastdir", lib)
    S:saveSetting("start_with", "filemanager")
    S:makeTrue("lock_home_folder")
end
-- "Continue reading" should not point at the KOReader launcher script.
local last = S:readSetting("lastfile")
if type(last) == "string" and last:match("%.sh$") then
    S:delSetting("lastfile")
end

-- Sleep screen: a random picture from /mnt/us/screensavers.
if isdir("/mnt/us/screensavers") then
    S:saveSetting("screensaver_type", "random_image")
    S:saveSetting("screensaver_dir", "/mnt/us/screensavers")
end

-- Typography for new books: Literata, a little more air.
if isfile(data .. "/fonts/literata/Literata-Regular.ttf") then
    S:saveSetting("cre_font", "Literata")
end
S:saveSetting("copt_line_spacing", 110)
S:saveSetting("copt_h_page_margins", { 15, 15 })

-- E-ink: flash only at chapter breaks instead of every 6 pages.
S:saveSetting("full_refresh_count", -1)
S:saveSetting("night_full_refresh_count", -1)

-- Quieter status bar, if one exists yet.
local f = S:readSetting("footer")
if type(f) == "table" then
    f.page_progress = false
    f.book_time_to_read = false
    f.chapter_time_to_read = true
    f.pages_left = true
    f.percentage = true
    f.time = true
    f.battery = true
    f.battery_hide_threshold = 25
    f.items_separator = "bullet"
    f.progress_style_thin = true
    f.progress_bar_position = "below"
end

-- Wi-Fi: no prompts, and reconnect after waking (book inbox uses this).
S:saveSetting("wifi_enable_action", "turn_on")
S:saveSetting("wifi_disable_action", "leave_on")
S:makeTrue("auto_restore_wifi")
if isdir(data .. "/plugins/inboxsync.koplugin") then
    S:makeTrue("wifi_was_on")
end

S:makeTrue(KEY)
S:flush()
