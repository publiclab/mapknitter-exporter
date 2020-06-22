require "minitest/autorun"
require "./lib/exporter"
require "json"

class ExporterTest < Minitest::Test
  def test_all_functions # TODO: break this into separate parts
    id = 99
    user_id = 1
    scale = 2
    # replace map.export with a simple Export object, maybe a Mock?
    # https://github.com/seattlerb/minitest#mocks
    resolution = 20
    nodes_array = [
      {
        'lat': 41.8403113680142,
        'lon': -71.3983854668186
      },
      {
        'lat': 41.8397358653566,
        'lon': -71.3916477577732
      },
      {
        'lat': 41.8351476451765,
        'lon': -71.392699183707
      },
      {
        'lat': 41.8377535388085,
        'lon': -71.3981708900974
      }
    ]
    image = {
      'height': 20,
      'width': 20,
      'id': 1,
      'image_file_name': 'demo.png',
      'src': 'test/fixtures/demo.png',
      'nodes': nodes_array
    }

    # simulate real JSON:
    image = JSON.parse(image.to_json)
    nodes_array = JSON.parse(nodes_array.to_json)
    export = MockExport.new

    # make a sample image
    system('mkdir -p public/system/images/1/original')
    system('cp test/fixtures/demo.png public/system/images/1/original/')
    system("mkdir -p public/warps/#{id}")
    system("mkdir -p public/tms/#{id}")
    system("touch public/warps/#{id}/folder")
    assert File.exist?("public/warps/#{id}/folder")

    coords = MapKnitterExporter.generate_perspectival_distort(
      scale,
      image['id'],
      nodes_array,
      image['image_file_name'],
      image['src'],
      image['height'],
      image['width'],
      id
    )
    assert coords
    assert MapKnitterExporter.get_working_directory(id)
    assert MapKnitterExporter.warps_directory(id)

    # get rid of existing geotiff
    system("rm -r public/warps/#{id}/1.tif")
    # make a sample image
    system('mkdir -p public/system/images/1/original/')
    system('cp test/fixtures/demo.png public/system/images/1/original/test.png')

    origin = MapKnitterExporter.distort_warpables(
      scale,
      [image],
      export,
      id
    )
    lowest_x, lowest_y, warpable_coords = origin
    assert origin
    ordered = false

    system("mkdir -p public/warps/#{id}")
    system("mkdir -p public/tms/#{id}")
    # these params could be compressed - warpable coords is part of origin; are coords and origin required?
    assert MapKnitterExporter.generate_composite_tiff(
      warpable_coords,
      origin,
      [image],
      id,
      ordered
    )

    tiles = MapKnitterExporter.generate_tiles('', id)
    assert tiles
    assert_equal "public/tms/#{id}/", tiles

    system("mkdir -p public/tms/#{id}")
    system("touch public/tms/#{id}/#{id}.zip")
    zip = MapKnitterExporter.zip_tiles(id)
    assert zip
    assert_equal "public/tms/#{id}.zip", zip
    assert File.file?("public/tms/#{id}.zip")

    jpg = MapKnitterExporter.generate_jpg(id)
    assert jpg
    assert_equal "public/warps/#{id}/#{id}.jpg", jpg
    assert File.file?("public/warps/#{id}/#{id}.jpg")

    export = MockExport.new

    # run_export(user_id, resolution, export, id, placed_warpables, key)
    output_export = MapKnitterExporter.run_export(
      user_id,
      resolution,
      export,
      id,
      [image],
      ''
    )
    assert_equal "complete", output_export.status

    assert_equal "public/warps/#{id}/#{id}.tif", export.geotiff
    assert_equal "public/warps/#{id}/#{id}.jpg", export.jpg

    assert File.file?("public/warps/#{id}/#{id}.tif")
    assert File.file?("public/warps/#{id}/#{id}.jpg")

    # test deletion of the files; they were already deleted in run_export,
    # so let's make new dummy ones:
    # make a sample image
    system('mkdir -p public/system/images/1/original/')
    system('touch public/system/images/1/original/test.png')
    system("mkdir -p public/warps/#{id}")
    system("mkdir -p public/tms/#{id}")
    system("touch public/tms/#{id}/#{id}.zip")
    system("touch public/warps/#{id}/folder")
    assert File.exist?("public/warps/#{id}/folder")
    system("mkdir -p public/warps/#{id}-working")
    system("touch public/warps/#{id}/test.png")
    assert MapKnitterExporter.delete_temp_files(id)
  end
end

class MockExport
  attr_accessor :status, :tms, :geotiff, :zip, :jpg, :user_id, :size, :width, :height, :cm_per_pixel

  def save
    puts "saved"
  end
end
