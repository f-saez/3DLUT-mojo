
@always_inline
fn srgb_to_linear_rgb(e : Float32) -> Float32:
    if e <= 0.04045:
        return e / 12.92
    else:
        return  pow((e+0.055) / 1.055, 2.4)


@always_inline
fn linear_rgb_to_srgb(e : Float32) -> Float32:
    if e <= 0.0031308:
        return e *  12.92
    else:
        return pow(e, 1./2.4)*1.055 - 0.055


@always_inline
fn rec709_to_linear_rgb(e : Float32) -> Float32:
    if e < 0.081:
        return e / 4.5
    else:
       return pow( (e + 0.099) / 1.099, 1./0.45)

@always_inline
fn linear_rgb_to_rec709(e : Float32) -> Float32:
    if e < 0.018:
        return e * 4.5
    else:
        return pow(e, 0.45)*1.099 - 0.099

fn srgb_to_rec709(e : Float32) -> Float32:
    return linear_rgb_to_rec709( srgb_to_linear_rgb(e) )

fn rec709_to_srgb(e : Float32) -> Float32:
    return linear_rgb_to_srgb( rec709_to_linear_rgb(e))

fn srgb_to_rec709(inout e : SIMD[DType.float32,4]):
    e[0] = linear_rgb_to_rec709( srgb_to_linear_rgb(e[0]) )
    e[1] = linear_rgb_to_rec709( srgb_to_linear_rgb(e[1]) )
    e[2] = linear_rgb_to_rec709( srgb_to_linear_rgb(e[2]) )
    e[3] = linear_rgb_to_rec709( srgb_to_linear_rgb(e[3]) )
    

fn rec709_to_srgb(inout e : SIMD[DType.float32,4]):
    e[0] = linear_rgb_to_srgb( rec709_to_linear_rgb(e[0]))
    e[1] = linear_rgb_to_srgb( rec709_to_linear_rgb(e[1]))
    e[2] = linear_rgb_to_srgb( rec709_to_linear_rgb(e[2]))
    e[3] = linear_rgb_to_srgb( rec709_to_linear_rgb(e[3]))