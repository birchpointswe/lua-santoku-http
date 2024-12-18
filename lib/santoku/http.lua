local http = require("socket.http")
local ltn12 = require("ltn12")
local arr = require("santoku.array")
local err = require("santoku.error")

local function request (opts)
  local chunks = {}
  local _, status, headers = err.checknil(http.request({
    method = opts.method,
    url = opts.url,
    headers = opts.headers,
    sink = ltn12.sink.table(chunks),
    source = ltn12.source.string(opts.body)
  }))
  local body = arr.concat(chunks)
  return {
    status = status,
    headers = headers,
    body = body
  }
end

return {
  request = request
}
