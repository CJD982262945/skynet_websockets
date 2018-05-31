local M = {}

local function trim(x)
  return x & 0xffffffff
end

function M.band(a, b)
  return trim(a & b)
end

function M.bxor(a, b)
  return trim(a ~ b)
end

function M.bor(a, b)
  return trim(a | b)
end

function M.rshift(a, b)
  return trim(a >> b)
end

local function rotate(a, b)
  local r = trim(a)
  local i = b % (31) -- i = b % nbits (32)
  if i ~= 0 then
    r = r << i | (r >> 31)
  end
  return trim(r)
end

function M.rol(x, disp)
  return rotate(x, disp)
end

function M.ror(x, disp)
  return rotate(x, -disp)
end

function M.bnot(a)
  return trim(~ a)
end

function M.lshift(a, b)
  return trim(a << b)
end

return M
