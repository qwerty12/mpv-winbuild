-- Written for https://github.com/qwerty12/mpv-winbuild

local utils = require 'mp.utils'
local ffi = require 'ffi'
ffi.cdef[[
unsigned int GetModuleFileNameW(void *hModule, wchar_t *lpFilename, unsigned int nSize);
int MultiByteToWideChar(unsigned int CodePage, unsigned int dwFlags, const char *lpMultiByteStr, int cbMultiByte, wchar_t *lpWideCharStr, int cchWideChar);
int WideCharToMultiByte(unsigned int CodePage, unsigned int dwFlags, const wchar_t *lpWideCharStr, int cchWideChar, char *lpMultiByteStr, int cbMultiByte, const char *lpDefaultChar, bool *lpUsedDefaultChar);
bool SetEnvironmentVariableW(const wchar_t *lpName, const wchar_t *lpValue);
]]

local function calc_mpv_path()
    -- 'cause expand-path ~~exe_dir doesn't work

    local w_exedir = ffi.new("wchar_t[261]")
    local len = ffi.C.GetModuleFileNameW(NULL, w_exedir, 260) --MAX_PATH
    if len ~= 0 then
        local utf8_size = ffi.C.WideCharToMultiByte(65001, 0, w_exedir, -1, NULL, 0, NULL, NULL) --CP_UTF8
        if utf8_size > 0 then
            local utf8_path = ffi.new("char[?]", utf8_size)
            local utf8_size = ffi.C.WideCharToMultiByte(65001, 0, w_exedir, -1, utf8_path, utf8_size, NULL, NULL)
            if utf8_size > 0 then
                return utils.split_path(ffi.string(utf8_path, utf8_size))
            end
        end
    end

    return ""
end

local function append_frei0r_path(base, frei0r)
    if base and frei0r then
        local ret = utils.join_path(base, frei0r)
        local fi = utils.file_info(ret)
        if fi ~= nil and fi.is_dir then
            return ret
        end
    end

    return ""
end

local function MultiByteToWideChar(MultiByteStr)
    if MultiByteStr then
        local utf16_len = ffi.C.MultiByteToWideChar(65001, 0, MultiByteStr, -1, NULL, 0)
        if utf16_len > 0 then
            --utf16_len = utf16_len + 1
            local utf16_str = ffi.new("wchar_t[?]", utf16_len)
            if ffi.C.MultiByteToWideChar(65001, 0, MultiByteStr, -1, utf16_str, utf16_len) > 0 then
                return utf16_str
            end
        end
    end

    return nil
end

local function setenv_utf8(name, value)
    if name and value then
        local name = MultiByteToWideChar(name)
        local value = MultiByteToWideChar(value)
        if name ~= nil and value ~= nil then
            return ffi.C.SetEnvironmentVariableW(name, value)
        end
    end

    return false
end

setenv_utf8("FREI0R_PATH", append_frei0r_path(calc_mpv_path(), "frei0r-1"))