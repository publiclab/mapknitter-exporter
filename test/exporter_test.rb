require 'test_helper'

class ExporterTest < ActiveSupport::TestCase
  test "isolated exporter lib" do

    slug = "#{slug}"
    id = 1
    scale = 2
    images = images(:one) # need to source from test/fixtures/warpables.yml 
    average_scale
    export = map.export # replace map.export with a simple Export object
    root = "https://mapknitter.org"
    user = User.last # replace with static, look at what's actually used
    resolution = 20

    # make a sample image
    system('mkdir -p public/system/images/1/original')
    system('cp test/fixtures/demo.png public/system/images/1/original/')
    system("mkdir -p public/warps/#{slug}")
    system("mkdir -p public/tms/#{slug}")
    system("touch public/warps/#{slug}/folder")
    assert File.exist?("public/warps/#{slug}/folder")

    # TODO: create static images.nodes_array
    coords = Exporter.generate_perspectival_distort(
      scale, 
      slug,
      images.nodes_array,
      id, w.image_file_name,
      image.image,
      image.height,
      image.width
    )
    assert coords
    assert Exporter.get_working_directory(slug)
    assert Exporter.warps_directory(slug)

    # get rid of existing geotiff
    system("rm -r public/warps/#{slug}/1-geo.tif")
    # make a sample image
    system('mkdir -p public/system/images/2/original/')
    system('cp test/fixtures/demo.png public/system/images/2/original/test.png')

    origin = Exporter.distort_warpables(
      scale,
      images,
      export,
      slug
    )
    lowest_x, lowest_y, warpable_coords = origin
    assert origin
    ordered = false

    system("mkdir -p public/warps/#{slug}")
    system("mkdir -p public/tms/#{slug}")
    # these params could be compressed - warpable coords is part of origin; are coords and origin required?
    assert Exporter.generate_composite_tiff(
      warpable_coords,
      origin,
      [image],
      slug,
      ordered
    )

    assert Exporter.generate_tiles('', slug, root)

    assert Exporter.zip_tiles(slug)

    assert Exporter.generate_jpg(slug, root)

    assert Exporter.run_export(
      user,
      resolution,
      export,
      id,
      slug,
      root,
      average_scale,
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
    assert Exporter.delete_temp_files(slug)
  end
end

