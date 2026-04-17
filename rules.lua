local Rules = {
  PVP = false,
  SWAMP = false,
}

function Rules:setPvp(enabled)
  self.PVP = enabled == true
end

function Rules:setSwamp(enabled)
  self.SWAMP = enabled == true
end

return Rules
