package main

import rl "vendor:raylib"
import "core:math/rand"

CHUNK_WIDTH :: 16
CHUNK_HEIGHT :: 32
CHUNK_LENGTH :: 64
CHUNK_COUNT :: 2 // Number of chunks loaded at any one time.
TILE_SPACING_HORZ :: 16
TILE_SPACING_VERT :: 8

TileType :: enum u8 {
	Empty,
	Solid,
    Cloud,
}

TileRects := [TileType]rl.Rectangle{
	.Empty = rl.Rectangle{},
	.Solid = rl.Rectangle{0, 0, 32, 32},
    .Cloud = rl.Rectangle{32, 0, 32, 32},
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
}

world_to_screen_coords :: proc(x, y, z: f32) -> (screen_x, screen_y: f32) {
	screen_x = (x + z) * TILE_SPACING_HORZ 
	screen_y = ((x - z) * TILE_SPACING_VERT) - (y * TILE_SPACING_HORZ)
	return
}

load_next_chunk :: proc(world: ^World, chunk_idx: int) {
    assert(chunk_idx >= 0 && chunk_idx < CHUNK_COUNT)

    for y in 0..<CHUNK_HEIGHT {
		for z in 0..<CHUNK_LENGTH {
			for x in 0..<CHUNK_WIDTH {
				if y < 3 || (y == 3 && z > 5 && rand.float32() < 0.2) || (y == 3 && z == 0 && x % 2 == 0) {
                    t: TileType = .Solid if chunk_idx == 0 else .Cloud
					world.chunks[chunk_idx].tiles[y][z][x] = t
				} else {
                    world.chunks[chunk_idx].tiles[y][z][x] = .Empty
                }
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