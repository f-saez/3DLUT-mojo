# 3DLUT-mojo
3D lookup tables for Mojo

https://developer.nvidia.com/gpugems/gpugems2/part-iii-high-quality-rendering/chapter-24-using-lookup-tables-accelerate-color
https://lightillusion.com/what_are_luts.html

A 3D Lut, from a .cube file, is basically the same thing as an HaldClut with some exceptions.
A cube file is a text file, the data is Float32, it can be "huge" (up to 77 MBytes) and, more important, it is always associated with a colorspace.

An HaldClut is very often sRGB. 
A 3D lut is often Rec-709 or Log (more info here https://en.wikipedia.org/wiki/Log_profile, https://blog.frame.io/2020/02/03/color-spaces-101/ and https://postpace.io/blog/difference-between-raw-log-and-rec-709-camera-footage/).

One can easily convert from colorspace but if you apply a LUT designed for a Log colorspace on a sRGB image, you will end-up with some unwanted results.
Converting from/to Rec-709 is a easy because the two colorspace are very similar, even if they are not identical. Some people may even think it's not really necessary to convert between them.

Log, on the other side, well. There are many Log colorspace (https://en.wikipedia.org/wiki/Log_profile). The Log color space can be compared to the raw format in photography.  What we call Raw corresponds to a multitude of variations linked to various sensors. It's more or less the same with Log.
Converting from/to a Log colorspace is easy as long as you know the math behind it.

## I wanna play !

```
    var img = Image.from_ppm(Path("validation/woman.ppm")) 

    var a = LUT3D.from_file(Path("validation/lut1_rec709.cube")) 
    if a:
        var lut = a.take()
        lut.set_num_threads(8)
        lut.process(img, 0.9)    
```

The image is sRGB, the LUT Rec-709. Let's do the same thing but with a conversion :
```
    var img = Image.from_ppm(Path("validation/woman.ppm")) 

    var a = LUT3D.from_file(Path("validation/lut1_rec709.cube")) 
    if a:
        var lut = a.take()
        lut.set_num_threads(8)
        img.convert_to_rec709()
        lut.process(img, 0.9)
        img.convert_to_srgb()
        _ = img.to_ppm(Path("validation/woman_convert.ppm")) 
```

## Note

lut3d is not optimized. It's a naive implementation whose purpose is just to convert .cube file to Haldclut.


