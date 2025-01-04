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

update_lightning :: proc(lightning: ^Ent, world: ^World, delta_time: f32) {
    update_ent(lightning, world, delta_time)

    player_ent: ^Ent
    for &ent in world.ents {
        if ent.variant == .Player {
            player_ent = &ent
            break
        }
    }
    if player_ent != nil && linalg.length2(player_ent.pos.xz - lightning.pos.xz) < 25 * 25 {
        lightning.vel.y = -50.0
    }
    if .Bottom in lightning.touch_flags {
        lightning.life_timer = (lightning.life_timer.? - delta_time)
    }
}