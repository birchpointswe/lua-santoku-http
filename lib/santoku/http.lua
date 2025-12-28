local async = require("santoku.async")
local str = require("santoku.string")
local rand = require("santoku.random")

return function (backend)
  local events = async.events()

  local function do_request (url, opts)
    local req_url, req_opts
    events.process("request", nil, function (u, o)
      req_url, req_opts = u, o
    end, url, opts)
    if backend.request then
      local req = backend.request(req_url, req_opts)
      return {
        cancel = req.cancel,
        await = function ()
          local ok, resp = req.await()
          local res_ok, res_resp
          events.process("response", nil, function (o, r)
            res_ok, res_resp = o, r
          end, ok, resp)
          return res_ok, res_resp
        end
      }
    else
      return {
        cancel = function () end,
        await = function ()
          local ok, resp = backend.fetch(req_url, req_opts)
          local res_ok, res_resp
          events.process("response", nil, function (o, r)
            res_ok, res_resp = o, r
          end, ok, resp)
          return res_ok, res_resp
        end
      }
    end
  end

  local function create_request (url, opts)
    local retry = opts.retry == nil and {} or opts.retry
    local times = retry and (retry.times or 3) or 0
    local backoff = retry and (retry.backoff or 1000) or 0
    local multiplier = retry and (retry.multiplier or 3) or 1
    local filter = retry and (retry.filter or function (_, resp)
      local s = resp and resp.status
      if not s or s == 0 then return true end
      return s == 502 or s == 503 or s == 504 or s == 429
    end) or function () return false end

    local canceled = false
    local current_req = nil

    return {
      cancel = function ()
        canceled = true
        if current_req then current_req.cancel() end
      end,
      await = function ()
        local attempts = 0
        while attempts <= times do
          if canceled then
            return false, { status = 0, canceled = true }
          end
          current_req = do_request(url, opts)
          local ok, resp = current_req.await()
          current_req = nil
          if canceled or (resp and resp.canceled) then
            return false, { status = 0, canceled = true }
          end
          if not filter(ok, resp) then
            return ok, resp
          end
          attempts = attempts + 1
          if attempts <= times then
            local delay = backoff + (backoff * rand.num())
            backoff = backoff * multiplier
            backend.sleep(delay)
            if canceled then
              return false, { status = 0, canceled = true }
            end
          end
        end
        current_req = do_request(url, opts)
        local ok, resp = current_req.await()
        current_req = nil
        return ok, resp
      end
    }
  end

  local function fetch (url, opts)
    opts = opts or {}
    if opts.cancelable then
      return create_request(url, opts)
    end
    return create_request(url, opts).await()
  end

  local function get (url, opts)
    opts = opts or {}
    opts.method = "GET"
    if opts.params then
      url = url .. str.to_query(opts.params)
    end
    return fetch(url, opts)
  end

  local function post (url, opts)
    opts = opts or {}
    opts.method = "POST"
    return fetch(url, opts)
  end

  return {
    on = events.on,
    off = events.off,
    fetch = fetch,
    get = get,
    post = post
  }
end
