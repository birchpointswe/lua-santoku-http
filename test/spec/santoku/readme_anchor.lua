local test = require("santoku.test")

local err = require("santoku.error")
local assert = err.assert

local validate = require("santoku.validate")
local eq = validate.isequal

local http = require("santoku.http")

local function mock (responses)
  local i, slept = 0, 0
  return {
    fetch = function ()
      i = i + 1
      local r = responses[i] or responses[#responses]
      return r.ok, r.resp
    end,
    sleep = function ()
      slept = slept + 1
    end,
  }, function () return i, slept end
end

test("get returns ok plus a response", function ()
  local backend, stats = mock({ { ok = true, resp = { status = 200, body = "hi" } } })
  local ok, resp = http(backend).get("http://x/")
  assert(eq(true, ok))
  assert(eq(200, resp.status))
  assert(eq("hi", resp.body))
  assert(eq(1, stats()))
end)

test("a failed request is retried, sleeping between attempts", function ()
  local backend, stats = mock({
    { ok = false, resp = { status = 503 } },
    { ok = false, resp = { status = 503 } },
    { ok = true, resp = { status = 200 } },
  })
  local ok, resp = http(backend).get("http://x/")
  assert(eq(true, ok))
  assert(eq(200, resp.status))
  local calls, slept = stats()
  assert(eq(3, calls))
  assert(eq(2, slept))
end)

test("hooks wrap every response", function ()
  local backend = mock({ { ok = true, resp = { status = 200, body = "raw" } } })
  local client = http(backend)
  client.on("response", function (k, ok, resp)
    resp.body = "rewritten"
    return k(ok, resp)
  end, true)
  local ok, resp = client.get("http://x/")
  assert(eq(true, ok))
  assert(eq("rewritten", resp.body))
end)

test("a cancelable request short-circuits before it is issued", function ()
  local backend, stats = mock({ { ok = true, resp = { status = 200 } } })
  local req = http(backend).fetch("http://x/", { cancelable = true })
  req.cancel()
  local ok, resp = req.await()
  assert(eq(false, ok))
  assert(eq(true, resp.canceled))
  assert(eq(0, stats()))
end)
