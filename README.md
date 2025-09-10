# Santoku HTTP

Santoku HTTP is an HTTP client library for Lua providing request/response
handling, automatic JSON encoding/decoding, retry logic, and interceptor-based
request modification.

## Module Reference

### `santoku.http`
HTTP client functionality with automatic JSON handling and configurable retry logic.

| Function | Arguments | Returns | Description |
|----------|-----------|---------|-------------|
| `fetch` | `req` | `response, request` | Executes HTTP request with configured options |
| `request` | `[method], [url], [opts], [done]` | `request_object` | Creates configurable HTTP request object |
| `get_request` | `[url], [opts], [done]` | `request_object` | Creates GET request object |
| `post_request` | `[url], [opts], [done]` | `request_object` | Creates POST request object |
| `req` | `[method], [url], [opts], [done]` | `response, request` | Creates and executes request immediately |
| `get` | `[url], [opts], [done]` | `response, request` | Executes GET request immediately |
| `post` | `[url], [opts], [done]` | `response, request` | Executes POST request immediately |
| `client` | `-` | `client_object` | Creates HTTP client with interceptor support |

#### Request Object Structure

The request object created by `request()` contains:

| Field | Type | Description |
|-------|------|-------------|
| `method` | `string` | HTTP method (GET, POST, etc.) |
| `url` | `string` | Request URL |
| `headers` | `table` | Request headers |
| `body` | `string/table` | Request body (tables are JSON-encoded for POST) |
| `params` | `table` | Query parameters (encoded for GET requests) |
| `done` | `function` | Callback function for handling response |
| `events` | `event_emitter` | Event system for request/response interception |
| `retry` | `table/false` | Retry configuration |

#### Options Object

The `opts` parameter accepts:

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `method` | `string` | `"GET"` | HTTP method |
| `url` | `string` | - | Request URL (alternative to positional) |
| `headers` | `table` | `nil` | Request headers |
| `body` | `string/table` | `nil` | Request body |
| `params` | `table` | `nil` | Query parameters |
| `done` | `function` | `error.checkok` | Response handler |
| `retry` | `table/false` | `{}` | Retry configuration (false to disable) |

#### Response Object

The response object contains:

| Field | Type | Description |
|-------|------|-------------|
| `ok` | `boolean` | True if status is 2xx |
| `status` | `number` | HTTP status code |
| `headers` | `table` | Response headers (lowercase keys) |
| `body` | `string/table` | Response body (auto-parsed if JSON) |

#### Retry Configuration

The `retry` option accepts a table with:

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `times` | `number` | `3` | Maximum retry attempts |
| `backoff` | `number` | `1` | Initial backoff in seconds |
| `multiplier` | `number` | `3` | Backoff multiplier per retry |
| `filter` | `function` | - | Custom retry condition function |

Default retry filter retries on status codes: 502, 503, 504, 429

#### Client Object

The client object returned by `client()` provides:

| Method | Arguments | Returns | Description |
|--------|-----------|---------|-------------|
| `on` | `event, handler, [prepend]` | `nil` | Register event handler |
| `off` | `event, handler` | `nil` | Unregister event handler |
| `req` | `[method], [url], [opts], [done]` | `response, request` | Execute intercepted request |
| `get` | `[url], [opts], [done]` | `response, request` | Execute intercepted GET |
| `post` | `[url], [opts], [done]` | `response, request` | Execute intercepted POST |

Client events:
- `"request"`: Fired before request execution, receives `(callback, request)`
- `"response"`: Fired after response, receives `(callback, ok, response, request)`

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
