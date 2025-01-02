package main

import "core:math"
import "core:math/linalg"

update_fire :: proc(fire: ^Ent, world: ^World, delta_time: f32) {
    WANDER_DIST_SQUARED :: 10 * 10

    update_ent(fire, world, delta_time)

    if linalg.length2(fire.pos - fire.home) > WANDER_DIST_SQUARED {
        fire.vel += linalg.normalize(fire.home - fire.pos) * delta_time * 2.0
    }
}