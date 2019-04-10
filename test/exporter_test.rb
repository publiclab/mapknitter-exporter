require "minitest/autorun"
require "./lib/mapknitterExporter"

class ExporterTest < Minitest::Test
  def test_all_functions # break this into separate parts

    slug = "ten-forward"
    id = 1
    user_id = 1
    scale = 2
    # replace map.export with a simple Export object, maybe a Mock?
    # https://github.com/seattlerb/minitest#mocks
    root = "" # instead of default https://mapknitter.org, bc image is local
    resolution = 20
    nodes_array = [
      {
        lat: 41.8403113680142,
        lon: -71.3983854668186
      },
      {
        lat: 41.8397358653566,
        lon: -71.3916477577732
      },
      {
        lat: 41.8351476451765,
        lon: -71.392699183707
      },
      {
        lat: 41.8377535388085,
        lon: -71.3981708900974
      }
    ]
    image = {
      height: 20,
      width: 20,
      id: 1,
      filename: 'demo.png',
      url: 'test/fixtures/demo.png',
      nodes_array: nodes_array
    }
    export = MockExport.new()

    # make a sample image
    system('mkdir -p public/system/images/1/original')
    system('cp test/fixtures/demo.png public/system/images/1/original/')
    system("mkdir -p public/warps/#{slug}")
    system("mkdir -p public/tms/#{slug}")
    system("touch public/warps/#{slug}/folder")
    assert File.exist?("public/warps/#{slug}/folder")

    coords = MapKnitterExporter.generate_perspectival_distort(
      scale, 
      slug,
      nodes_array,
      id, 
      image[:filename],
      image[:url],
      image[:height],
      image[:width],
      '' # root
    )
    assert coords
    assert MapKnitterExporter.get_working_directory(slug)
    assert MapKnitterExporter.warps_directory(slug)

    # get rid of existing geotiff
    system("rm -r public/warps/#{slug}/1-geo.tif")
    # make a sample image
    system('mkdir -p public/system/images/2/original/')
    system('cp test/fixtures/demo.png public/system/images/2/original/test.png')

    origin = MapKnitterExporter.distort_warpables(
      scale,
      [image], # TODO: here it also expects image to have a nodes_array object
      export,
      slug
    )
    lowest_x, lowest_y, warpable_coords = origin
    assert origin
    ordered = false

    system("mkdir -p public/warps/#{slug}")
    system("mkdir -p public/tms/#{slug}")
    # these params could be compressed - warpable coords is part of origin; are coords and origin required?
    assert MapKnitterExporter.generate_composite_tiff(
      warpable_coords,
      origin,
      [image],
      slug,
      ordered
    )

    assert MapKnitterExporter.generate_tiles('.', slug, root)

    assert MapKnitterExporter.zip_tiles(slug)

    assert MapKnitterExporter.generate_jpg(slug, '.')

    assert MapKnitterExporter.run_export(
      user_id,
      resolution,
      export,
      id,
      slug,
      root,
      scale,
      [image],
      ''
    )

    # test deletion of the files; they were already deleted in run_export, 
    # so let's make new dummy ones:
    # make a sample image
    system('mkdir -p public/system/images/2/original/')
    system('touch public/system/images/2/original/test.png')
    system("mkdir -p public/warps/#{slug}")
    system("mkdir -p public/tms/#{slug}")
    system("touch public/warps/#{slug}/folder")
    assert File.exist?("public/warps/#{slug}/folder")
    system("mkdir -p public/warps/#{slug}-working")
    system("touch public/warps/#{slug}/test.png")
    assert MapKnitterExporter.delete_temp_files(slug)
  end
end

class MockExport

  attr_accessor :status, :tms, :geotiff, :zip, :jpg, :user_id

  def save
    puts "saved"
  end

end
