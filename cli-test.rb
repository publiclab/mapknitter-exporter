require "./lib/exporter"
require "json"
require "open-uri"

puts ARGV

url = ARGV[0] || "https://mapknitter.org/maps/ceres--2/warpables.json"
data = JSON.parse(open(url).read)
name = ARGV[1] || "test"

class Export
  attr_accessor :status, :tms, :geotiff, :zip, :jpg, :user_id, :size, :width, :height, :cm_per_pixel
  def save
    true
  end
end

export = Export.new

MapKnitterExporter.run_export(1, 20, export, name, data, '', 99)
