--[[pod_format="raw",created="2024-05-01 05:10:49",modified="2024-06-09 19:10:49",revision=183]]
local _modules = {}

function loadfile (filename)
  local src = fetch(filename)

  if (type(src) ~= "string") then
    notify("could not include "..filename)
    stop()
    return
  end

  -- https://www.lua.org/manual/5.4/manual.html#pdf-load
  -- chunk name (for error reporting), mode ("t" for text only -- no binary chunk loading), _ENV upvalue
  -- @ is a special character that tells debugger the string is a filename
  local func,err = load(src, "@"..filename, "t", _ENV)
  -- syntax error while loading
  if (not func) then
    send_message(3, {event="report_error", content = "*syntax error"})
    send_message(3, {event="report_error", content = tostr(err)})

    stop()
    return
  end
  return func
end

function require(name)
  local already_imported = _modules[name]
  if already_imported ~= nil then
    return already_imported
  end
  _modules[name] = true

  local filename = fullpath(name:gsub ('%.', '/') ..'.lua')

  local func = loadfile (filename)

  local module = func(name)
  _modules[name]=module

  return module
end