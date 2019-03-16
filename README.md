# MapKnitterExporter

Add this gem with `gem install mapknitter-exporter`

Then, use it with:

```ruby
require 'mapknitter-exporter'

# not sure this will work:

MapKnitterExporter.generate_perspectival_distort(
  scale,
  'map',
  nodes_array,
  1, # a unique id
  'test/fixtures/demo.png',
  image,
  height,
  width
)
```

## Tests

Tests are not passing completely but they are running; use `ruby test/exporter_test.rb` to run them.

Tests require `minitest` which you can install with `bundle install`.
