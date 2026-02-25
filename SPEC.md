# yabeda-rack-queue Specification

## Purpose

This gem measures HTTP request queue time — the duration between when a reverse
proxy or load balancer first receives a request and when the Ruby application
begins processing it. It reports this as a Yabeda histogram metric.

## Metric

| Name | Type | Group | Unit | Description |
|------|------|-------|------|-------------|
| `rack_queue_duration` | histogram | `rack_queue` | seconds | Time a request waited in the upstream queue before reaching the application |

### Histogram Buckets

`[0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10, 30, 60]`

No tags are recorded by default.

## Headers

The middleware inspects these Rack environment keys, in order:

1. `HTTP_X_REQUEST_START`
2. `HTTP_X_QUEUE_START`

The first header that yields a valid timestamp is used. If neither header is
present or parseable, no metric is recorded and the request passes through
unaffected.

## Middleware Behavior

- The middleware always calls the downstream Rack app, regardless of header state.
- Queue time is computed **before** calling the downstream app (measures time
  *before* application processing, not including it).
- The middleware does not modify the Rack env or the response in any way.
- The middleware never raises exceptions due to invalid input.
- Current time is measured via `Process.clock_gettime(Process::CLOCK_REALTIME)`
  (wall clock, not monotonic — necessary because the header timestamp comes from
  a different process).

## Header Value Parsing

Header values are parsed for compatibility with common reverse proxies and APM
agents.

1. First, extract a numeric timestamp token from the header value:
   - `t=<number>` (preferred)
   - or plain `<number>`
2. Then normalize units by trying divisors in order:
   - divide by `1_000_000` (microseconds)
   - else divide by `1_000` (milliseconds)
   - else divide by `1` (seconds)
3. The first normalized value that is after the minimum acceptable epoch
   (`2000-01-01`) is used.

Notes:

- This supports seconds, milliseconds, and microseconds (integer or decimal).
- Leading/trailing whitespace is ignored.
- If a header contains comma-separated values, use the first value.

### Known Format Examples

| Source | Header | Format | Example Value |
|--------|--------|--------|---------------|
| Heroku | `X-Request-Start` | milliseconds | `1512379167574` |
| Nginx | `X-Request-Start` | `t=` seconds.ms | `t=1512379167.574` |
| Apache | `X-Request-Start` | `t=` microseconds | `t=1570633834463123` |
| HAProxy (<1.9) | `X-Request-Start` | `t=` integer seconds | `t=1512379167` |
| F5 | `X-Request-Start` | `t=` milliseconds | `t=1512379167574` |
| Contour/Envoy | `X-Request-Start` | `t=` seconds.ms | `t=1512379167.574` |

## Validation

A parsed timestamp is rejected (treated as absent) if:

- The header value contains no extractable numeric portion
- The resulting timestamp is before 2000-01-01 00:00:00 UTC (epoch 946684800)
- The resulting timestamp is more than 30 seconds in the future

If a timestamp is invalid, we do not record anything. We should not raise any exceptions, it should just be a no-op.

### Negative Queue Time (Clock Skew)

If the computed queue time (`now - request_start`) is negative — which can happen
when the application server's clock is slightly ahead of the load balancer's
clock — the observation is dropped (no metric is recorded).

We'll log a WARN level message in this case.

## Puma Request Body Wait Adjustment

If `env["puma.request_body_wait"]` exists, subtract it from the computed queue
time to avoid counting time spent waiting for slow clients to upload request
bodies.

- `puma.request_body_wait` is interpreted as milliseconds and converted to seconds before subtraction
- Numeric strings are coerced to float before subtraction
- Non-numeric or negative values are treated as absent (no subtraction)
- If subtraction would make queue time negative, clamp to `0.0` seconds

## Parsing Truth Table

Assumptions used below:

- Minimum acceptable epoch: `946684800` (2000-01-01 UTC)
- `now = 1700000000` (example current time)
- Future cutoff = `now + 30` seconds

| Header value | Extracted token | Chosen normalization | Parsed timestamp (s) | Result |
|---|---:|---|---:|---|
| `t=1512379167.574` | `1512379167.574` | `/1` (seconds) | `1512379167.574` | accepted |
| `1512379167.574` | `1512379167.574` | `/1` (seconds) | `1512379167.574` | accepted |
| `t=1512379167574` | `1512379167574` | `/1000` (milliseconds) | `1512379167.574` | accepted |
| `1512379167574` | `1512379167574` | `/1000` (milliseconds) | `1512379167.574` | accepted |
| `t=1570633834463123` | `1570633834463123` | `/1000000` (microseconds) | `1570633834.463123` | accepted |
| `1570633834463123` | `1570633834463123` | `/1000000` (microseconds) | `1570633834.463123` | accepted |
| `t=1512379167` | `1512379167` | `/1` (seconds) | `1512379167` | accepted |
| `1512379167` | `1512379167` | `/1` (seconds) | `1512379167` | accepted |
| `  t=1512379167.574  ` | `1512379167.574` | `/1` (seconds) | `1512379167.574` | accepted (whitespace ignored) |
| `t=1512379167.574, t=1512379168.000` | `1512379167.574` (first value) | `/1` (seconds) | `1512379167.574` | accepted |
| `invalid` | _none_ | — | — | rejected (no numeric token) |
| `t=` | _none_ | — | — | rejected (empty token) |
| `t=0` | `0` | none pass minimum epoch | — | rejected (too old) |
| `t=915148800` | `915148800` | none pass minimum epoch | — | rejected (too old) |
| `t=1700000035` | `1700000035` | `/1` (seconds) | `1700000035` | rejected (more than 30s in future for assumed `now`) |

### Queue time post-processing examples

| Parsed `request_start` | `now` | Raw queue time (s) | `puma.request_body_wait` | Final outcome |
|---:|---:|---:|---:|---|
| `1699999999.900` | `1700000000.000` | `0.100` | _absent_ | `0.100` |
| `1699999999.900` | `1700000000.000` | `0.100` | `40` (ms) | `0.060` |
| `1699999999.900` | `1700000000.000` | `0.100` | `"40"` (ms) | `0.060` |
| `1700000000.050` | `1700000000.000` | `-0.050` | _absent_ | dropped (clock skew, WARN logged) |
| `1699999999.900` | `1700000000.000` | `0.100` | `200` (ms) | `0.000` (post-subtraction clamp) |

