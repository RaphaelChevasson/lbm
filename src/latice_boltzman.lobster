import std
import vec
import color
import gl

import color_conversions // hls(h,l,s)->color
import float_formatting // fmt(float)->string and fmt(float2)->string

gl.window("Latice Boltzman Fluid Sim", 1280, 720)
//let input_image = "anon.png"
let grid_size = int2 { 16, 9 } * 5
let conn = 9 // connectivity (including self)
let distrib_size = int3(grid_size, conn)
//let wrap_around = false
let status_bar_height = 0.04 // 0: hiden, 1: take 100% screen space

/*let neighbor_directions, dir_weights = switch (d, conn):
    case (2, 9): ([ int2 { -1, 0 }, int2 { 1, 0 }, int2 {  0, -1 }, int2 { 0,  1 },
                   int2 { -1, -1 }, int2 { 1, 1 }, int2 { 1, -1 }, int2 { -1, 1 }, int2 {  0, 0 }],
                 [1/36, 1/9, 1/36, 1/9, 4/9, 1/9, 1/36, 1/9, 1/36])
    default: assert false*/
let dir_dpos = [ int2 { -1, 0 }, int2 { 1, 0 }, int2 {  0, -1 }, int2 { 0,  1 },
                 int2 { -1, -1 }, int2 { 1, 1 }, int2 { 1, -1 }, int2 { -1, 1 }, int2 {  0, 0 }]
let dir_weights = [1./9., 1./9., 1./9., 1./9., 1./36., 1./36., 1./36., 1./36., 4./9.]
let speed_of_sound = 1.0 / sqrt(3.0)
let relaxation_factor = 0.55

var iteration = 0
let density = mapxy(grid_size): 1.0
let velocity = mapxy(grid_size): float2_0
let speed_distrib = mapxyz(distrib_size): equilibrium_distrib(_)
def reset():
    iteration = 0
    forxy(grid_size): density[_] = 1.0
    forxy(grid_size): velocity[_] = float2_0
    forxyz(distrib_size): speed_distrib[_] = equilibrium_distrib(_)

let old_speed_distrib = mapxyz(distrib_size): 0.0
let old_density_debug = mapxy(grid_size): 0.0 // only stored for debugging purpose
let old_velocity_debug = mapxy(grid_size): float2_0 // only stored for debugging purpose

def modulo(x, n): return (x % n + n) % n // in [0,n[ range, contrary to % which can be negative
def isin(ij, size): return all(ij >= int2_0) and all(ij < size)
def pow2(v): return v*v


//let tex = gl.load_texture(input_image)
//assert tex

def collide(): // diffusion
    forxyz(distrib_size) ijd:
        speed_distrib[ijd] = lerp(speed_distrib[ijd], equilibrium_distrib(ijd), relaxation_factor)

def equilibrium_distrib(ijd): // what to difuse toward = perfect gas rest state
    let pos = ijd.xy
    let dir = ijd.z
    let order1 = 3.0 * dot(velocity[pos], float(dir_dpos[dir])) / speed_of_sound.pow2() // order 1 term
    let corr = 3.0 * dot(velocity[pos], velocity[pos]) / speed_of_sound.pow2() // correction term for order 2 accuracy
    return dir_weights[dir] * density[pos] * (
        1.0 + order1 + 0.5 * (order1.pow2() - corr)
    )

def stream(): // advection
    forxyz(distrib_size) ijd:
        old_speed_distrib[ijd] = speed_distrib[ijd]
    forxyz(distrib_size) ijd:
        let pos = ijd.xy
        let dir = ijd.z
        let dest = modulo(pos + dir_dpos[dir], grid_size)
        speed_distrib[ijd] = old_speed_distrib[int3(dest, dir)]

def update_macroscopic_values():
    forxy(grid_size) ij:
        old_density_debug[ij] = density[ij]
        old_velocity_debug[ij] = velocity[ij]

        var sum = 0.0
        for(conn) dir:
            sum += speed_distrib[int3(ij, dir)]
        density[ij] = sum

        var mean = float2_0
        for(conn) dir:
            mean += speed_distrib[int3(ij, dir)] * float(dir_dpos[dir])
        mean /= float(conn)
        velocity[ij] = mean

def momentum(ij): // TOCHECK !!! (maybe the microscopic momentum is more appropriate and invariant?)
    return density[ij] * dot(velocity[ij], velocity[ij])

def stats():
    var tot_density = 0.0
    forxy(grid_size): tot_density += density[_]
    var tot_momentum = 0.0
    forxy(grid_size): tot_momentum += momentum(_)
    return (tot_density, tot_momentum)

def add_fluid(center, radius=1, pres=2.0):
    forxy(radius * int2_1) ij:
        let pos = modulo(center + ij - radius/2, grid_size)
        density[pos] = pres
def move_fluid(center, radius=1, vel=float2_0):
    forxy(radius * int2_1) ij:
        let pos = modulo(center + ij - radius/2, grid_size)
        velocity[pos] = vel

add_fluid(grid_size / 2 - int2 {5, 0}, 2, 10.0)
add_fluid(grid_size / 2 + int2 {5, 0}, 2, 10.0)

def status_bar(res, status_bar_res, mouse_grid_pos, up_text_margin = 4):
    guard status_bar_res.y > 0
    gl.set_font_name("data/fonts/Droid_Sans/DroidSans.ttf")
    let w, h = status_bar_res.x, status_bar_res.y
    let ij = mouse_grid_pos
    let i, j = ij.x, ij.y
    gl.translate(float2 { 0.0, res.y - h}):
        gl.color(color_darkest_grey)
        gl.rect(float2 { w, h })

        gl.color(color_white)
        gl.line(float2 { 0.0, 0.0 },
                float2 {   w, 0.0 }, 1.0)
        
        let left_text =
            if isin(ij, grid_size): "Pos ({i}, {j}) | Density {fmt(density[ij])} | Vel {fmt(velocity[ij])} | Mom {fmt(momentum(ij))}"
            else: ""
        
        let tot_density, tot_momentum = stats()
        let ms = int(10000.0 * gl.delta_time()) / 10
        let right_text = "Iteration {iteration} | {ms}ms/it | Tot Density {fmt(tot_density)}"
        gl.color(color_white)
        gl.set_font_size(h-up_text_margin)
        gl.translate(float2 { 0.0, up_text_margin } ):
            gl.text(left_text)
            let right_text_w = gl.text_size(right_text).x
            gl.translate(float2 { (w - right_text_w), 0.0 }):
                gl.text(right_text)

while gl.frame() and not gl.button("escape"):
    let res = gl.window_size()
    let status_bar_res = int2 { res.x, int(res.y * status_bar_height) }
    let grid_res = res - int2_y * status_bar_res
    let mouse_grid_pos = gl.mouse_pos(0) * grid_size / grid_res
    let mouse_grid_vel = clamp(
        float(gl.mouse_delta(0) * grid_size) / float(grid_res), // no /dt because both mouse and fluid velocities are in dist/dt
        -0.2 * speed_of_sound.pow2() * float2_1, 0.2 * speed_of_sound.pow2() * float2_1 // why do we need to be so conservative here?
    )

    if gl.button("r"):
        reset()

    if gl.button("mouse1"):
        add_fluid(mouse_grid_pos, 10, 2.0)
    if gl.button("mouse3"): // right button
        add_fluid(mouse_grid_pos, 10, 0.0) // remove fluid
    if gl.button("mouse2"): // middle button
        move_fluid(mouse_grid_pos, 10, mouse_grid_vel)

    let right = if gl.button("right") or gl.button("d"): 1.0 else: 0.0
    let left = if gl.button("left") or gl.button("q"): 1.0 else: 0.0
    if left or right:
        for(grid_size.y):
            //velocity[int2 { 0, _ }] = float2 { 0.5 * speed_of_sound.pow2(), 0.0 }
            density[int2 {             0, _ }] = 1.0 + right - left
            density[int2 { grid_size.x-1, _ }] = 1.0 + left - right

    if 1: // if gl.button("space"):
        iteration += 1
        collide()
        stream()
        update_macroscopic_values()

    gl.clear color_black
    //gl.set_shader("textured")
    //gl.set_primitive_texture(0, tex)
    gl.scale(float(grid_res) / float(grid_size)):
        forxy(grid_size) ij:
            // gl.color color { density[ij] * 0.5, 0.5 + 10.0 * velocity[ij].x, 0.5 + 10.0 * velocity[ij].y, 1.0 }
            gl.color hls(
                modulo(velocity[ij].atan2(), 360.0) / 360.0,
                // 0.5,
                clamp(density[ij] * 0.5, 0.0, 1.0),
                //clamp(1.0 + 0.05 * log2( momentum(ij) ), 0.0, 1.0), // show momentum
                clamp(velocity[ij].magnitude() * 3.0 / speed_of_sound, 0.0, 1.0)
            )
            gl.translate ij:
                gl.unit_square()
    status_bar(res, status_bar_res, mouse_grid_pos)

