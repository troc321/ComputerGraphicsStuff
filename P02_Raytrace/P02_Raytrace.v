import gfx

import os
import math

////////////////////////////////////////////////////////////////////////////////////////
// module aliasing to make code a little easier to read
// ex: replacing `gfx.Scene` with just `Scene`

type Point     = gfx.Point
type Vector    = gfx.Vector
type Direction = gfx.Direction
type Normal    = gfx.Normal
type Ray       = gfx.Ray
type Color     = gfx.Color
type Image     = gfx.Image
type Shape     = gfx.Shape
type LightType = gfx.LightType

type Intersection = gfx.Intersection
type Surface      = gfx.Surface
type Scene        = gfx.Scene


////////////////////////////////////////////////////////////////////////////////////////
// Comment out lines in array below to prevent re-rendering every scene.
// If you create a new scene file, add it to the list below.
// NOTE: **BEFORE** you submit your solution, uncomment all lines, so
//       your code will render all the scenes!
fn get_scene_filenames() []string {
    return [
        'P02_00_sphere',
        'P02_01_sphere_ambient',
        'P02_02_sphere_room',
        'P02_03_quad',
        'P02_04_quad_room',
        'P02_05_ball_on_plane',
        'P02_06_balls_on_plane',
        'P02_06.5_balls_on_plane_directional'
        'P02_07_reflections',
        'P02_08_antialiased',
        'P02_09_creative_artifact',
        'P02_10_tri'
    ]
}

fn intersect_ray_sphere(surface Surface, ray Ray) Intersection {
    a := 1.0
    e := ray.e
    ctr := surface.frame.o
    r := surface.radius
    ec := Vector{x: e.x - ctr.x, y: e.y - ctr.y, z: e.z - ctr.z}
    b := 2.0 * ray.d.dot(ec) 
    c := ec.length_squared() - r * r
    d := b*b - 4 * a * c

    if d < 0 {
        //ray did not intersect sphere
        return gfx.no_intersection
    }

    mut t := (-b - math.sqrt(d))/ 2.0
    if t < ray.t_min {
        t = (-b + math.sqrt(d))/ 2.0
    }
    if t < ray.t_min || t > ray.t_max {
        return gfx.no_intersection
    }

    p := ray.at(t)
    n := ctr.direction_to(p)
    return Intersection{
        frame: gfx.frame_oz(p, n),
        surface: surface,
        distance: t 
    } 
    /*
        if surface's shape is a sphere
            if ray does not intersect sphere, return no intersection
            compute ray's t value(s) at intersection(s)
            if ray's t is not a valid (between ray's min and max), return no intersection
            return intersection information
            NOTE: a ray can intersect a sphere in 0, 1, or 2 different points!

        if surface's shape is a quad
            if ray does not intersect plane, return no intersection
            compute ray's t value at intersection with plane
            if ray's t is not a valid (between min and max), return no intersection
            if intersection is outside the quad, return no intersection
            return intersection information
    */
}

fn intersect_ray_surface(surface Surface, ray Ray) Intersection {
    if surface.shape == Shape.sphere {
        return intersect_ray_sphere(surface, ray)
    }
    if surface.shape == Shape.quad {
        c := surface.frame.o
        e := ray.e
        d := ray.d
        n := surface.frame.z

        t := e.vector_to(c).dot(n) / d.dot(n)
        if t < ray.t_min || t > ray.t_max {
            return gfx.no_intersection
        }

        p := ray.at(t)
        if surface.radius < math.abs(p.x - surface.frame.o.x) || surface.radius < math.abs(p.y - surface.frame.o.y) || surface.radius < math.abs(p.z - surface.frame.o.z){
            return gfx.no_intersection
        }
        return Intersection{
        frame: gfx.frame_oz(p, n),
        surface: surface,
        distance: t
        } 

    }
    if surface.shape == Shape.triangle {
        c := surface.c
        a := surface.a
        b := surface.b
        e := ray.e
        d := ray.d
        eprime := c.vector_to(e)
        aprime := c.vector_to(a)
        bprime := c.vector_to(b)
        t := eprime.cross(aprime).dot(bprime) / d.cross(bprime).dot(aprime)
        alpha := d.cross(bprime).dot(eprime) / d.cross(bprime).dot(aprime) 
        beta := eprime.cross(aprime).dot(d) / d.cross(bprime).dot(aprime)
        zprime := a.vector_to(b).cross(a.vector_to(c)).as_direction()

        if !ray.valid_t(t) {
            return gfx.no_intersection
        }

        p := ray.at(t)
        if alpha < 0 || beta < 0 || (alpha + beta) > 1 {
            return gfx.no_intersection
        } 

        return Intersection{
        frame: gfx.frame_oz(p, zprime),
        surface: surface,
        distance: t
        } 
    }
    return gfx.no_intersection
}

fn create_creative_artifact(surface Surface, ray Ray) Intersection {
    if surface.shape == Shape.sphere {
        return intersect_ray_sphere(surface, ray)
    }
    if surface.shape == Shape.quad {
        c := surface.frame.o
        e := ray.e
        d := ray.d
        n := surface.frame.z

        t := e.vector_to(c).dot(n) / d.dot(n)
        if t < ray.t_min || t > ray.t_max {
            return gfx.no_intersection
        }

        p := ray.at(t)
        if surface.radius > math.abs(p.z - surface.frame.o.y){
            return gfx.no_intersection
        }
        return Intersection{
        frame: gfx.frame_oz(p, n),
        surface: surface,
        distance: t
        } 

    }
    return gfx.no_intersection
}

// Determines if given ray intersects any surface in the scene.
// If ray does not intersect anything, null is returned.
// Otherwise, details of first intersection are returned as an `Intersection` struct.
fn intersect_ray_scene(scene Scene, ray Ray) Intersection {
    mut closest := gfx.no_intersection  // type is Intersection

    if scene.surfaces.len >= 7 {
        for surface in scene.surfaces{
        intersection := create_creative_artifact(surface, ray)
        if intersection.miss() { 
            continue
        } else {
            if closest.is_closer(intersection) {
                continue
            }
        }
        closest = intersection
    }
    } else { 
    for surface in scene.surfaces{
        intersection := intersect_ray_surface(surface, ray)
        if intersection.miss() { 
            continue
        } else {
            if closest.is_closer(intersection) {
                continue
            }
        }
        closest = intersection
    }
    }

    /*
        for each surface in surfaces
            continue if ray did not hit surface ( ex: inter.miss() )
            continue if new intersection is not closer than previous closest intersection
            set closest intersection to new intersection
    */

    return closest  // return closest intersection
}

// Computes irradiance (as Color) from scene along ray
fn irradiance(scene Scene, ray Ray) Color {
    mut accum := gfx.black

    intersection := intersect_ray_scene(scene, ray)

    if intersection.miss() {
        return scene.background_color
    }

    kd := intersection.surface.material.kd
    ks := intersection.surface.material.ks
    n := intersection.surface.material.n
    normal := intersection.frame.z 

    //direction from intersection backwards
    view_dir := ray.d.negate()

    for light in scene.lights {
        mut light_dir := intersection.frame.o.direction_to(light.frame.o)
        mut shadow_ray := intersection.frame.o.ray_to(light.frame.o)

        mut light_response := light.kl.scale(
            1.0/intersection.frame.o.distance_squared_to(light.frame.o)
        )
        if light.lighttype == LightType.directional {
            light_response = light.kl
            light_dir = light.frame.z
            shadow_ray = intersection.frame.o.ray_along(light.frame.z)
        }
        if intersect_ray_scene(scene, shadow_ray).hit() {
            continue
        }
        h := (light_dir.as_vector() + view_dir.as_vector()).as_direction()
        accum.add_in(
            light_response.mult(
                kd.add(ks.scale(math.pow(math.max(0.0, normal.dot(h)), n)))
            ).scale(
                math.abs(normal.dot(light_dir))
            )
        )
    }

    //ambient hack
    accum.add_in(
        scene.ambient_color.mult(kd)
    )

    /*
        get scene intersection
        if not hit, return scene's background intensity
        accumulate color starting with ambient
        foreach light
            compute light response    (L)
            compute light direction   (l)
            compute light visibility  (V)
            compute material response (BRFD*cos) and accumulate
        if material has reflections (lightness of kr > 0)
            create reflection ray
            accumulate reflected light (recursive call) scaled by material reflection
        return accumulated color
    */

    if !intersection.surface.material.kr.is_black() {
        reflect_dir := view_dir.reflect(normal)
        reflect_ray := intersection.frame.o.ray_along(reflect_dir) 
        accum.add_in(
            intersection.surface.material.kr.mult(irradiance(scene, reflect_ray))
        )
    }
    return accum
}

// Computes image of scene using basic Whitted raytracer.
fn raytrace(scene Scene) Image {
    mut image := gfx.Image{ size:scene.camera.sensor.resolution }
    num_samples := scene.camera.sensor.samples
    image.clear()

    if num_samples == 1 {
        w := scene.camera.sensor.resolution.width
        h := scene.camera.sensor.resolution.height

        for row in 0 .. h {
            for col in 0 .. w {
                u := f64(col+0.5) / f64(w)
                v := f64(row+0.5) / f64(h)
                q := scene.camera.frame.o.add(
                    scene.camera.frame.x.scale((u - 0.5) * scene.camera.sensor.size.width)
                    ).add(
                        scene.camera.frame.y.scale(-(v - 0.5) * scene.camera.sensor.size.height)
                    ).sub(
                        scene.camera.frame.z.scale(scene.camera.sensor.distance)
                    )
                ray := scene.camera.frame.o.ray_through(q)
                image.set_xy(col, row, irradiance(scene,ray))
            }
        }
    } else {
        w := scene.camera.sensor.resolution.width
        h := scene.camera.sensor.resolution.height
         for i in 0 .. h {
            for j in 0 .. w {
                mut accum := gfx.black
                for ii in 0 .. num_samples {
                    for jj in 0 .. num_samples {
                        u := (i+(f64(ii)+0.5)/num_samples)/w
                        v := (j+(f64(jj)+0.5)/num_samples)/h
                        q := scene.camera.frame.o.add(
                            scene.camera.frame.x.scale((u - 0.5) * scene.camera.sensor.size.width)
                            ).add(
                            scene.camera.frame.y.scale(-(v - 0.5) * scene.camera.sensor.size.height)
                            ).sub(
                            scene.camera.frame.z.scale(scene.camera.sensor.distance))
                        ray := scene.camera.frame.o.ray_through(q)
                        accum.add_in(
                            irradiance(scene,ray)
                        )
                    }
                }
                image.set_xy(i, j, accum.scale(1/(math.pow(num_samples, 2)))) 
         }
    }
    } 

    /*
        if no anti-aliasing
            foreach image row (scene.resolution.height)
                foreach pixel in row (scene.resolution.width)
                    compute ray-camera parameters (u,v) for pixel
                    compute camera ray
                    set pixel to color raytraced with ray (`irradiance`)
        else
            foreach image row
                foreach pixel in row
                    init accumulated color
                    foreach sample in y
                        foreach sample in x
                            compute ray-camera parameters
                            computer camera ray
                            accumulate color raytraced with ray
                    set pixel to average of accum color (scale by number of samples)
        return rendered image
    */

    return image
}

fn main() {
    // Make sure images folder exists, because this is where all
    // generated images will be saved
    if !os.exists('output') {
        os.mkdir('output') or { panic(err) }
    }

    for filename in get_scene_filenames() {
        println('Rendering $filename' + '...')
        scene_path := 'scenes/' + filename + '.json'
        image_path := 'output/' + filename + '.ppm'
        scene := gfx.scene_from_file(scene_path)
        image := raytrace(scene)
        gfx.save_image(image:image, filename:image_path)
    }

    println('Done!')
}
