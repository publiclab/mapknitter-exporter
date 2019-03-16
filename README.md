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
