def log10(x): return log2(x) / log2(10.0)

def round_sig(f:float, sig_digits = 2):
    let p = floor(log10(abs(f)))
    let scale = pow(10.0, sig_digits - 1 - p)
    return round(f * scale) / scale

def fmt(f:float, sig_digits = 2):
    if not f or f == inf or f == -inf or string(f).find_string("nan") >= 0:
        return string(f)

    let af = abs(f)
    let p = floor(log10(af))
    let r = round_sig(f, sig_digits)

    // Decide between fixed and scientific
    if p >= -2 and p < sig_digits:
        // fixed notation
        return string(r)
    else:
        // scientific notation
        let e = floor(log10(abs(r)))
        let m = r / pow(10.0, e)
        let m2 = round_sig(m, sig_digits)
        return string(m2) + "e" + string(e)

def fmt(f: float2, sig_digits = 2):
    return "({fmt(f.x, sig_digits)}, {fmt(f.y, sig_digits)})"