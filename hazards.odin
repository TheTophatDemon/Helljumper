package main

import rl "vendor:raylib"

import "core:math"
import "core:math/linalg"

import "assets"

update_fire :: proc(fire: ^Ent, world: ^World, delta_time: f32) {
    WANDER_DIST_SQUARED :: 10 * 10

    update_ent(fire, world, delta_time)

    if linalg.length2(fire.pos - fire.home) > WANDER_DIST_SQUARED {
        fire.vel += linalg.normalize(fire.home - fire.pos) * delta_time * 2.0
    }
}

update_lightning :: proc(lightning: ^Ent, world: ^World, delta_time: f32) {
    previous_y := lightning.pos.y
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
        if lightning.life_timer.? <= 0.0 {
            // Destroy the tiles surrounding the bolt
            for &chunk in containing_chunks(world, ent_bbox(lightning)) {
                tile_x := int(lightning.pos.x - chunk.pos.x)
                tile_z := int(lightning.pos.z - chunk.pos.z)
                for x in max(0, tile_x - 2)..=min(CHUNK_WIDTH - 1, tile_x + 2) {
                    for z in max(0, tile_z - 2)..=min(CHUNK_LENGTH - 1, tile_z + 2) {
                        for y in 0..<CHUNK_HEIGHT {
                            if linalg.length2(rl.Vector2{f32(x) + 0.5, f32(z) + 0.5} + chunk.pos.xz - lightning.pos.xz) < 4.0 {
                                chunk.tiles[y][z][x] = .Empty
                            }
                        }
                    }
                }
            }
        }
    } else if lightning.pos.y < CHUNK_HEIGHT && previous_y >= CHUNK_HEIGHT {
        rl.PlaySound(assets.Sounds[.Lightning])
    }
}