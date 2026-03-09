# yabeda-rack-queue

Rack middleware that measures HTTP request queue time. It reports the result to [Yabeda](https://github.com/yabeda-rb/yabeda) as a histogram.

## What is queue time?

A request may wait before your app handles it. A proxy or load balancer (like Nginx or Heroku) causes this wait. This is called queue time.

High queue time means your app is too busy. It cannot take new requests. That is a sign you need more capacity.

## How it works

Load balancers can add a header to each request. The header records when the request arrived. Common headers are `X-Request-Start` and `X-Queue-Start`.

This middleware reads that header. It subtracts the header's timestamp from the current time. Then it reports that value as `rack_queue.duration`.

> [!NOTE]
> If neither header is present, no measurement is taken. The request passes through unchanged.

## Installation

Add to your Gemfile:

```ruby
gem "yabeda-rack-queue"
```

Then run:

```bash
bundle install
```

## Usage

Add the middleware to your Rack stack. You also need a Yabeda adapter. For example, use [yabeda-prometheus](https://github.com/yabeda-rb/yabeda-prometheus).

```ruby
require "yabeda/rack/queue"
require "yabeda/prometheus"

Yabeda.configure!

use Yabeda::Rack::Queue::Middleware
run MyRackApp
```

For Rails, add it in `config/application.rb`:

```ruby
config.middleware.use Yabeda::Rack::Queue::Middleware
```

## Metric

| Name | Group | Type | Unit |
|------|-------|------|------|
| `duration` | `rack_queue` | histogram | seconds |

Access it in code:

```ruby
Yabeda.rack_queue.duration
```

With adapters that prepend the group name, such as Prometheus, this becomes `rack_queue_duration_seconds`.

Histogram buckets: 1 ms, 5 ms, 10 ms, 25 ms, 50 ms, 100 ms, 250 ms, 500 ms, 1 s, 2.5 s, 5 s, 10 s, 30 s, 60 s.

## Header formats

The middleware checks `X-Request-Start` first. If that header is absent, it tries `X-Queue-Start`.

Supported timestamp formats:

| Format | Example |
|--------|---------|
| Seconds (float) | `1609459200.123` |
| Milliseconds | `1609459200123` |
| Microseconds | `1609459200123456` |
| `t=` prefix | `t=1609459200.123` |

The middleware auto-detects the unit. It checks if the number fits a valid recent time.

## Puma adjustment

Puma sets `puma.request_body_wait` (in milliseconds) in the Rack env. This records how long Puma spent reading the request body.

The middleware subtracts this value from queue time. Without this step, large bodies make queue time appear too long.

## Configuration

The middleware accepts these keyword arguments:

| Argument | Default | Purpose |
|----------|---------|---------|
| `reporter:` | `YabedaReporter.new` | Writes the value to Yabeda. |
| `logger:` | stderr | Gets warning messages. |
| `clock:` | `Process.clock_gettime(CLOCK_REALTIME)` | Returns current time in seconds. |

Example with a custom logger:

```ruby
use Yabeda::Rack::Queue::Middleware, logger: Rails.logger
```

## Requirements

- Ruby >= 3.1.
- yabeda >= 0.14, < 1.0.
- A Yabeda adapter. For example: [yabeda-prometheus](https://github.com/yabeda-rb/yabeda-prometheus).

## Development

Run tests:

```bash
bundle exec rake test
```

Run the linter:

```bash
bundle exec standardrb
```

## Contributing

Bug reports and pull requests are welcome at <https://github.com/speedshop/yabeda-rack-queue>.

## License

MIT. See [LICENSE.txt](LICENSE.txt).
