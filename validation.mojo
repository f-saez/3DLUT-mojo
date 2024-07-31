
from ppm import Image
from pathlib import Path
from testing import assert_true, assert_equal, assert_almost_equal

from lut3d import LUT3D

fn almost_equal(a : Image, b : Image) -> Bool:
    """
        Comparing two images, one reference and one created by the same library
        but on a different architecture or a different version or with a different codec could result in
        small and invisible differences
        So to prevent a bunch of troubles, I choose to allow a small percentage of differences.
        something like 2% of the pixels could have a 2% difference.
    """
    var result = False
    var w = a.get_width()
    var h = a.get_height()
    var num_pixels = w*h
    var num_diff = 0
    if w==b.get_width() and h==b.get_height() and a.get_stride()==b.get_stride():
        # a dumb way to do that, but who cares ?
        for y in range(h):
            var idx = y*a.get_stride()
            for x in range(w):
                var delta = abs(a.pixels[idx].cast[DType.int32]() - b.pixels[idx].cast[DType.int32]())
                if delta>=5:
                    num_diff += 1
                else:
                    delta = abs(a.pixels[idx+1].cast[DType.int32]() - b.pixels[idx+1].cast[DType.int32]())
                    if delta>5:
                        num_diff += 1
                    else:                                    
                        delta = abs(a.pixels[idx+2].cast[DType.int32]() - b.pixels[idx+2].cast[DType.int32]())                            
                        if delta>5:
                            num_diff += 1
                        else:                                    
                            delta = abs(a.pixels[idx+3].cast[DType.int32]() - b.pixels[idx+3].cast[DType.int32]())                                
                            if delta>5:
                                num_diff += 1                                                                            
        result = Float32(num_diff) / Float32(num_pixels) <= 0.02
    return result


fn validation_lut_file() raises :

    var a = LUT3D.from_file(Path("validation/lut_validation.cube")) 
    assert_true(a)
    var lut = a.take()
    assert_equal(lut.nodes, 32)
    assert_almost_equal(lut.domain_r.min, 0.1)
    assert_almost_equal(lut.domain_g.min, 0.2)
    assert_almost_equal(lut.domain_b.min, 0.3)
    assert_almost_equal(lut.domain_r.max, 1.4)
    assert_almost_equal(lut.domain_g.max, 1.5)
    assert_almost_equal(lut.domain_b.max, 1.6)
    assert_equal(lut.name,"LUT name")
    assert_almost_equal(lut.rgb[0], 0.0)
    assert_almost_equal(lut.rgb[1], 0.0)
    assert_almost_equal(lut.rgb[2], 0.0)
    
    assert_almost_equal(lut.rgb[3], 0.0)
    assert_almost_equal(lut.rgb[4], 0.0)
    assert_almost_equal(lut.rgb[5], 0.0)

    assert_almost_equal(lut.rgb[6], 0.017792)
    assert_almost_equal(lut.rgb[7], 0.003662)
    assert_almost_equal(lut.rgb[8], 0.003662)

    assert_almost_equal(lut.rgb[9],  0.832886)
    assert_almost_equal(lut.rgb[10], 0.831879)
    assert_almost_equal(lut.rgb[11], 0.490021)

    assert_almost_equal(lut.rgb[12], 0.856781)
    assert_almost_equal(lut.rgb[13], 0.838013)
    assert_almost_equal(lut.rgb[14], 0.495697)

fn validation_lut_image() raises :
    var img = Image.from_ppm(Path("validation/woman.ppm")) 
    var img_ref = Image.from_ppm(Path("validation/woman_ref_no_convert.ppm")) 
    assert_equal(img.get_width(), img_ref.get_width())
    assert_equal(img.get_height(), img_ref.get_height())

    var a = LUT3D.from_file(Path("validation/lut1_rec709.cube")) 
    assert_true(a)
    var lut = a.take()
    assert_equal(lut.nodes, 32)

    lut.process(img, 0.6)
    assert_true( almost_equal(img, img_ref) )

    img = Image.from_ppm(Path("validation/woman.ppm")) 
    img_ref = Image.from_ppm(Path("validation/woman_ref_convert.ppm")) 
    assert_equal(img.get_width(), img_ref.get_width())
    assert_equal(img.get_height(), img_ref.get_height())

    img.convert_to_rec709()
    lut.process(img, 0.6)
    img.convert_to_srgb()
    assert_true( almost_equal(img, img_ref) )


def main():
    validation_lut_image()  
    validation_lut_file()

