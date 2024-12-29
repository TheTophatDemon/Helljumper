package main

import rl "vendor:raylib"
import "core:math/rand"
import "core:path/filepath"
import "core:reflect"
import "core:fmt"

import "assets"

CHUNK_WIDTH :: 16
CHUNK_HEIGHT :: 16
CHUNK_LENGTH :: 64
CHUNK_COUNT :: 3 // Number of chunks loaded at any one time.
TILE_SPACING_HORZ :: 16
TILE_SPACING_VERT :: 8

TileType :: enum u8 {
	Empty,
	Solid,
    Cloud,
    Pillar,
}

TileRects := [TileType]rl.Rectangle{
	.Empty = rl.Rectangle{},
	.Solid = rl.Rectangle{0, 0, 32, 32},
    .Cloud = rl.Rectangle{32, 0, 32, 32},
    .Pillar = rl.Rectangle{64, 0, 32, 32},
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

}

init_world :: proc(world: ^World, heaven: bool) {
    if world.ents != nil {
        delete(world.ents)
    }

    world^ = {
        heaven = heaven,
    }
    world.chunks[0].pos = rl.Vector3{0.0, 0.0, -CHUNK_LENGTH}
	world.chunks[2].pos = rl.Vector3{0.0, 0.0, CHUNK_LENGTH}
	world.ents = make([dynamic]Ent, 0, 100)
	load_next_chunk(world, 0, 0)
	load_next_chunk(world, 1, 0)
	load_next_chunk(world, 2, 0)

	world.camera = rl.Camera2D{
		offset = rl.Vector2{WINDOW_WIDTH / 4, WINDOW_HEIGHT / 2},
		zoom = 2,
	}

	// Spawn player
	append(&world.ents, Ent{
		pos = rl.Vector3{8.0, 16.0, 3.0},
		tex = assets.Gfx[.Player],
		sprite_origin = rl.Vector2{16.0, 40.0},
		anim_player = assets.AnimPlayer{
			anims = &assets.Anims[.Player],
		},
		extents = rl.Vector3{0.25, 1.0, 0.25},
		update_func = update_player,
		gravity = -20.0,
	})
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
}

chunk_is_visible :: proc(camera: rl.Camera2D, chunk: ^Chunk) -> bool {
    left, bottom := world_to_screen_coords(chunk.pos.x, chunk.pos.y, chunk.pos.z)
    right, top := world_to_screen_coords(chunk.pos.x + CHUNK_WIDTH, chunk.pos.y + CHUNK_HEIGHT, chunk.pos.z + CHUNK_LENGTH)
    return rl.GetCollisionRec(rl.Rectangle{
        left, top, right - left, bottom - top
    }, rl.Rectangle{
        camera.target.x - camera.offset.x,
        camera.target.y - camera.offset.y,
        camera.offset.x * 4.0,
        camera.offset.y * 2.0,
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