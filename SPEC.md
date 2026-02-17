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

No tags are recorded by default. Users can wrap calls with `Yabeda.with_tags`
if they need per-path or per-method breakdowns.

## Headers

The middleware inspects these Rack environment keys, in order:

1. `HTTP_X_REQUEST_START`
2. `HTTP_X_QUEUE_START`

The first header that yields a valid timestamp is used. If neither header is
present or parseable, no metric is recorded and the request passes through
unaffected.

## Header Value Parsing

A regex extracts the numeric portion from the header value:

1. `t=<number>` — extract the number after `t=`
2. Plain `<number>` — use the whole value

The extracted number is then interpreted:

- **Contains a decimal point** → seconds since epoch (e.g. Nginx's `t=1512379167.574`)
- **No decimal point** → milliseconds since epoch (e.g. Heroku's `1512379167574`)

### Known Format Examples

| Source | Header | Format | Example Value |
|--------|--------|--------|---------------|
| Heroku | `X-Request-Start` | plain milliseconds | `1512379167574` |
| Nginx | `X-Request-Start` | `t=` seconds.ms | `t=1512379167.574` |
| F5 | `X-Request-Start` | `t=` milliseconds | `t=1512379167574` |
| Contour/Envoy | `X-Request-Start` | `t=` seconds.ms | `t=1512379167.574` |
| Nginx + Passenger | `X-Request-Start` | `t=` seconds.ms | `t=1512379167.574` |

## Validation

A parsed timestamp is rejected (treated as absent) if:

- The header value contains no extractable numeric portion
- The resulting timestamp is before 2000-01-01 00:00:00 UTC (epoch 946684800)
- The resulting timestamp is more than 30 seconds in the future

## Negative Queue Time (Clock Skew)

If the computed queue time (`now - request_start`) is negative — which can happen
when the application server's clock is slightly ahead of the load balancer's
clock — it is clamped to `0.0` seconds. A metric observation of `0.0` is still
recorded, indicating the header was present.

We'll log a WARN level message in this case.

## Middleware Behavior

- The middleware always calls the downstream Rack app, regardless of header state.
- Queue time is computed **before** calling the downstream app (measures time
  *before* application processing, not including it).
- The middleware does not modify the Rack env or the response in any way.
- The middleware never raises exceptions due to unparseable or missing headers.
- Current time is measured via `Process.clock_gettime(Process::CLOCK_REALTIME)`
  (wall clock, not monotonic — necessary because the header timestamp comes from
  a different process).

