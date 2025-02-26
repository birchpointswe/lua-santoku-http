





local http = require("socket.http")
local ltn12 = require("ltn12")
local json = require("cjson")
local str = require("santoku.string")
local arr = require("santoku.array")
local asy = require("santoku.async")
local sys = require("santoku.system")
local varg = require("santoku.varg")
local rand = require("santoku.random")
local err = require("santoku.error")

local M = {}

local reqs = {}

local function fetch_request (req)
  local url, method, headers = req.url, req.method, req.headers
  local body, params
  if method == "GET" and req.qstr then
    url = url .. req.qstr
  end
  if method == "GET" and req.params then
    params = req.params
  end
  if method == "POST" and req.body then
    body = json.encode(req.body)
  end
  return M.fetch(url, {
    method = method,
    headers = headers,
    body = body,
    params = params,
  }, req)
end


M.request = function (url, opts, done, retry)
  if url and reqs[url] then
    return url
  end
  local req = {}
  reqs[req] = true
  if type(opts) == "function" then
    done, retry = opts, done
    opts = nil
  end
  if type(url) ~= "string" then
    req.method = url.method
    req.url = url.url
    req.body = url.body
    req.params = url.params
    req.headers = url.headers
    req.done = done or url.done
    req.retry = retry or url.retry
  elseif opts then
    req.method = opts.method
    req.body = opts.body
    req.params = opts.params
    req.headers = opts.headers
    req.done = done or opts.done
    req.retry = retry or opts.retry
  end
  req.url = url
  req.qstr = req.params and str.to_query(req.params) or ""
  req.done = req.done or done or err.checkok
  req.events = asy.events()
  req.retry = req.retry == nil and {} or req.retry
  if req.retry then
    local retry = type(req.retry) == "table" and req.retry or {}
    local times = retry.times or 3
    local backoff = retry.backoff or 1
    local multiplier = retry.multiplier or 3
    local filter = retry.filter or function (ok, resp)
      local s = resp and resp.status

      return not ok and (s == 502 or s == 503 or s == 504 or s == 429)
    end
    req.events.on("response", function (k, ...)
      if times > 0 and filter(...) then

        sys.sleep(backoff + (backoff * rand.num()))
        times = times - 1
        backoff = backoff * multiplier
        return fetch_request(req)
      else
        return k(...)
      end
    end, true)
  end
  return req
end

M.fetch = function (url, opts, req)

  return varg.tup(function (...)

    if req.events then
      return req.events.process("response", nil, req.done, ...)
    else
      return req.done(...)
    end

  end, err.pcall(function ()

    local chunks = {}

    local _, status, headers = err.checknil(http.request({
      url = url,
      method = opts.method,
      headers = opts.headers,
      sink = ltn12.sink.table(chunks),
      source = opts.body and ltn12.source.string(opts.body) or nil
    }))

    local body = arr.concat(chunks)

    if headers then
      local headers0 = {}
      for k, v in pairs(headers) do
        headers0[str.lower(k)] = v
      end
      headers = headers0
    end

    local ct = headers and headers["content-type"]
    ct = ct and str.lower(ct)

    if ct and str.find(ct, "application/json") and body then
      body = json.decode(body)
    end

    return {
      ok = status >= 200 and status < 300,
      status = status,
      headers = headers,
      body = body
    }

  end))
end

M.req = function (...)
  local req = M.request(...)
  req.method = req.method or "GET"
  return fetch_request(req)
end

M.get = function (...)
  local req = M.request(...)
  req.method = "GET"
  return fetch_request(req)
end

M.post = function (...)
  local req = M.request(...)
  req.method = "POST"
  req.headers = req.headers or {}
  req.headers["content-type"] = req.headers["content-type"] or "application/json"
  return fetch_request(req)
end

local intercept = function (fn, events)
  return function (...)
    return events.process("request", nil, function (req0)
      req0.events.on("response", function (done0, ok0, ...)
        return events.process("response", function (done1, ok1, req1, ...)
          if ok1 == "retry" then
            return fn(req0)
          else
            return done1(ok1, req1, ...)
          end
        end, function (ok2, _, ...)
          return done0(ok2, ...)
        end, ok0, req0, ...)
      end, true)
      return fn(req0)
    end, M.request(...))
  end
end



M.client = function ()
  local events = asy.events()
  return {
    on = events.on,
    off = events.off,
    req = intercept(M.req, events),
    get = intercept(M.get, events),
    post = intercept(M.post, events)
  }
end

return M
