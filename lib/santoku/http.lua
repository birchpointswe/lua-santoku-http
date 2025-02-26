





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

local function fetch (url, opts, req)

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
    }, {
      url = url,
      method = opts.method,
      headers = opts.headers,
      body = req.body,
    }
  end))
end

M.fetch = function (req)
  local url, method, headers = req.url, req.method, req.headers
  local body, params
  if method == "GET" and req.qstr then
    url = url .. req.qstr
  end
  if method == "GET" and req.params then
    params = req.params
  end
  if method == "POST" and req.body_encoded then
    body = req.body_encoded
  end
  return fetch(url, {
    method = method,
    headers = headers,
    body = body,
    params = params,
  }, req)
end


M.request = function (...)

  local method, url, opts, done = ...
  if method and reqs[method] then
    return method
  end

  local n = varg.len(...)


  if n == 0 then
    return
  elseif n == 1 then
    url = method
    method = nil
    opts = nil
    done = nil
  elseif type(method) ~= "string" then
    opts, done = method, url
    method, url = nil, nil
  elseif type(url) ~= "string" then
    url, opts, done = method, url, opts
    method = nil
  end
  if type(opts) == "function" then
    done = opts
    opts = nil
  end

  opts = opts or {}

  local req = {}
  reqs[req] = true

  req.method = method or opts.method or "GET"
  req.url = url or opts.url
  req.done = done or opts.done or err.checkok

  req.body = opts.body
  req.params = opts.params
  req.headers = opts.headers
  req.qstr = req.params and str.to_query(req.params) or ""

  if req.method == "POST" then
    if req.body and type(req.body) == "table" then
      req.headers = req.headers or {}
      req.headers["content-type"] = req.headers["content-type"] or "application/json"
      req.body_encoded = json.encode(req.body)
    end
  end

  req.events = asy.events()
  req.retry = opts.retry == nil and {} or req.retry

  if req.retry then
    local retry = type(req.retry) == "table" and req.retry or {}
    local times = retry.times or 3
    local backoff = retry.backoff or 1
    local multiplier = retry.multiplier or 3
    local filter = retry.filter or function (ok, resp)
      local s = ok and resp and resp.status

      return ok and (s == 502 or s == 503 or s == 504 or s == 429)
    end
    req.events.on("response", function (k, ...)
      if times > 0 and filter(...) then

        sys.sleep(backoff + (backoff * rand.num()))
        times = times - 1
        backoff = backoff * multiplier
        return M.fetch(req)
      else
        return k(...)
      end
    end, true)
  end
  return req
end

M.get_request = function (...)
  return M.request("GET", ...)
end

M.post_request = function (...)
  return M.request("GET", ...)
end

M.req = function (...)
  return M.fetch(M.request(...))
end

M.get = function (...)
  return M.fetch(M.get_request(...))
end

M.post = function (...)
  return M.fetch(M.post_request(...))
end

local intercept = function (req, events)
  return function (...)
    return events.process("request", nil, function (req0)
      req0.events.on("response", function (done0, ok0, ...)
        return events.process("response", function (done1, ok1, req1, ...)
          if ok1 == "retry" then
            return M.fetch(req0)
          else
            return done1(ok1, req1, ...)
          end
        end, function (ok2, _, ...)
          return done0(ok2, ...)
        end, ok0, req0, ...)
      end, true)
      return M.fetch(req0)
    end, req(...))
  end
end



M.client = function ()
  local events = asy.events()
  return {
    on = events.on,
    off = events.off,
    req = intercept(M.request, events),
    get = intercept(M.get_request, events),
    post = intercept(M.post_request, events)
  }
end

return M
