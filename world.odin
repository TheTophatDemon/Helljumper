package main

import rl "vendor:raylib"
import "core:math/rand"
import "core:path/filepath"
import "core:reflect"
import "core:fmt"
import "core:slice"
import "core:math/linalg"
import "core:math"

import "assets"

CHUNK_WIDTH :: 16
CHUNK_HEIGHT :: 16
CHUNK_LENGTH :: 64
CHUNK_COUNT :: 3 // Number of chunks loaded at any one time.
TILE_SPACING_HORZ :: 16
TILE_SPACING_VERT :: 8
KILL_PLANE_OFFSET :: 20.0

TileType :: enum u8 {
	Empty,
	Solid,
    Cloud,
    Pillar,
    Bridge,
    Spike,
    HellBridge,
    Rock,
    LavaRock,
}

TileRects := [TileType]rl.Rectangle{
	.Empty = rl.Rectangle{},
	.Solid = rl.Rectangle{0, 0, 32, 32},
    .Cloud = rl.Rectangle{32, 0, 32, 32},
    .Pillar = rl.Rectangle{64, 0, 32, 32},
    .Bridge = rl.Rectangle{64+32, 0, 32, 32},
    .Spike = rl.Rectangle{0, 32, 32, 32},
    .HellBridge = rl.Rectangle{32, 32, 32, 32},
    .Rock = rl.Rectangle{64, 32, 32, 32},
    .LavaRock = rl.Rectangle{96, 32, 32, 32},
}

Chunk :: struct {
    tiles: [CHUNK_HEIGHT][CHUNK_LENGTH][CHUNK_WIDTH]TileType,
    pos: rl.Vector3, // Bottom back left corner
}

ChunkTile :: struct {
	chunk: ^Chunk,
	coords: [3]int,
}

World :: struct {
    chunks: [CHUNK_COUNT]Chunk,
    ents: [dynamic]Ent,
    heaven: bool,
    camera: rl.Camera2D,
    distance_traveled: f32,
    game_lost, heaven_transition: bool,
}

init_world :: proc(world: ^World, heaven: bool) {
    if world.ents != nil {
        delete(world.ents)
    }

    world^ = {
        heaven = heaven,
    }
    chunks_arr := assets.HeavenChunks if heaven else assets.HellChunks
    world.chunks[0].pos = rl.Vector3{0.0, 0.0, -CHUNK_LENGTH}
	world.chunks[2].pos = rl.Vector3{0.0, 0.0, CHUNK_LENGTH}
	world.ents = make([dynamic]Ent, 0, 100)
	load_next_chunk(world, 0, rand.int_max(len(chunks_arr)))
    load_next_chunk(world, 1, 0)
	load_next_chunk(world, 2, rand.int_max(len(chunks_arr)))
	// load_next_chunk(world, 2, 4)

	world.camera = rl.Camera2D{
		offset = rl.Vector2{WINDOW_WIDTH / 4, WINDOW_HEIGHT / 2},
		zoom = 2,
	}

	// Spawn player
    player_pos := rl.Vector3{8.0, 16.0, 3.0}
	append(&world.ents, Ent{
		pos = player_pos,
		tex = assets.Gfx[.Player],
		sprite_origin = rl.Vector2{16.0, 46.0},
		anim_player = assets.AnimPlayer{
			anims = &assets.Anims[.Player],
		},
		extents = rl.Vector3{0.25, 1.0, 0.25},
		update_func = update_player,
		gravity = -20.0,
        needs_outline = true,
        needs_drop_shadow = true,
        variant = .Player,
	})

    if heaven {
        next_song = assets.Songs[.TheLonging]
    } else {
        next_song = assets.Songs[.IgnisMagnis]
    }
}

update_world :: proc(world: ^World, delta_time: f32, score: f32) -> (new_score: f32) {
    SCROLL_SPEED :: 14.0
    
    new_score = score

    player_z_before_update: f32
    for &ent in world.ents {
        if ent.variant == .Player {
            player_z_before_update = ent.pos.z
        }
        if ent.update_func != nil do ent.update_func(&ent, world, delta_time)
    }
    #reverse for &ent, e in world.ents {
        fell_behind := ent.pos.z < world.distance_traveled - KILL_PLANE_OFFSET
        life_time, has_life_time := ent.life_timer.?
        if ent.variant != .Player && (fell_behind || (has_life_time && life_time <= 0)) {
            unordered_remove(&world.ents, e)
        }
    }

    // Must do this after entities are removed in case player gets shifted around in the array.
    player_ent: ^Ent
    for &ent in world.ents {
        if ent.variant == .Player {
            player_ent = &ent
            break
        }
    }
    
    distance_gained: f32
    if (player_ent == nil || player_ent.pos.z > 6.0) && !world.heaven_transition {
        distance_gained = SCROLL_SPEED * delta_time
        world.distance_traveled += distance_gained
    }
    when ODIN_DEBUG {
        if rl.IsKeyDown(.GRAVE) {
            // Stop the movement of the player and the camera in order to inspect bugs
            world.distance_traveled -= distance_gained
            distance_gained = 0.0
            if player_ent != nil do player_ent.vel.z = 0.0
        }
    }
    
    world.camera.target.x, world.camera.target.y = world_to_screen_coords(0.0, 0.0, world.distance_traveled)
   
    if player_ent != nil {
        // Spawn new chunks after player reaches mid point of current chunk
        for c in 0..<CHUNK_COUNT {
            chunk := &world.chunks[c]
            midpoint := chunk.pos.z + CHUNK_LENGTH / 2
            if player_ent.pos.z > midpoint && player_z_before_update <= midpoint {
                next_chunk_idx := (c + 2) % CHUNK_COUNT
                next_chunk := &world.chunks[next_chunk_idx]
                next_chunk.pos = chunk.pos + rl.Vector3{0.0, 0.0, CHUNK_LENGTH * 2}
                load_next_chunk(world, next_chunk_idx)
                fmt.println("New chunk loaded.")
                break
            }
        }
    
        // Player has fallen
        if player_ent.pos.y < -16.0 {
            if world.heaven {
                init_world(world, false)
                rl.PlaySound(assets.Sounds[.Descend])
                next_song = assets.Songs[.IgnisMagnis]
            } else {
                world_lose_game(world)
            }
        } else {
            if player_ent.pos.z < world.distance_traveled - KILL_PLANE_OFFSET {
                world_lose_game(world)
            }
        }

        // Player has risen
        if world.heaven_transition && player_ent.pos.y > 16.0 {
            init_world(world, true)
        }

        if !world.game_lost {
            if world.heaven {
                new_score += distance_gained
            } else {
                new_score -= distance_gained
            }
        }
    }

    return
}

world_lose_game :: proc(world: ^World, call_loc := #caller_location, call_expr := #caller_expression) {
    if world.game_lost do return
    fmt.println("Player died because ", call_loc, call_expr)
    world.game_lost = true
    rl.PlaySound(assets.Sounds[.Lose])
}

world_to_screen_coords :: proc(x, y, z: f32) -> (screen_x, screen_y: f32) {
    screen_x = (x + z) * TILE_SPACING_HORZ
    screen_y = ((x - z) * TILE_SPACING_VERT) - (y * TILE_SPACING_HORZ)
	return
}

load_next_chunk :: proc(world: ^World, chunk_idx: int, asset_idx: int = -1) {
    assert(chunk_idx >= 0 && chunk_idx < CHUNK_COUNT)

    chunk_arr := assets.HeavenChunks if world.heaven else assets.HellChunks

    te3_map: assets.Te3Map
    if asset_idx >= 0 {
        te3_map = chunk_arr[asset_idx]
    } else {
        te3_map = rand.choice(chunk_arr[:])
    }

    te3_tiles := assets.load_tile_grid_from_te3_map(&te3_map)
    defer delete(te3_tiles)

    for tile, t in te3_tiles {
        x := t % te3_map.tiles.width
        y := t / (te3_map.tiles.width * te3_map.tiles.length)
        z := (t / te3_map.tiles.width) % te3_map.tiles.length
        if tile.model_id < 0 || tile.tex_id < 0 {
            world.chunks[chunk_idx].tiles[y][z][x] = .Empty
        } else {
            tex_name := filepath.short_stem(te3_map.tiles.textures[tile.tex_id])
            ok: bool
            world.chunks[chunk_idx].tiles[y][z][x], ok = reflect.enum_from_name(TileType, tex_name)
            if !ok {
                fmt.printfln("Didn't find matching tile type for texture '%v'.", tex_name)
            }
        }
    }

    for te3_ent in te3_map.ents {
        name, has_name := te3_ent.properties["name"]
        if !has_name do continue
        spawn_pos := world.chunks[chunk_idx].pos + (te3_ent.position / 2.0)
        switch name {
        case "shallot":
            // Spawn shallot
            if world.distance_traveled > CHUNK_LENGTH * 2 && rand.float32() < 0.50 {
                append(&world.ents, Ent{
                    pos = spawn_pos,
                    extents = rl.Vector3{0.5, 64.0, 0.5},
                    tex = assets.Gfx[.Shallot],
                    sprite_origin = rl.Vector2{ 8.0, 360.0 },
                    variant = .Shallot,
                    update_func = update_ent,
                    needs_drop_shadow = true,
                })
            }
        case "fire":
            // Spawn fire
            yaw := linalg.to_radians(te3_ent.angles[1])
            fire := Ent{
                pos = spawn_pos,
                home = spawn_pos,
                tex = assets.Gfx[.Fire],
                sprite_origin = rl.Vector2{8.0, 16.0},
                anim_player = assets.AnimPlayer{
                    anims = &assets.Anims[.Fire],
                },
                extents = rl.Vector3{0.25, 0.5, 0.25},
                update_func = update_fire,
                needs_outline = true,
                needs_drop_shadow = true,
                variant = .Hazard,
                max_speed = 1.0,
                vel = rl.Vector3{-math.sin(yaw), 0.0, math.cos(yaw)},
            }
            append(&world.ents, fire)
        case "spike":
            // Spawn spike entity (used to display outlines when spike tiles are behind walls)
            spike := Ent{
                pos = spawn_pos,
                tex = assets.Gfx[.SpikeOutline],
                sprite_origin = rl.Vector2{8.0, 8.0},
                needs_outline = true,
                variant = .Decoration,
            }
            append(&world.ents, spike)
        case "lightning":
            if rand.float32() < 0.50 do break
            lightning := Ent{
                pos = spawn_pos + rl.Vector3{0.0, 50.0, 0.0},
                tex = assets.Gfx[.Lightning],
                anim_player = assets.AnimPlayer{
                    anims = &assets.Anims[.Lightning],
                },
                sprite_origin = rl.Vector2{8.0, 360.0},
                extents = rl.Vector3{0.5, 64.0, 0.5},
                update_func = update_lightning,
                needs_outline = false,
                needs_drop_shadow = true,
                variant = .Hazard,
                life_timer = 0.75,
            }
            append(&world.ents, lightning)
        }
    }
}

chunk_is_visible :: proc(world: ^World, chunk: ^Chunk) -> bool {
    left, bottom := world_to_screen_coords(chunk.pos.x, chunk.pos.y, chunk.pos.z)
    right, top := world_to_screen_coords(chunk.pos.x + CHUNK_WIDTH, chunk.pos.y + CHUNK_HEIGHT, chunk.pos.z + CHUNK_LENGTH)
    left -= 32
    top -= 32
    right += 32
    bottom += 32
    return rl.GetCollisionRec(rl.Rectangle{
        left, top, right - left, bottom - top
    }, rl.Rectangle{
        world.camera.target.x - (world.camera.offset.x / 2.0),
        world.camera.target.y - (world.camera.offset.y / 2.0),
        world.camera.offset.x * 2.0,
        world.camera.offset.y,
    }) != {}
}

containing_chunks :: proc(world: ^World, bbox: rl.BoundingBox) -> (containing_chunks: []Chunk) {
    for c in 0..<CHUNK_COUNT {
        min := world.chunks[c].pos
        if rl.CheckCollisionBoxes(rl.BoundingBox{
            min = min,
            max = min + rl.Vector3{CHUNK_WIDTH, CHUNK_HEIGHT, CHUNK_LENGTH},
        }, bbox) {
            containing_chunks = world.chunks[0:c+1]
        }
    }
    return
}

draw_tile :: proc(chunk: ^Chunk, x, y, z: int) {
	tile := chunk.tiles[y][z][x]
	if tile == .Empty do return
	src := TileRects[tile]
	dest := rl.Rectangle{0, 0, src.width, src.height}
	dest.x, dest.y = world_to_screen_coords(f32(x) + chunk.pos.x, f32(y) + chunk.pos.y, f32(z) + chunk.pos.z)
	shade: u8 = 255
	#partial switch tile {
        case .Solid: shade = 180 + u8(min(255-180, y * 16))
		case .Cloud, .Pillar, .Bridge: shade = 200 + u8(min(55, y * 16))
	}
	
	rl.DrawTexturePro(assets.Gfx[.Tiles], src, dest, rl.Vector2{0.0, 3.0 * src.height / 4.0}, 0.0, rl.Color{shade, shade, shade, 255})
}