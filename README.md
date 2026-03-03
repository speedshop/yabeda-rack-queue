# yabeda-rack-queue

Rack middleware that measures HTTP request queue time and reports it to
[Yabeda core](https://github.com/yabeda-rb/yabeda) as a histogram.

## Features

- Reports upstream queue wait time before your app starts handling the request
- Reads common queue headers (`X-Request-Start`, `X-Queue-Start`)
- Exposes `rack_queue.rack_queue_duration` (seconds)
- Supports Puma request body wait adjustment (`puma.request_body_wait`)

## Installation

Add the gem:

```ruby
gem "yabeda-rack-queue"
```

Then install dependencies:

```bash
bundle install
```

## Quickstart

```ruby
require "yabeda/rack/queue"
require "yabeda/prometheus"

Yabeda.configure!

use Yabeda::Rack::Queue::Middleware
run MyRackApp
```

Send a request with an upstream queue header (for example `X-Request-Start`) and
the middleware will record `rack_queue.rack_queue_duration`.

## Metric

- Name: `rack_queue_duration`
- Group: `rack_queue`
- Type: histogram
- Unit: seconds

## Development

Run tests:

```bash
bundle exec rake test
```

Run lint:

```bash
bundle exec standardrb
```

## Contributing

Issues and pull requests are welcome.

## License

MIT, see [LICENSE.txt](LICENSE.txt).
