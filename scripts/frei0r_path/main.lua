-- Written for https://github.com/qwerty12/mpv-winbuild

local utils = require 'mp.utils'
local ffi = require 'ffi'
ffi.cdef[[
unsigned long __stdcall GetModuleFileNameW(void *hModule, wchar_t *lpFilename, unsigned long nSize);
int __stdcall MultiByteToWideChar(unsigned int CodePage, unsigned long dwFlags, const char *lpMultiByteStr, int cbMultiByte, wchar_t *lpWideCharStr, int cchWideChar);
int __stdcall WideCharToMultiByte(unsigned int CodePage, unsigned long dwFlags, const wchar_t *lpWideCharStr, int cchWideChar, char *lpMultiByteStr, int cbMultiByte, const char *lpDefaultChar, bool *lpUsedDefaultChar);
int _wputenv_s(const wchar_t *name, const wchar_t *value);
]]

local function WideCharToMultiByte(WideCharStr)
    if WideCharStr then
        local utf8_size = ffi.C.WideCharToMultiByte(65001, 0, WideCharStr, -1, nil, 0, nil, nil) --CP_UTF8
        if utf8_size > 0 then
            local utf8_path = ffi.new("char[?]", utf8_size)
            local utf8_size = ffi.C.WideCharToMultiByte(65001, 0, WideCharStr, -1, utf8_path, utf8_size, nil, nil)
            if utf8_size > 0 then
                return ffi.string(utf8_path, utf8_size)
            end
        end
    end

    return nil
end

local function MultiByteToWideChar(MultiByteStr)
    if MultiByteStr then
        local utf16_len = ffi.C.MultiByteToWideChar(65001, 0, MultiByteStr, -1, nil, 0)
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

local function calc_mpv_path()
    -- 'cause expand-path ~~exe_dir doesn't work

    local w_exedir = ffi.new("wchar_t[261]")
    local len = ffi.C.GetModuleFileNameW(nil, w_exedir, 260) --MAX_PATH
    if len ~= 0 then
        local exedir = WideCharToMultiByte(w_exedir)
        if exedir then
            return utils.split_path(exedir)
        end
    end

    return nil
end

local function append_frei0r_path(base, frei0r)
    if base and frei0r then
        local ret = utils.join_path(base, frei0r)
        local fi = utils.file_info(ret)
        if fi ~= nil and fi.is_dir then
            return ret
        end
    end

    return nil
end

local function setenv_utf8(name, value)
    if name and value then
        local name = MultiByteToWideChar(name)
        local value = MultiByteToWideChar(value)
        if name ~= nil and value ~= nil then
            return ffi.C._wputenv_s(name, value) == 0
        end
    end

    return false
end

for _, dir in ipairs({calc_mpv_path(), mp.get_script_directory()}) do
    local fr_dir = append_frei0r_path(dir, "frei0r-1")
    if fr_dir then
        setenv_utf8("FREI0R_PATH", fr_dir)
        break
    end
end
