local test = require("santoku.test")
local http = require("santoku.http")

local err = require("santoku.error")
local assert = err.assert

local validate = require("santoku.validate")
local eq = validate.isequal



local function mock (responses)
  local i = 0
  local fetched = {}
  local slept = 0
  local backend = {
    fetch = function (url, opts)
      i = i + 1
      fetched[#fetched + 1] = { url = url, opts = opts }
      local r = responses[i] or responses[#responses]
      return r.ok, r.resp
    end,
    sleep = function ()
      slept = slept + 1
    end,
  }
  return backend, function () return i, slept, fetched end
end

test("get returns a response", function ()
  local backend, stats = mock({ { ok = true, resp = { status = 200, body = "hi" } } })
  local client = http(backend)
  local ok, resp = client.get("http://x/")
  assert(eq(true, ok))
  assert(eq(200, resp.status))
  assert(eq("hi", resp.body))
  local calls = stats()
  assert(eq(1, calls))
end)

test("get builds a query string from params", function ()
  local backend = mock({ { ok = true, resp = { status = 200 } } })
  local fetched
  backend.fetch = (function (orig)
    return function (url, opts)
      fetched = url
      return orig(url, opts)
    end
  end)(backend.fetch)
  local client = http(backend)
  client.get("http://x/", { params = { a = 1 } })
  assert(eq("http://x/?a=1", fetched))
end)

test("retries then succeeds", function ()
  local backend, stats = mock({
    { ok = false, resp = { status = 503 } },
    { ok = false, resp = { status = 503 } },
    { ok = true, resp = { status = 200 } },
  })
  local client = http(backend)
  local ok, resp = client.get("http://x/")
  assert(eq(true, ok))
  assert(eq(200, resp.status))
  local calls, slept = stats()
  assert(eq(3, calls))
  assert(eq(2, slept))
end)

test("retry = false disables retry", function ()
  local backend, stats = mock({
    { ok = false, resp = { status = 503 } },
    { ok = true, resp = { status = 200 } },
  })
  local client = http(backend)
  local ok, resp = client.get("http://x/", { retry = false })
  assert(eq(false, ok))
  assert(eq(503, resp.status))
  local calls, slept = stats()
  assert(eq(1, calls))
  assert(eq(0, slept))
end)

test("request and response hooks rewrite url/opts/resp", function ()
  local backend, _ = mock({ { ok = true, resp = { status = 200, body = "raw" } } })
  local seen_url
  backend.fetch = (function (orig)
    return function (url, opts)
      seen_url = url
      return orig(url, opts)
    end
  end)(backend.fetch)
  local client = http(backend)
  client.on("request", function (k, url, opts)
    return k(url .. "?tagged=1", opts)
  end, true)
  client.on("response", function (k, ok, resp)
    resp.body = "rewritten"
    return k(ok, resp)
  end, true)
  local ok, resp = client.get("http://x/")
  assert(eq("http://x/?tagged=1", seen_url))
  assert(eq(true, ok))
  assert(eq("rewritten", resp.body))
end)

test("cancelable request short-circuits with the canceled sentinel", function ()
  local backend, stats = mock({ { ok = true, resp = { status = 200 } } })
  local client = http(backend)
  local req = client.fetch("http://x/", { cancelable = true })
  req.cancel()
  local ok, resp = req.await()
  assert(eq(false, ok))
  assert(eq(0, resp.status))
  assert(eq(true, resp.canceled))
  local calls = stats()
  assert(eq(0, calls))
end)
