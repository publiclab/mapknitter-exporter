require_relative 'cartagen'
require_relative 'mapknitter_exporter'
require 'open3'
require 'net/http'
require "shellwords"
require "fileutils"

class MapKnitterExporter
  def self.ulimit
    # use ulimit to restrict to 7200 CPU seconds and 5gb virtual memory, and 5gB file storage:
    # "ulimit -t 7200 && ulimit -v 5000000 && ulimit -f 5000000 && "
    "ulimit -t 14400 && ulimit -v 5000000 && ulimit -f 10000000 && nice -n 19 "
  end

  def self.get_working_directory(path)
    "public/warps/#{path}-working/"
  end

  def self.warps_directory(path)
    "public/warps/#{path}/"
  end

  def self.delete_temp_files(path)
    system('rm -r ' + get_working_directory(path))
    system('rm ' + warps_directory(path) + '*.png')
  end

  ########################
  ## Run on each image:

  def self.image_magick_manipulation(height, width, mask_location, local_location, completed_local_location, maxdimension, maskpoints, masked_local_location, points)
    image_magick = "convert "
    image_magick += "-contrast-stretch 0 "
    image_magick += local_location.shellescape + " "
    image_magick += "-crop " + maxdimension.to_i.to_s + "x" + maxdimension.to_i.to_s + "+0+0! "
    image_magick += "-flatten "
    image_magick += "-distort Perspective '" + points + "' "
    image_magick += "-flatten "
    image_magick += if width > height
                      "-crop " + width + "x" + width + "+0+0\! "
                    else
                      "-crop " + height + "x" + height + "+0+0\! "
                   end
    image_magick += "+repage "
    image_magick += completed_local_location
    puts image_magick
    system(ulimit + image_magick)

    # create a mask (later we can blur edges here)
    image_magick2 = 'convert +antialias '
    image_magick2 += if width > height
                       "-size " + width + "x" + width + " "
                     else
                       "-size " + height + "x" + height + " "
                    end
    # attempt at blurred edges in masking, but I've given up, as gdal_merge doesn't seem to respect variable-opacity alpha channels
    image_magick2 += ' xc:none -draw "fill black stroke red stroke-width 30 polyline '
    image_magick2 += maskpoints + '" '
    image_magick2 += ' -alpha set -channel A -transparent red -blur 0x8 -channel R -evaluate set 0 +channel ' + mask_location
    # image_magick2 += ' xc:none -draw "fill black stroke none polyline '
    # image_magick2 += maskpoints + '" '
    # image_magick2 += ' '+mask_location
    puts image_magick2
    system(ulimit + image_magick2)

    image_magick3 = 'composite ' + mask_location + ' ' + completed_local_location + ' -compose DstIn -alpha Set ' + masked_local_location
    puts image_magick3
    system(ulimit + image_magick3)
  end

  # pixels per meter = pxperm
  def self.generate_perspectival_distort(pxperm, id, nodes_array, image_file_name, img_url, height, width, collection_id) # rubocop:disable Metrics/AbcSize
    image_file_name ||= img_url.split('/').last
    # everything in -working/ can be deleted;
    # this is just so we can use the files locally outside of s3
    working_directory = get_working_directory(collection_id)
    Dir.mkdir(working_directory) unless File.exist?(working_directory) && File.directory?(working_directory)
    local_location = "#{working_directory}w#{id}-#{image_file_name}"
    directory = warps_directory(collection_id)
    Dir.mkdir(directory) unless File.exist?(directory) && File.directory?(directory)
    completed_local_location = directory + 'w' + id.to_s + '.png'

    # everything -masked.png can be deleted
    masked_local_location = directory + 'w' + id.to_s + '-masked.png'
    # everything -mask.png can be deleted
    mask_location = directory + 'w' + id.to_s + '-mask.png'
    # completed_local_location = directory+id.to_s+'.tif'
    # know everything -unwarped can be deleted
    geotiff_location = directory + 'w' + id.to_s + '-geo-unwarped.tif'
    # everything -geo WITH AN ID could be deleted, but there is a feature request to preserve these
    warped_geotiff_location = directory + 'w' + id.to_s + '.tif'

    northmost = nodes_array.first['lat'].to_f
    southmost = nodes_array.first['lat'].to_f
    westmost =  nodes_array.first['lon'].to_f
    eastmost =  nodes_array.first['lon'].to_f

    nodes_array.each do |node|
      northmost = node['lat'].to_f if node['lat'].to_f > northmost
      southmost = node['lat'].to_f if node['lat'].to_f < southmost
      westmost =  node['lon'].to_f if node['lon'].to_f < westmost
      eastmost =  node['lon'].to_f if node['lon'].to_f > eastmost
    end

    scale = 20_037_508.34
    y1 = pxperm.to_f * Cartagen.spherical_mercator_lat_to_y(northmost, scale)
    x1 = pxperm.to_f * Cartagen.spherical_mercator_lon_to_x(westmost, scale)
    y2 = pxperm.to_f * Cartagen.spherical_mercator_lat_to_y(southmost, scale)
    x2 = pxperm.to_f * Cartagen.spherical_mercator_lon_to_x(eastmost, scale)

    # should determine if it's stored in s3 or locally:
    if img_url.slice(0, 4) == 'http'
      host = img_url.split('//').last.split('/').first
      Net::HTTP.start(host) do |http|
        resp = http.get(img_url)
        open(local_location, "wb") do |file| # rubocop:disable Security/Open
          file.write(resp.body)
        end
      end
    else
      FileUtils.cp(img_url, local_location)
    end

    points = ""
    maskpoints = ""
    coordinates = ""
    first = true

    # EXIF orientation values:
    # Value  0th Row  0th Column
    # 1  top  left side
    # 2  top  right side
    # 3  bottom  right side
    # 4  bottom  left side
    # 5  left side  top
    # 6  right side  top
    # 7  right side  bottom
    # 8  left side  bottom

    rotation = `identify -format %[exif:Orientation] #{local_location.shellescape}`.to_i
    # stdin, stdout, stderr = Open3.popen3('identify -format %[exif:Orientation] #{local_location}')
    # rotation = stdout.readlines.first.to_s.to_i
    # puts stderr.readlines

    if rotation == 6
      puts 'rotated CCW'
      source_corners = source_corners = [[0, height], [0, 0], [width, 0], [width, height]]
    elsif rotation == 8
      puts 'rotated CW'
      source_corners = [[width, 0], [width, height], [0, height], [0, 0]]
    elsif rotation == 3
      puts 'rotated 180 deg'
      source_corners = [[width, height], [0, height], [0, 0], [width, 0]]
    else
      source_corners = [[0, 0], [width, 0], [width, height], [0, height]]
    end

    maxdimension = 0

    nodes_array.each do |node|
      corner = source_corners.shift
      nx1 = corner[0]
      ny1 = corner[1]
      nx2 = -x1 + (pxperm.to_f * Cartagen.spherical_mercator_lon_to_x(node['lon'].to_f, scale.to_f))
      ny2 =  y1 - (pxperm.to_f * Cartagen.spherical_mercator_lat_to_y(node['lat'].to_f, scale.to_f))

      points += '  ' unless first
      maskpoints += ' ' unless first
      points = points + nx1.to_s + ',' + ny1.to_s + ' ' + nx2.to_i.to_s + ',' + ny2.to_i.to_s
      maskpoints = maskpoints + nx2.to_i.to_s + ',' + ny2.to_i.to_s
      first = false
      # we need to find an origin; find northwestern-most point
      coordinates = coordinates + ' -gcp ' + nx2.to_s + ', ' + ny2.to_s + ', ' + node['lon'].to_s + ', ' + node['lat'].to_s

      # identify largest dimension to set canvas size for ImageMagick:
      maxdimension = nx1.to_i if maxdimension < nx1.to_i
      maxdimension = ny1.to_i if maxdimension < ny1.to_i
      maxdimension = nx2.to_i if maxdimension < nx2.to_i
      maxdimension = ny2.to_i if maxdimension < ny2.to_i
    end

    # close mask polygon:
    maskpoints += ' '
    nx2 = -x1 + (pxperm.to_f * Cartagen.spherical_mercator_lon_to_x(nodes_array.first['lon'].to_f, scale.to_f))
    ny2 = y1 - (pxperm.to_f * Cartagen.spherical_mercator_lat_to_y(nodes_array.first['lat'].to_f, scale.to_f))
    maskpoints = maskpoints + nx2.to_i.to_s + ',' + ny2.to_i.to_s

    height = (y1 - y2).to_i.to_s
    width = (-x1 + x2).to_i.to_s

    # http://www.imagemagick.org/discourse-server/viewtopic.php?f=1&t=11319
    # http://www.imagemagick.org/discourse-server/viewtopic.php?f=3&t=8764
    # read about equalization
    # -equalize
    # -contrast-stretch 0

    image_magick_manipulation(height, width, mask_location, local_location, completed_local_location, maxdimension, maskpoints, masked_local_location, points)

    gdal_translate = "gdal_translate -of GTiff -a_srs EPSG:4326 " + coordinates + '  -co "TILED=NO" ' + masked_local_location + ' ' + geotiff_location
    puts gdal_translate
    system(ulimit + gdal_translate)

    # gdalwarp = 'gdalwarp -srcnodata "255" -dstnodata 0 -cblend 30 -of GTiff -t_srs EPSG:4326 '+geotiff_location+' '+warped_geotiff_location
    gdalwarp = 'gdalwarp -of GTiff -t_srs EPSG:4326 ' + geotiff_location + ' ' + warped_geotiff_location
    puts gdalwarp
    system(ulimit + gdalwarp)

    # deletions could happen here; do it in distinct method so we can run it independently
    delete_temp_files(id)

    [x1, y1]
  end

  ########################
  ## Run on maps:

  # distort all warpables, returns upper left corner coords in x,y
  def self.distort_warpables(scale, images, export, id)
    puts '> generating geotiffs of each warpable in GDAL'
    lowest_x = 0
    lowest_y = 0
    all_coords = []
    current = 0
    images.each_with_index do |image, index|
      current += 1

      export.status = 'warping ' + current.to_s + ' of ' + images.length.to_s
      puts 'warping ' + current.to_s + ' of ' + images.length.to_s
      export.save
      ##
      image['id'] = image['id'] || index

      img_coords = generate_perspectival_distort(
        scale,
        image['id'],
        image['nodes'],
        image['image_file_name'],
        image['src'],
        image['height'].to_i,
        image['width'].to_i,
        id # collection id
      )
      puts '- ' + img_coords.to_s
      all_coords << img_coords

      lowest_x = img_coords.first if img_coords.first < lowest_x || lowest_x.zero?
      lowest_y = img_coords.last if img_coords.last < lowest_y || lowest_y.zero?
    end
    [lowest_x, lowest_y, all_coords]
  end

  # generate a tiff from all warpable images in this set
  def self.generate_composite_tiff(_coords, _origin, warpables, id, ordered)
    directory = "public/warps/#{id}/"
    composite_location = directory + id.to_s + '.tif'
    minlat = nil
    minlon = nil
    maxlat = nil
    maxlon = nil
    warpables.each_with_index do |warpable, i|
      warpable['nodes'].each do |n|
        puts "warpable: ", n['id'], i, n['lat'], n['lon']
        minlat = n['lat'].to_f if minlat.nil? || n['lat'].to_f < minlat
        minlon = n['lon'].to_f if minlon.nil? || n['lon'].to_f < minlon
        maxlat = n['lat'].to_f if maxlat.nil? || n['lat'].to_f > maxlat
        maxlon = n['lon'].to_f if maxlon.nil? || n['lon'].to_f > maxlon
      end
    end
    puts "minlat #{minlat}, minlon #{minlon}, maxlat #{maxlat}, maxlon #{maxlon}"
    if ordered != true && warpables.first.key?('poly_area')
      # sort by area; this would be overridden by a provided order
      warpables = warpables.sort { |a, b| b['poly_area'] <=> a['poly_area'] }
    end
    geotiffs = ""
    warpables.each do |warpable|
      wid = "w" + warpable['id'].to_s
      geotiffs += ' ' + directory + wid + '.tif'
    end
    gdalwarp = "gdalwarp -s_srs EPSG:3857 -t_srs EPSG:4326 -te #{minlon} #{minlat} #{maxlon} #{maxlat} #{geotiffs} #{directory}#{id}.tif"
    puts gdalwarp
    system(ulimit + gdalwarp)
    composite_location
  end

  # generates a tileset at public/tms/<id>/
  def self.generate_tiles(key, id)
    key = "AIzaSyAOLUQngEmJv0_zcG1xkGq-CXIPpLQY8iQ" if key == "" # ugh, let's clean this up!
    key ||= "AIzaSyAOLUQngEmJv0_zcG1xkGq-CXIPpLQY8iQ"
    gdal2tiles = "gdal2tiles.py -k --s_srs EPSG:3857 -z 10-22 -t #{id} -g #{key} public/warps/#{id}/#{id}.tif public/tms/#{id}/"
    puts gdal2tiles
    if system(ulimit + gdal2tiles)
      "public/tms/#{id}/"
    else
      false
    end
  end

  # zips up tiles at public/tms/<id>.zip;
  def self.zip_tiles(id)
    rmzip = "cd public/tms/ && rm #{id}.zip && cd ../../"
    system(rmzip)
    zip = "cd public/tms/ && #{ulimit} zip -rq #{id}.zip #{id}/ && cd ../../"
    if system(zip)
      "public/tms/#{id}.zip"
    else
      false
    end
  end

  # generates a tileset at public/tms/<id>/
  def self.generate_jpg(id)
    image_magick = "convert -background white -flatten public/warps/#{id}/#{id}.tif public/warps/#{id}/#{id}.jpg"
    if system(ulimit + image_magick)
      "public/warps/#{id}/#{id}.jpg"
    else
      false
    end
  end

  # runs the above map functions while maintaining a record of state in an Export model;
  # we'll be replacing the export model state with a flat status file
  def self.run_export(user_id, resolution, export, id, warpables, key, ordered = false)
    export.user_id = user_id if user_id
    export.status = 'starting'
    # we set these false again later...
    export.tms = false
    export.geotiff = false
    export.zip = false
    export.jpg = false
    export.save

    # filter out those that have no corner coordinates
    placed_warpables = warpables.keep_if do |w|
      w['nodes'] && !w['nodes'].empty?
    end

    directory = "public/warps/#{id}/"
    _stdin, stdout, stderr = Open3.popen3('rm -r ' + directory.to_s)
    puts stdout.readlines
    puts stderr.readlines
    _stdin, stdout, stderr = Open3.popen3("rm -r public/tms/#{id}")
    puts stdout.readlines
    puts stderr.readlines

    puts '> averaging scales; resolution: ' + resolution.to_s
    pxperm = 100 / resolution.to_f # pixels per meter
    puts '> scale: ' + pxperm.to_s + 'pxperm'

    puts '> distorting warpables'

    origin = distort_warpables(pxperm, placed_warpables, export, id)
    warpable_coords = origin.pop

    export.status = 'compositing'
    export.save

    puts '> generating composite tiff'
    composite_location = generate_composite_tiff(
      warpable_coords,
      origin,
      placed_warpables,
      id,
      ordered
    )

    identify = "identify -quiet -format '%b,%w,%h' #{composite_location}"
    puts identify
    info = `#{identify}`.split(',')
    puts info

    if info[0] != ''
      export.geotiff = composite_location
      export.size = info[0]
      export.width = info[1]
      export.height = info[2]
      export.cm_per_pixel = 100.0000 / pxperm
      export.save
    end

    # this could be forked
    puts '> generating tiles'
    export.tms = false
    export.status = 'tiling'
    export.save
    export.tms = generate_tiles(key, id)
    export.save unless export.tms == false

    puts '> zipping tiles'
    export.zip = false
    export.status = 'zipping tiles'
    export.save
    export.zip = zip_tiles(id)
    export.save unless export.zip == false
    # end fork

    # this could be forked
    puts '> generating jpg'
    export.jpg = false
    export.status = 'creating jpg'
    export.save
    export.jpg = generate_jpg(id)
    unless export.jpg == false
      export.status = 'complete'
      export.save
    end
    # end fork

    export
  end
end
