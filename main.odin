package main

import rl "vendor:raylib"
import "core:fmt"
import "core:slice"
import "core:math/rand"

import "assets"

WINDOW_WIDTH :: 1280
WINDOW_HEIGHT :: 720

DropShadow :: struct {
	pos: rl.Vector3,
	scale: f32,
}

Drawable :: union{
	^Ent,
	ChunkTile,
	DropShadow,
}

za_warudo: World

main :: proc() {
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Helljumper")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)
	assets.load()

	init_world(&za_warudo, true)

	for !rl.WindowShouldClose() {
		delta_time := rl.GetFrameTime()

		player_z_before_update: f32
		player_ent: ^Ent
		for &ent in za_warudo.ents {
			if ent.update_func == update_player {
				player_z_before_update = ent.pos.z
				player_ent = &ent
			}
			if ent.update_func != nil do ent.update_func(&ent, &za_warudo, delta_time)
		}

		za_warudo.camera.target.x, za_warudo.camera.target.y = world_to_screen_coords(0.0, 0.0, player_ent.pos.z + 6.0)

		for c in 0..<CHUNK_COUNT {
			chunk := &za_warudo.chunks[c]
			midpoint := chunk.pos.z + CHUNK_LENGTH / 2
			if player_ent.pos.z > midpoint && player_z_before_update <= midpoint {
				// Time to generate the next chunk of the level
				next_chunk_idx := (c + 2) % CHUNK_COUNT
				next_chunk := &za_warudo.chunks[next_chunk_idx]
				next_chunk.pos = chunk.pos + rl.Vector3{0.0, 0.0, CHUNK_LENGTH * 2}
				load_next_chunk(&za_warudo, next_chunk_idx)
				fmt.println("New chunk loaded.")
				break
			}
		}

		defer if player_ent.pos.y < -16.0 {
			// Player has fallen
			init_world(&za_warudo, !za_warudo.heaven)
		}

		rl.BeginDrawing()
		if za_warudo.heaven {
			rl.ClearBackground(rl.Color{0, 64, 200, 255})
		} else {
			rl.ClearBackground(rl.Color{115, 23, 45, 255})
		}
		rl.BeginMode2D(za_warudo.camera)

		drawables := make([dynamic]Drawable, 0, CHUNK_COUNT * CHUNK_WIDTH * CHUNK_HEIGHT * CHUNK_LENGTH + len(za_warudo.ents))
		for c in 0..<CHUNK_COUNT {
			chunk := &za_warudo.chunks[c]
			if !chunk_is_visible(za_warudo.camera, chunk) do continue
			for y in 0..<CHUNK_HEIGHT {
				for z in 0..<CHUNK_LENGTH {
					for x in 0..<CHUNK_WIDTH {
						if chunk.tiles[y][z][x] == .Empty do continue
						if x < CHUNK_WIDTH - 1 && 
							y < CHUNK_HEIGHT - 1 && 
							z > 0 &&
							chunk.tiles[y + 1][z][x] != .Empty &&
							chunk.tiles[y][z - 1][x] != .Empty &&
							chunk.tiles[y][z][x + 1] != .Empty
						{
							// Don't render tiles that are completely obscured.
							continue
						}
						append(&drawables, ChunkTile{chunk = chunk, coords = [3]int{x, y, z}})
					}
				}
			}
		}
		for &ent in za_warudo.ents {
			append(&drawables, &ent)

			drop_shadow_loop:
			for c in 0..<CHUNK_COUNT {
				chunk := &za_warudo.chunks[c]
				// Make drop shadow
				tile_x := int(ent.pos.x - chunk.pos.x)
				tile_y := int(ent.pos.y - chunk.pos.y)
				tile_z := int(ent.pos.z - chunk.pos.z)
				if tile_x >= 0 && tile_y >= 0 && tile_z >= 0 && tile_x < CHUNK_WIDTH && tile_y < CHUNK_HEIGHT && tile_z < CHUNK_LENGTH {
					for y := tile_y; y >= 0; y -= 1 {
						if chunk.tiles[y][tile_z][tile_x] != .Empty {
							if abs(ent.pos.y - f32(y)) > 1.25 {
								append(&drawables, DropShadow{
									pos = rl.Vector3{ent.pos.x, f32(y) + chunk.pos.y + 1.1, ent.pos.z},
									scale = min(1.0, ent.pos.y - chunk.pos.y - f32(y) - 1.0),
								})
							}
							break drop_shadow_loop
						}
					}
				}
			}
		}

		sort_drawables(drawables[:])

		for drawable in drawables {
			switch variant in drawable {
				case ^Ent: draw_ent(variant)
				case ChunkTile: draw_tile(variant.chunk, variant.coords[0], variant.coords[1], variant.coords[2])
				case DropShadow: draw_drop_shadow(variant)
			}
		}
		
		rl.EndMode2D()

		rl.DrawFPS(4, 4)
		rl.EndDrawing()

		// Clear temporary allocations
		free_all(context.temp_allocator)
	}
}

draw_tile :: proc(chunk: ^Chunk, x, y, z: int) {
	tile := chunk.tiles[y][z][x]
	if tile == .Empty do return
	src := TileRects[tile]
	dest := rl.Rectangle{0, 0, src.width, src.height}
	dest.x, dest.y = world_to_screen_coords(f32(x) + chunk.pos.x, f32(y) + chunk.pos.y, f32(z) + chunk.pos.z)
	shade: u8
	switch tile {
		case .Empty: shade = 0
		case .Solid: shade = 128 + u8(min(127, y * 16))
		case .Cloud, .Pillar: shade = 200 + u8(min(55, y * 16))
	}
	
	rl.DrawTexturePro(assets.Gfx[.Tiles], src, dest, rl.Vector2{0.0, 3.0 * src.height / 4.0}, 0.0, rl.Color{shade, shade, shade, 255})
}

draw_drop_shadow :: proc(using drop_shadow: DropShadow) {
	x, y := world_to_screen_coords(pos.x, pos.y, pos.z)
	rl.DrawEllipse(cast(i32)x, cast(i32)y, 8.0 * scale, 4.0 * scale, rl.Color{0, 0, 0, 128})
}