local function hasFlag(flag)
  local argv = rawget(_G, "arg")
  if type(argv) ~= "table" then
    return false
  end

  for _, value in pairs(argv) do
    if value == flag then
      return true
    end
  end

  return false
end

local Rules = {
  PVP = hasFlag("--pvp"),
}

return Rules
