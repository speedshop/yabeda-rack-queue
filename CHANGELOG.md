# Changelog

## 0.2.0 - 2026-03-09

### Changed

- Renamed the histogram metric from `rack_queue_duration` to `duration` inside the `rack_queue` group.
- The Yabeda accessor is now `Yabeda.rack_queue.duration`.
- Adapters that prepend the group name, such as Prometheus, now expose the metric as `rack_queue_duration_seconds` instead of `rack_queue_rack_queue_duration_seconds`.

## 0.1.0 - 2026-03-08

### Added

- Initial release.
