# yabeda-rack-queue

Rack middleware for reporting HTTP request queue time to Yabeda.

## Installation

Add to your Gemfile:

```ruby
gem "yabeda-rack-queue"
```

Then bundle install.

## Usage

```ruby
require "yabeda/rack/queue"
require "yabeda/prometheus"

Yabeda.configure!

use Yabeda::Rack::Queue::Middleware
run MyRackApp
```

The middleware inspects `X-Request-Start` / `X-Queue-Start` headers and records
`rack_queue.rack_queue_duration` histogram values in seconds.
