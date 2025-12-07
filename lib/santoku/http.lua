local async = require("santoku.async")
local str = require("santoku.string")
local rand = require("santoku.random")

return function (backend)
  local events = async.events()

  local function do_fetch (url, opts, done)
    return events.process("request", nil, function (url0, opts0)
      return backend.fetch(url0, opts0, function (ok, resp)
        return events.process("response", nil, done, ok, resp)
      end)
    end, url, opts)
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
    return function (url, opts0, done)
      local attempt
      attempt = function ()
        return fetch_fn(url, opts0, function (ok, resp)
          if times > 0 and filter(ok, resp) then
            times = times - 1
            local delay = backoff + (backoff * rand.num())
            backoff = backoff * multiplier
            return backend.sleep(delay, attempt)
          else
            return done(ok, resp)
          end
        end)
      end
      return attempt()
    end
  end

  local function fetch (url, opts, done)
    opts = opts or {}
    done = done or opts.done
    local fetcher = with_retry(do_fetch, opts)
    return fetcher(url, opts, done)
  end

  local function get (url, opts, done)
    opts = opts or {}
    opts.method = "GET"
    if opts.params then
      url = url .. str.to_query(opts.params)
    end
    return fetch(url, opts, done)
  end

  local function post (url, opts, done)
    opts = opts or {}
    opts.method = "POST"
    return fetch(url, opts, done)
  end

  return {
    on = events.on,
    off = events.off,
    fetch = fetch,
    get = get,
    post = post
  }
end
