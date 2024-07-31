
from pathlib import Path
from lut3d import LUT3D
from ppm import Image
from time import now

def main():

    var aaa = LUT3D.from_file(Path("validation/lut1_rec709.cube")) 
    if aaa:
        coef = 0.62
        lut = aaa.take()
        lut.set_num_threads(8) 
        img = Image.from_ppm(Path("validation").joinpath("woman"))
        tic = now()
        lut.process(img, coef)
        t = Float64(now() - tic) / 1e6
        print("time : ",t," ms")
        print("MPixels/s : ", img.get_mpixels()/t*1000)
        _ = img.to_ppm(Path("validation").joinpath("result"))    

