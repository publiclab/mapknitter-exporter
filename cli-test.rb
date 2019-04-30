require "./lib/mapknitterExporter"
require "json"
require "open-uri"

data = JSON.parse(open("https://mapknitter.org/maps/ceres--2/warpables.json").read)

class Export
  attr_accessor :status, :tms, :geotiff, :zip, :jpg, :user_id, :size, :width, :height, :cm_per_pixel
  def save
    true
  end
end

export = Export.new

MapKnitterExporter.run_export(1,20,export,1,data,'',99)
