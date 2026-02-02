import color

def hsv(h, s, v): // hue, saturation, value in [0, 1]
    // shamelessly stolen from https://github.com/python/cpython/blob/main/Lib/colorsys.py
    guard s != 0.0:
        return color { v, v, v, 1.0 }
    let i = int(h * 6.0) // XXX assume int() truncates!
    let f = (h * 6.0) - i
    let p = v * (1.0 - s)
    let q = v * (1.0 - s * f)
    let t = v * (1.0 - s * (1.0 - f))
    let r, g, b = switch i % 6:
        case 0: (v, t, p)
        case 1: (q, v, p)
        case 2: (p, v, t)
        case 3: (p, q, v)
        case 4: (t, p, v)
        case 5: (v, p, q)
        default: assert false // Cannot get here
    return color { r, g, b, 1.0 }

def hls(h, l, s): // hue, luminance, saturation in [0, 1]
    // shamelessly stolen from https://github.com/python/cpython/blob/main/Lib/colorsys.py
    if s == 0.0:
        return color { l, l, l, 1.0 }
    let m2 =
        if l <= 0.5:  l * (1.0 + s)
        else:         l + s - (l * s)
    let m1 = 2.0 * l - m2
    return color { v(m1, m2, h + 1.0/3.0), v(m1, m2, h), v(m1, m2, h - 1.0/3.0), 1.0 }

def v(m1, m2, hue):
    hue = hue % 1.0
    if hue < 1.0/6.0:
        return m1 + (m2 - m1) * hue*6.0
    if hue < 0.5:
        return m2
    if hue < 2.0/3.0:
        return m1 + (m2 - m1) * (2.0/3.0 - hue) * 6.0
    return m1