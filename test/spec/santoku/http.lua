local test = require("santoku.test")
local http = require("santoku.http")
local serialize = require("santoku.serialize")





























test("client.get", function ()
  local client = http.client()
  client.on("request", function (k, r)
    return k(r)
  end, true)
  print(serialize(client.get("http://localhost:8000/test.json", function (...)
    local resp = require("santoku.error").checkok(...)
    return resp
  end)))




end)
