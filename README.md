# santoku-http

A transport-agnostic HTTP client front end for Lua, built on base
[`santoku`](../lua-santoku/README.md) (`santoku.async`, `santoku.string`,
`santoku.random`). It adds query-string building, retry with backoff,
cancellation, and request/response hooks on top of a backend you supply. It
performs no network I/O itself; the backend does that.

This README is a usage guide, not an API reference. The tests are the spec:
`test/spec/santoku/http.lua` exercises the full surface. For
`santoku.async` (events), `santoku.string` (`to_query`), and `santoku.random`,
see the [base `santoku` docs](../lua-santoku/README.md).

## Backend contract

`require("santoku.http")` returns a factory. Call it with one `backend` table:

```lua
local http = require("santoku.http")
local client = http(backend)
```

The backend supplies the transport. Provide one of:

- `backend.fetch(url, opts)` returning `ok, resp` (synchronous style), or
- `backend.request(url, opts)` returning `{ cancel, await }` where `await()`
  returns `ok, resp` (async style; `cancel()` aborts the in-flight request).

It must also provide `backend.sleep(ms)`, used for retry backoff. `resp` is
whatever your backend returns; this library only reads `resp.status` (for the
default retry filter) and `resp.canceled` (to detect a backend-side cancel).

## Returned API

The factory returns `{ fetch, get, post, on, off }`.

- `get(url, opts)` sets `opts.method = "GET"`; if `opts.params` is set it appends
  `str.to_query(opts.params)` to the url (a `?a=1&b=2` string).
- `post(url, opts)` sets `opts.method = "POST"`.
- `fetch(url, opts)` runs the request. With `opts.cancelable` it returns a
  request object `{ cancel, await }`; otherwise it calls `await()` for you and
  returns `ok, resp` directly.
- `on(event, handler, async)` / `off(event, handler)` register hooks on the
  `"request"` and `"response"` events (see Hooks).

```lua
local ok, resp = client.get("http://example/", { params = { q = "x" } })
-- fetches http://example/?q=x  ->  ok, resp from the backend
```

covers: `test/spec/santoku/http.lua` ("get returns a response", "get builds a
query string from params").

## Retry

`opts.retry` controls retry. It defaults to on (an empty table); set
`opts.retry = false` to disable. Fields:

- `times` (default 3): maximum retries after the first attempt.
- `backoff` (default 1000): initial delay passed to `backend.sleep`.
- `multiplier` (default 3): the delay is multiplied by this after each retry.
- `filter(ok, resp)` (default below): return true to retry, false to stop.

The default filter retries when there is no status (`nil`/`0`) or the status is
`502`, `503`, `504`, or `429`. Each backoff is `backoff + backoff * rand.num()`
(jittered), then `backoff` grows by `multiplier`.

```lua
-- one attempt, no retry
local ok, resp = client.get(url, { retry = false })

-- up to 5 retries, custom predicate
client.get(url, { retry = { times = 5, filter = function (ok, resp)
  return not ok
end } })
```

covers: `test/spec/santoku/http.lua` ("retries then succeeds", "retry = false
disables retry").

## Cancelable requests

With `opts.cancelable`, `fetch` returns `{ cancel, await }` instead of running to
completion. Call `await()` to drive it; call `cancel()` to abort. A canceled
request resolves to `false, { status = 0, canceled = true }`. Cancellation is
checked before each attempt and after each backoff, and if a request is in
flight the backend's `cancel` is invoked.

```lua
local req = client.fetch(url, { cancelable = true })
req.cancel()
local ok, resp = req.await()   -- false, { status = 0, canceled = true }
```

covers: `test/spec/santoku/http.lua` ("cancelable request short-circuits with
the canceled sentinel").

## Hooks

`on`/`off` wrap `santoku.async` events. The `"request"` event runs before send
with `(url, opts)`; the `"response"` event runs after with `(ok, resp)`. To
rewrite the values, register the handler as async (third argument `true`) and
pass the new values forward through the continuation:

```lua
client.on("request", function (k, url, opts)
  return k(url .. "?tagged=1", opts)
end, true)

client.on("response", function (k, ok, resp)
  resp.body = process(resp.body)
  return k(ok, resp)
end, true)
```

A synchronous handler (no third argument) sees the values but its return is not
propagated; it can still mutate the passed `opts`/`resp` table in place.

covers: `test/spec/santoku/http.lua` ("request and response hooks rewrite
url/opts/resp").

## Testing

This repo uses the `toku` build harness. The spec lives in
`test/spec/santoku/http.lua` and drives the module with a mock backend (canned
`fetch` results and a counting no-op `sleep`), so no network is used. Run the
suite through `toku`.

## License

MIT License

Copyright 2025

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
