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
end)

test("post", function ()
  print(serialize({http.get("http://localhost:8000/test", {
    body = { a = 1, b = "2", c = nil, d = true },
    headers = { ["x-test-something"] = "this is a header" }
  }, function (...)
    print(serialize({...}))
    return ...
  end)}))
end)
