# MapKnitterExporter

Add this gem with `gem install mapknitter-exporter`

Then, use it with:

```ruby
require 'mapknitter-exporter'

# this should work:

MapKnitterExporter.generate_perspectival_distort(
  scale,
  1, # a unique id
  [
    { lat: 41.8403113680142, lon: -71.3983854668186 },
    { lat: 41.8397358653566, lon: -71.3916477577732 },
    { lat: 41.8351476451765, lon: -71.392699183707  },
    { lat: 41.8377535388085, lon: -71.3981708900974 }
  ],
  'test/fixtures/demo.png',
  image,
  height,
  width
)
```

## Tests

To run tests, use `ruby test/exporter_test.rb`.

Tests require `minitest` which you can install with `bundle install`.
