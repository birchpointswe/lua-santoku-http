local test = require("santoku.test")
local http = require("santoku.http")
local serialize = require("santoku.serialize")

test("get", function ()
  print(serialize({http.get("http://localhost:8000/test.json", {
    params = { a = 1, b = "2", c = nil, d = true },
    headers = { ["x-test-something"] = "this is a header" }
  }, function (...)
    print(serialize({...}))
    return ...
  end)}))
  print(serialize({http.get("http://localhost:8000/test.json", function (...)
    print(serialize({...}))
    return ...
  end)}))
end)

test("post", function ()
  print(serialize({http.get("http://localhost:8000/test", {
    body = { a = 1, b = "2", c = nil, d = true },
    headers = { ["x-test-something"] = "this is a header" }
  }, function (...)
    print(serialize({...}))
    return ...
  end)}))
  print(serialize({http.get("http://localhost:8000/test", function (...)
    print(serialize({...}))
    return ...
  end)}))
end)


local sys = require("santoku.system")
local utc = require("santoku.utc")
local client = http.client()

local last
client.on("request", function (done, req)
  local now = utc.time(true)
  if not last then
    last = now
    return done(req)
  else
    local diff = now - last
    if diff > 5 then
      sys.sleep(diff - 5)
      last = utc.time(true)
    end
    return done(req)
  end
end, true)

for _ = 1, 100 do
  client.get("http://localhost:8000/test", function (...)
    print(serialize({...}))
  end)
end
