--[[--
Font module.
]]

local lfs = require("libs/libkoreader-lfs")
local Freetype = require("ffi/freetype")
local Screen = require("device").screen
local Device = require("device")
local DEBUG = require("dbg")

local Font = {
    fontmap = {
        -- default font for menu contents
        cfont = "noto/NotoSans-Regular.ttf",
        -- default font for title
        --tfont = "NimbusSanL-BoldItal.cff",
        tfont = "noto/NotoSans-Bold.ttf",
        -- default font for footer
        ffont = "noto/NotoSans-Regular.ttf",

        -- default font for reading position info
        rifont = "noto/NotoSans-Regular.ttf",

        -- default font for pagination display
        pgfont = "noto/NotoSans-Regular.ttf",

        -- selectmenu: font for item shortcut
        scfont = "droid/DroidSansMono.ttf",

        -- help page: font for displaying keys
        hpkfont = "droid/DroidSansMono.ttf",
        -- font for displaying help messages
        hfont = "noto/NotoSans-Regular.ttf",

        -- font for displaying input content
        -- we have to use mono here for better distance controlling
        infont = "droid/DroidSansMono.ttf",

        -- font for info messages
        infofont = "noto/NotoSans-Regular.ttf",
    },
    sizemap = {
        cfont = 24,
        tfont = 26,
        ffont = 20,
        pgfont = 20,
        scfont = 20,
        rifont = 16,
        hpkfont = 20,
        hfont = 24,
        infont = 22,
        infofont = 24,
    },
    fallbacks = {
        [1] = "noto/NotoSansCJK-Regular.ttf",
        [2] = "noto/NotoSans-Regular.ttf",
        [3] = "freefont/FreeSans.ttf",
    },

    fontdir = "./fonts",

    -- face table
    faces = {},
}

function Font:getFace(font, size)
    -- default to content font
    if not font then font = self.cfont end

    if not size then size = self.sizemap[font] end
    -- original size before scaling by screen DPI
    local orig_size = size
    size = Screen:scaleBySize(size)

    local hash = font..size
    local face_obj = self.faces[hash]
    -- build face if not found
    if not face_obj then
        local realname = self.fontmap[font]
        if not realname then
            realname = font
        end
        realname = self.fontdir.."/"..realname
        local ok, face = pcall(Freetype.newFace, realname, size)
        if not ok then
            DEBUG("#! Font "..font.." ("..realname..") not supported: "..face)
            return nil
        end
        --- Freetype font face wrapper object
        -- @table FontFaceObj
        -- @field size size of the font face (after scaled by screen size)
        -- @field orig_size raw size of the font face (before scale)
        -- @field ftface font face object from freetype
        -- @field hash hash key for this font face
        face_obj = {
            size = size,
            orig_size = orig_size,
            ftface = face,
            hash = hash
        }
        self.faces[hash] = face_obj
    end
    return face_obj
end

--[[
    These fonts from Kindle system cannot be loaded by Freetype.
--]]
local kindle_fonts_blacklist = {
    ["HYGothicBold.ttf"] = true,
    ["HYGothicMedium.ttf"] = true,
    ["HYMyeongJoBold.ttf"] = true,
    ["HYMyeongJoMedium.ttf"] = true,
    ["MYingHeiTBold.ttf"] = true,
    ["MYingHeiTMedium.ttf"] = true,
    ["SongTBold.ttf"] = true,
    ["SongTMedium.ttf"] = true,
}

local function isInFontsBlacklist(f)
    if Device:isKindle() then
        return kindle_fonts_blacklist[f]
    end
end

function Font:_readList(target, dir)
    -- lfs.dir non-exsitent directory will give error, weird!
    local ok, iter, dir_obj = pcall(lfs.dir, dir)
    if not ok then return end
    for f in iter, dir_obj do
        if lfs.attributes(dir.."/"..f, "mode") == "directory" and f ~= "." and f ~= ".." then
            self:_readList(target, dir.."/"..f)
        else
            local file_type = string.lower(string.match(f, ".+%.([^.]+)") or "")
            if file_type == "ttf" or file_type == "ttc"
                or file_type == "cff" or file_type == "otf" then
                if not isInFontsBlacklist(f) then
                    table.insert(target, dir.."/"..f)
                end
            end
        end
    end
end

function Font:_getExternalFontDir()
    if Device:isAndroid() then
        return ANDROID_FONT_DIR
    else
        return os.getenv("EXT_FONT_DIR")
    end
end

function Font:getFontList()
    local fontlist = {}
    self:_readList(fontlist, self.fontdir)
    -- multiple paths should be joined with semicolon
    for dir in string.gmatch(self:_getExternalFontDir() or "", "([^;]+)") do
        self:_readList(fontlist, dir)
    end
    table.sort(fontlist)
    return fontlist
end

return Font
