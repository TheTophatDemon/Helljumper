package main

import rl "vendor:raylib"
import "core:math/linalg"
import "core:fmt"

import "assets"

Touching :: enum u8 {
    Bottom,
    Top,
    Left,
    Right,
    Front,
    Back,
}

EntVariant :: enum {
    Player,
    Shallot,
    Hazard,
    Decoration, // Stuff not interacted with
}

Ent :: struct {
	pos, home, vel: rl.Vector3,
    gravity: f32,
    life_timer: Maybe(f32),
    extents: rl.Vector3, // Half size of the collision box. Top of the box is extents.y * 2 units above the ent's position.
    sprite_origin: rl.Vector2,
	tex: rl.Texture2D,
	anim_player: assets.AnimPlayer,
    update_func: proc(ent: ^Ent, world: ^World, delta_time: f32),
    touch_flags: bit_set[Touching; u8],
    touched_tiles: bit_set[TileType; u64],
    max_speed: f32,
    time_since_last_land: f32,
    needs_outline, needs_drop_shadow: bool,
    variant: EntVariant,
}

update_ent :: proc(ent: ^Ent, world: ^World, delta_time: f32) {
    assets.update_anim_player(&ent.anim_player, delta_time)
    
    ent.vel.y += ent.gravity * delta_time
    next_pos := ent.pos + ent.vel * delta_time
    ent.touch_flags = {}
    ent.touched_tiles = {}
    if ent.extents != {} {
        if ent.vel.y < 0 {
            ent.pos.y = move_and_collide_ent(ent, world, ent.pos.y, next_pos.y, .Bottom)
        } else {
            ent.pos.y = move_and_collide_ent(ent, world, ent.pos.y, next_pos.y, .Top)
        }
        if ent.vel.z > 0 {
            ent.pos.z = move_and_collide_ent(ent, world, ent.pos.z, next_pos.z, .Front)
        } else {
            ent.pos.z = next_pos.z
        }
        if ent.vel.x < 0 {
            ent.pos.x = move_and_collide_ent(ent, world, ent.pos.x, next_pos.x, .Left)
        } else if ent.vel.x > 0 {
            ent.pos.x = move_and_collide_ent(ent, world, ent.pos.x, next_pos.x, .Right)
        }
    } else {
        ent.pos = next_pos
    }
    if .Bottom in ent.touch_flags {
        ent.vel.y = 0.0
        ent.time_since_last_land = 0.0
    } else {
        ent.time_since_last_land += delta_time
    }
}

move_and_collide_ent :: proc(ent: ^Ent, world: ^World, from, to: f32, direction: Touching) -> f32 {
    bbox_pos := ent.pos + rl.Vector3{0.0, ent.extents.y, 0.0}
    movement_bbox: rl.BoundingBox
    switch direction {
        case .Front: movement_bbox = {
            min = rl.Vector3{ bbox_pos.x - ent.extents.x + 0.01, bbox_pos.y - ent.extents.y + 0.01, from },
            max = rl.Vector3{ bbox_pos.x - 0.02, bbox_pos.y - 0.02, to } + ent.extents,
        }
        case .Left: movement_bbox = {
            min = rl.Vector3{ to, bbox_pos.y + 0.01, bbox_pos.z + 0.01 } - ent.extents,
            max = rl.Vector3{ from, bbox_pos.y + ent.extents.y - 0.02, bbox_pos.z + ent.extents.z - 0.02 },
        }
        case .Right: movement_bbox = {
            min = rl.Vector3{ from, bbox_pos.y - ent.extents.y + 0.01, bbox_pos.z - ent.extents.z + 0.01 },
            max = rl.Vector3{ to, bbox_pos.y - 0.02, bbox_pos.z - 0.02 } + ent.extents,
        }
        case .Bottom: movement_bbox = {
            min = rl.Vector3{ bbox_pos.x - ent.extents.x + 0.01, to, bbox_pos.z - ent.extents.z + 0.01 },
            max = rl.Vector3{ bbox_pos.x + ent.extents.x - 0.02, from + ent.extents.y, bbox_pos.z + ent.extents.z - 0.02 },
        }
        case .Top: movement_bbox = {
            min = rl.Vector3{ bbox_pos.x - ent.extents.x + 0.01, from + ent.extents.y, bbox_pos.z - ent.extents.z + 0.01 },
            max = rl.Vector3{ bbox_pos.x + ent.extents.x - 0.02, to + ent.extents.y * 2.0, bbox_pos.z + ent.extents.z - 0.02 },
        }
        case .Back:
    }
    for &chunk in containing_chunks(world, movement_bbox) {
        tile_min_x := int(movement_bbox.min.x - chunk.pos.x)
        tile_min_y := int(movement_bbox.min.y - chunk.pos.y)
        tile_min_z := int(movement_bbox.min.z - chunk.pos.z)
        tile_max_x := int(movement_bbox.max.x - chunk.pos.x)
        tile_max_y := int(movement_bbox.max.y - chunk.pos.y)
        tile_max_z := int(movement_bbox.max.z - chunk.pos.z)
        switch direction {
            case .Front:
                for y in tile_min_y..=tile_max_y {
                    if y < 0 || y >= CHUNK_HEIGHT do continue
                    for x in tile_min_x..=tile_max_x {
                        if x < 0 || x >= CHUNK_WIDTH do continue
                        for z in tile_min_z..=tile_max_z {
                            if z < 0 || z >= CHUNK_LENGTH do continue
                            if tile := chunk.tiles[y][z][x]; direction not_in TilePassThrough[tile] {
                                next := f32(z) - ent.extents.z
                                ent.touch_flags |= {.Front}
                                ent.touched_tiles += {tile}
                                if next < from do return from
                                return next
                            }
                        }
                    }
                }
            case .Bottom:
                for y := tile_max_y; y >= tile_min_y; y -= 1 {
                    if y < 0 || y >= CHUNK_HEIGHT do continue
                    for x in tile_min_x..=tile_max_x {
                        if x < 0 || x >= CHUNK_WIDTH do continue
                        for z in tile_min_z..=tile_max_z {
                            if z < 0 || z >= CHUNK_LENGTH do continue
                            if tile := chunk.tiles[y][z][x]; direction not_in TilePassThrough[tile] {
                                next := f32(y) + 1.0
                                ent.touch_flags |= {.Bottom}
                                ent.touched_tiles += {tile}
                                // Leave this out so you can warp to the top of arrow tiles
                                // if next > from do return from
                                return next
                            }
                        }
                    }
                }
            case .Top:
                for y in tile_min_y..=tile_max_y {
                    if y < 0 || y >= CHUNK_HEIGHT do continue
                    for x in tile_min_x..=tile_max_x {
                        if x < 0 || x >= CHUNK_WIDTH do continue
                        for z in tile_min_z..=tile_max_z {
                            if z < 0 || z >= CHUNK_LENGTH do continue
                            if tile := chunk.tiles[y][z][x]; direction not_in TilePassThrough[tile] {
                                next := f32(y) - ent.extents.y * 2.0
                                ent.touch_flags |= {.Top}
                                ent.touched_tiles += {tile}
                                if next < from do return from
                                return next
                            }
                        }
                    }
                }
            case .Left:
                for y in tile_min_y..=tile_max_y {
                    if y < 0 || y >= CHUNK_HEIGHT do continue
                    for z in tile_min_z..=tile_max_z {
                        if z < 0 || z >= CHUNK_LENGTH do continue
                        for x := tile_max_x; x >= tile_min_x; x -= 1 {
                            if x < 0 || x >= CHUNK_WIDTH do continue
                            if tile := chunk.tiles[y][z][x]; direction not_in TilePassThrough[tile] {
                                next := f32(x) + 1.0 + ent.extents.x
                                ent.touch_flags |= {.Left}
                                ent.touched_tiles += {tile}
                                if next > from do return from
                                return next
                            }
                        }
                    }
                }
            case .Right:
                for y in tile_min_y..=tile_max_y {
                    if y < 0 || y >= CHUNK_HEIGHT do continue
                    for z in tile_min_z..=tile_max_z {
                        if z < 0 || z >= CHUNK_LENGTH do continue
                        for x in tile_min_x..=tile_max_x {
                            if x < 0 || x >= CHUNK_WIDTH do continue
                            if tile := chunk.tiles[y][z][x]; direction not_in TilePassThrough[tile] {
                                next := f32(x) - ent.extents.x - 0.01
                                ent.touch_flags |= {.Right}
                                ent.touched_tiles += {tile}
                                if next < from do return from
                                return next
                            }
                        }
                    }
                }
            case .Back:
        }
    }

    return to
}

draw_ent :: proc(ent: ^Ent) {
    if !rl.IsTextureValid(ent.tex) do return
    src := assets.anim_player_current_rect(&ent.anim_player) if ent.anim_player.anims != nil else rl.Rectangle{width = f32(ent.tex.width), height = f32(ent.tex.height)}
    dest := rl.Rectangle{width = src.width, height = src.height}
    dest.x, dest.y = world_to_screen_coords(ent.pos.x, ent.pos.y, ent.pos.z)
    rl.DrawTexturePro(ent.tex, src, dest, ent.sprite_origin, 0.0, rl.WHITE)
    
    // Draw origin for debugging purposes
    // rl.DrawCircle(i32(dest.x), i32(dest.y), 2.0, rl.WHITE)
}

draw_ent_outline :: proc(ent: ^Ent) {
    before_layer := ent.anim_player.layer_idx
    defer ent.anim_player.layer_idx = before_layer

    if ent.anim_player.anims != nil && len(ent.anim_player.anims.meta.layers) > 1 {
        // The outline is stored on layer 1 in the sprite JSON
        // If this layer doesn't exist then simply draw the sprite again.
        ent.anim_player.layer_idx = 1
    }
    
    draw_ent(ent)
}

ent_bbox :: proc(ent: ^Ent) -> rl.BoundingBox {
    return rl.BoundingBox{
        min = rl.Vector3{ent.pos.x - ent.extents.x, ent.pos.y, ent.pos.z - ent.extents.z},
        max = rl.Vector3{ent.pos.x + ent.extents.x, ent.pos.y + ent.extents.y * 2.0, ent.pos.z + ent.extents.z},
    }
}