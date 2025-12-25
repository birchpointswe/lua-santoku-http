local async = require("santoku.async")
local str = require("santoku.string")
local rand = require("santoku.random")

return function (backend)
  local events = async.events()

  local function do_fetch (url, opts)
    url, opts = events.process("request", nil, url, opts)
    local ok, resp = backend.fetch(url, opts)
    return events.process("response", nil, ok, resp)
  end

  local function with_retry (fetch_fn, opts)
    local retry = opts.retry == nil and {} or opts.retry
    if not retry then
      return fetch_fn
    end
    retry = type(retry) == "table" and retry or {}
    local times = retry.times or 3
    local backoff = retry.backoff or 1000
    local multiplier = retry.multiplier or 3
    local filter = retry.filter or function (_, resp)
      local s = resp and resp.status
      if not s or s == 0 then return true end
      return s == 502 or s == 503 or s == 504 or s == 429
    end
    return function (url0, opts0)
      while times > 0 do
        local ok, resp = fetch_fn(url0, opts0)
        if not filter(ok, resp) then
          return ok, resp
        end
        times = times - 1
        local delay = backoff + (backoff * rand.num())
        backoff = backoff * multiplier
        backend.sleep(delay)
      end
      return fetch_fn(url0, opts0)
    end
  end

  local function fetch (url, opts)
    opts = opts or {}
    local fetcher = with_retry(do_fetch, opts)
    return fetcher(url, opts)
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
