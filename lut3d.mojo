
from pathlib import Path
from algorithm import parallelize
from ppm import Image
from colorspace import rec709_to_srgb

alias BPP_LUT:Int = 3 # 4xf32 LUT isn't faster but use more memory

@value
struct Domain:
    var min : Float32
    var max : Float32

    fn __init__(inout self):
        self.min = 0
        self.max = 1

fn is_title(t : String) -> Optional[String]:
    var result = Optional[String](None)
    if t.startswith("TITLE"):
        try:
            var t1 = t.split("\"")
            if len(t1)>1:
                result = Optional[String](t1[1])
        finally:
            pass
    return result

fn is_size(t : String) -> Int:
    var result = -1
    if t.startswith("LUT_3D_SIZE"):
        try:
            var t1 = t.split(" ")
            if len(t1)>1:
                result = atol(t1[1])
        finally:
            pass
    return result    

fn is_domain_min(t : String, inout r : Domain, inout g : Domain, inout b : Domain) -> Bool:
    var result = False
    if t.startswith("DOMAIN_MIN"):
        try:
            var t1 = t.split(" ")
            if len(t1)==4:
                r.min = atof(t1[1])
                g.min = atof(t1[2])
                b.min = atof(t1[3])
                result = True
        finally:
            pass
    return result 

fn is_domain_max(t : String, inout r : Domain, inout g : Domain, inout b : Domain) -> Bool:
    var result = False
    if t.startswith("DOMAIN_MAX"):
        try:
            var t1 = t.split(" ")
            if len(t1)==4:
                r.max = atof(t1[1])
                g.max = atof(t1[2])
                b.max = atof(t1[3])
                result = True
        finally:
            pass
    return result 


fn extract_rgb(t : String, inout r : Float32, inout g : Float32, inout b : Float32) -> Bool:
    var result = False
    try:
        var t1 = t.split(" ")
        if len(t1)==3:
            r = atof(t1[0])
            g = atof(t1[1])
            b = atof(t1[2])
            result = True
    finally:
        pass
    return result 


@always_inline
fn clamp(x : Float32, a : Float32, b : Float32) -> Float32:
    if x<a:
        return a
    elif x>b:
        return b
    else:
        return x


@value
struct LUT3D:
    var rgb      : List[Float32]
    var name     : String
    var domain_r : Domain
    var domain_g : Domain
    var domain_b : Domain
    var nodes    : Int
    var nodes1   : Float32
    var nodes_square : Int
    var _num_threads : Int

    fn __init__(inout self, owned rgb : List[Float32], owned name : String, owned dr : Domain, owned dg : Domain, owned db : Domain, nodes : Int):
        self.rgb = rgb
        self.name = name
        self.domain_r = dr
        self.domain_g = dg 
        self.domain_b = db
        self.nodes = nodes
        self.nodes_square = self.nodes * self.nodes
        self.nodes1 = Float32(self.nodes - 1)
        self._num_threads = 1

    @always_inline
    fn set_num_threads(inout self, num_threads : Int):
        if num_threads>0 and num_threads<1024:
            self._num_threads = num_threads

    @always_inline
    fn get_num_threads(self) -> Int:
        return self._num_threads


    @staticmethod
    fn from_file(filename : Path) raises -> Optional[Self]:
        var result = Optional[Self](None)
        if filename.is_file():
            
            var t = String()
            with open(filename, "rb") as f:
                t = f.read() 
            
            var data_lut = False
            var size_found = False            
            var rgb = List[Float32]()
            
            var name = String("")
            var domain_r = Domain()
            var domain_g = Domain()
            var domain_b = Domain()
            var r:Float32 = 0
            var g:Float32 = 0
            var b:Float32 = 0
            var nodes = 0
            for line in t.splitlines(False):
                var l = line[].strip()
                if len(l)>0 and l.startswith('#')==False:
                    if not data_lut:
                        var z = is_title(l)
                        if z:
                            name = z.take()
                        else:
                            if size_found==False:
                                nodes = is_size(l)
                                if nodes>0:
                                    size_found = True
                                    rgb = List[Float32](capacity=nodes * nodes * nodes * BPP_LUT)
                            else:
                                if is_domain_min(l, domain_r, domain_g, domain_b)==False:
                                    if is_domain_max(l, domain_r, domain_g, domain_b)==False:
                                        data_lut = extract_rgb(l, r, g, b)
                                        rgb.append(r)
                                        rgb.append(g)
                                        rgb.append(b)

                    else:
                        _ = extract_rgb(l, r, g, b)
                        rgb.append(r)
                        rgb.append(g)
                        rgb.append(b)
            
            var lut = LUT3D( rgb, name, domain_r, domain_g, domain_b, nodes)
            result = Optional[Self](lut)       

        return result
    
    # TODO not good, need to be rewritten
    @always_inline
    fn get_value(self, index_r : Int, index_g : Int, index_b : Int) -> SIMD[DType.float32,4]:
        var idx = BPP_LUT * (index_r + self.nodes * (index_g + self.nodes * index_b))
        var r = self.rgb[idx]
        var g = self.rgb[idx+1]
        var b = self.rgb[idx+2]
        return SIMD[DType.float32,4](r,g,b,1)   

    fn tetrahedral_interpolation(self, rgba : SIMD[DType.float32,4]) -> SIMD[DType.float32,4]:
        var nodes1 = SIMD[DType.float32,4](self.nodes1)
        var rgb = rgba *  nodes1

        var tmp = rgb.__floor__()
        var prev_f32 = tmp.max(0)

        var delta = rgb - prev_f32

        var prev = prev_f32.cast[DType.int32]()

        tmp = rgb.__ceil__()
        tmp = tmp.min(nodes1)
        var next = tmp.cast[DType.int32]()

        var d_r = delta[0]
        var d_g = delta[1]
        var d_b = delta[2]

        var prev_r = prev[0].value
        var prev_g = prev[1].value
        var prev_b = prev[2].value

        var next_r = next[0].value
        var next_g = next[1].value
        var next_b = next[2].value     

        var c000 = self.get_value(prev_r, prev_g, prev_b)
        var c111 = self.get_value(next_r, next_g, next_b)

        var result:SIMD[DType.float32,4]
        if d_r>d_g:
            if d_g>d_b:
                var c100 = self.get_value(next_r,prev_g ,prev_b)
                var c110 = self.get_value(next_r,next_g ,prev_b)
                result  = c000 * SIMD[DType.float32,4](1. - d_r)  # (1. - d_r) * c000
                result += c100 * SIMD[DType.float32,4](d_r - d_g) # + (d_r - d_g) * c100
                result += c110 * SIMD[DType.float32,4](d_g - d_b) # + (d_g - d_b) * c110
                result += c111 * SIMD[DType.float32,4](d_b) # + (d_g - d_b) * c110
            elif d_r>d_b:
                var c100 = self.get_value(next_r,prev_g ,prev_b)
                var c101 = self.get_value(next_r,prev_g ,next_b)
                result  = c000 *  SIMD[DType.float32,4](1. - d_r) # (1. - d_r) * c000
                result += c100 * SIMD[DType.float32,4](d_r - d_b) # + (d_r - d_g) * c100
                result += c101 * SIMD[DType.float32,4](d_b - d_g) # + (d_g - d_b) * c101
                result += c111 * SIMD[DType.float32,4](d_g) #  + (d_g - d_b) * c111
            else:
                var c001 = self.get_value(prev_r, prev_g, next_b)
                var c101 = self.get_value(next_r,prev_g ,next_b)
                result  = c000 * SIMD[DType.float32,4](1. - d_b)
                result += c001 * SIMD[DType.float32,4](d_b - d_r)
                result += c101 * SIMD[DType.float32,4](d_r - d_g)
                result += c111 * SIMD[DType.float32,4](d_g)
        elif d_b>d_g:
            var c001 = self.get_value(prev_r, prev_g, next_b)
            var c011 = self.get_value(prev_r, next_g, next_b)
            result  = c000 * SIMD[DType.float32,4](1. - d_b)
            result += c001 * SIMD[DType.float32,4](d_b - d_g)
            result += c011 * SIMD[DType.float32,4](d_g - d_r)
            result += c111 * SIMD[DType.float32,4](d_r)
        elif d_b>d_r:
            var c010 = self.get_value(prev_r, next_g, prev_b)
            var c011 = self.get_value(prev_r, next_g, next_b)
            result  = c000 * SIMD[DType.float32,4](1. - d_g)
            result += c010 * SIMD[DType.float32,4](d_g - d_b)
            result += c011 * SIMD[DType.float32,4](d_b - d_r)
            result += c111 * SIMD[DType.float32,4](d_r)
        else:
            var c010 = self.get_value(prev_r, next_g, prev_b)
            var c110 = self.get_value(next_r,next_g ,prev_b)
            result  = c000 * SIMD[DType.float32,4](1. - d_g)
            result += c010 * SIMD[DType.float32,4](d_g - d_r)
            result += c110 * SIMD[DType.float32,4](d_r - d_b)
            result += c111 * SIMD[DType.float32,4](d_b)

        result[3] = rgba[3] # this should be done with insert but I have the single idea on how insert work
        return result

    fn process(self, inout img : Image, strength : Float32):
        var stride = img.get_stride()
        var height = img.get_height()
        var width = img.get_width()
        self.process_4xu8_(img.pixels, width, height, stride, strength)

    fn process_4xu8_(self, pixels : DTypePointer[DType.uint8], width : Int, height : Int, stride : Int, strength : Float32):
        var coef = clamp(strength,0,1)
        if coef>0:
            var div255 = SIMD[DType.float32,4](1./255.)
            var ps255 = SIMD[DType.float32,4](255.)
            var epi255 = SIMD[DType.int32,4](255)
            var epi0 = SIMD[DType.int32,4](0)
            
            var coef1  = SIMD[DType.float32,4](coef)
            var coef2 = SIMD[DType.float32,4](1-coef)

            @parameter
            fn process_line(y : Int):	
                var idx = y * stride
                for _ in  range(width):
                    var rgba = pixels.load[width=4](idx).cast[DType.float32]()
                    rgba *= div255
                    var rgba2 = self.tetrahedral_interpolation(rgba)
                    var rgba3 = (rgba2*coef1 + rgba*coef2) * ps255
                    var rgba4 = rgba3.cast[DType.int32]().clamp(epi0, epi255)
                    pixels.store[width=4](idx, rgba4.cast[DType.uint8]())
                    idx += 4

            parallelize[process_line](height, self.get_num_threads() )