package main

import rl "vendor:raylib"
import "core:fmt"
import "core:slice"
import "core:math/rand"
import "core:math"
import "core:strings"
import "core:os"
import "core:encoding/endian"
import "core:mem"
import "core:time"

import "assets"

WINDOW_WIDTH :: 1280
WINDOW_HEIGHT :: 720
HIGH_SCORE_FILE_NAME :: "high_score"
TIME_TO_RESTART :: 5.0 // Seconds

HEAVEN_BG_COLOR :: rl.Color{0, 64, 200, 255}
HELL_BG_COLOR :: rl.Color{115, 23, 45, 255}

when ODIN_DEBUG {
	MUSIC_VOLUME: f32 : 1.0
} else {
	MUSIC_VOLUME: f32 : 1.0
}

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
curr_song, next_song: rl.Music

main :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			if len(track.bad_free_array) > 0 {
				fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
				for entry in track.bad_free_array {
					fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Helljumper")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)
	rl.InitAudioDevice()
	assets.load()
	defer assets.unload()

	game_screen := rl.LoadRenderTexture(WINDOW_WIDTH, WINDOW_HEIGHT)
	defer rl.UnloadRenderTexture(game_screen)

	rand.reset(u64(time.time_to_unix(time.now())))

	init_world(&za_warudo, true)

	score: f32
	new_record: bool
	high_score, low_score := load_high_score()
	old_high_score := high_score
	old_low_score := low_score
	restart_timer: f32
	global_timer: f32
	bg_color: rl.Color = HEAVEN_BG_COLOR
	see_instructions: bool = true

	curr_song = assets.Songs[.TheLonging]
	next_song = curr_song
	song_volume := MUSIC_VOLUME
	rl.PlayMusicStream(curr_song)
	rl.SetMusicVolume(curr_song, song_volume)
	// when ODIN_DEBUG do rl.SetMasterVolume(0.5)
	
	for !rl.WindowShouldClose() {
		delta_time := rl.GetFrameTime()
		
		rl.UpdateMusicStream(curr_song)
		if next_song != curr_song {
			song_volume -= delta_time
			if song_volume < 0 {
				song_volume = MUSIC_VOLUME
				rl.StopMusicStream(curr_song)
				curr_song = next_song
				rl.PlayMusicStream(curr_song)
			}
			rl.SetMusicVolume(curr_song, song_volume)
		}

		global_timer += delta_time

		pressing_any_button := rl.GetKeyPressed() != .KEY_NULL || (rl.IsGamepadAvailable(0) && rl.GetGamepadButtonPressed() != .UNKNOWN)

		if !see_instructions {
			score = update_world(&za_warudo, delta_time, score)
			if int(score) > int(high_score) {
				high_score = score
			}
			if int(score) < int(low_score) {
				low_score = score
			}
			if za_warudo.game_lost {
				restart_timer += delta_time
				if za_warudo.heaven {
					// When you die in heaven, you just go to hell.
					if restart_timer > TIME_TO_RESTART / 2.0 {
						restart_timer = 0.0
						init_world(&za_warudo, false)
					}
				} else {
					if int(high_score) > int(old_high_score) || int(low_score) < int(old_low_score) {
						old_high_score = high_score
						old_low_score = low_score
						new_record = true
						save_high_score(high_score, low_score)
					}
					if restart_timer > TIME_TO_RESTART || (restart_timer > 1.0 && pressing_any_button) {
						restart_timer = 0.0
						score = 0
						init_world(&za_warudo, true)
					}
				}
			}
		} else if pressing_any_button && global_timer > 0.5 {
			see_instructions = false
		}

		rl.BeginDrawing()
		rl.BeginTextureMode(game_screen)
		
		if za_warudo.heaven {
			if rl.IsSoundPlaying(assets.Sounds[.Lightning]) {
				// BG color will strobe when there's lightning
				strobe := math.sin(global_timer * 10.0)
				bg_color = rl.Color{0, u8(96.0 + (strobe * 32.0)), u8(160.0 + strobe * 40.0), 255}
			} else if bg_color != HELL_BG_COLOR {
				bg_color = rl.ColorLerp(bg_color, HEAVEN_BG_COLOR, delta_time)
			} else {
				bg_color = HEAVEN_BG_COLOR
			}
		} else {
			bg_color = HELL_BG_COLOR
		}
		rl.ClearBackground(bg_color)
		rl.BeginMode2D(za_warudo.camera)

		drawables := make([dynamic]Drawable, 0, CHUNK_COUNT * CHUNK_WIDTH * CHUNK_HEIGHT * CHUNK_LENGTH + len(za_warudo.ents))
		defer delete(drawables)
		for c in 0..<CHUNK_COUNT {
			chunk := &za_warudo.chunks[c]
			if !chunk_is_visible(&za_warudo, chunk) do continue
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

			if !ent.needs_drop_shadow do continue

			drop_shadow_loop:
			for c in 0..<CHUNK_COUNT {
				chunk := &za_warudo.chunks[c]
				// Make drop shadow
				tile_x := int(ent.pos.x - chunk.pos.x)
				tile_y := int(ent.pos.y - chunk.pos.y)
				tile_z := int(ent.pos.z - chunk.pos.z)
				if tile_x >= 0 && tile_y >= 0 && tile_z >= 0 && tile_x < CHUNK_WIDTH && tile_z < CHUNK_LENGTH {
					for y := min(CHUNK_HEIGHT - 1, tile_y); y >= 0; y -= 1 {
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

		for &ent in za_warudo.ents {
			if ent.needs_outline do draw_ent_outline(&ent)
		}
		
		rl.EndMode2D()
		rl.EndTextureMode()

		src := rl.Rectangle{
			width = f32(game_screen.texture.width if za_warudo.heaven else -game_screen.texture.width),
			height = f32(-game_screen.texture.height)
		}
		rl.DrawTexturePro(game_screen.texture, src, rl.Rectangle{0, 0, f32(game_screen.texture.width), f32(game_screen.texture.height)}, rl.Vector2{}, 0, rl.WHITE)
		
		if see_instructions {
			rl.DrawRectangle(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT, rl.Color{0, 0, 0, 128})
			rl.DrawTextEx(assets.HudFont, 
				"A and D or LEFT JOYSTICK - Strafe\n" + 
				"SPACE, Z or XBOX A - Jump. Hold to jump higher\n" +
				"Hold SHIFT or LEFT TRIGGER - Run\n\n" +
				"Run as far as you can through Heaven and\n" +
				"Stay out of Hell!",
				rl.Vector2{WINDOW_WIDTH * 0.3, WINDOW_HEIGHT * 0.3},
				24, 0.0,
				rl.GREEN,
			)

			if math.mod(global_timer, 1.0) > 0.25 {
				rl.DrawTextEx(assets.HudFont, "Press any button to begin!", rl.Vector2{WINDOW_WIDTH * 0.35, 3.0 * WINDOW_HEIGHT / 4.0}, 24, 1.0, rl.YELLOW)
			}

			rl.DrawTexture(assets.Gfx[.Logo], WINDOW_WIDTH - 320, WINDOW_HEIGHT - 320, rl.WHITE)
		} else {
			score_text := fmt.tprintf("TЯAVELEД: %04d БEST: %04d ШOЯST: %04d", int(score), int(high_score), int(low_score))
			c_score_text := strings.clone_to_cstring(score_text, context.temp_allocator)
			rl.DrawTextEx(assets.HudFont, c_score_text, rl.Vector2{WINDOW_WIDTH * 0.25, 6}, 32, 0.0, rl.Color{0, 0, 0, 128})
			rl.DrawTextEx(assets.HudFont, c_score_text, rl.Vector2{WINDOW_WIDTH * 0.25, 4}, 32, 0.0, rl.GREEN)
	
			if za_warudo.game_lost && !za_warudo.heaven {
				LOSE_MSG :: "THOЦ HAST PEЯISHEД"
				shadow_pos := rl.Vector2{WINDOW_WIDTH / 4, 3 * WINDOW_HEIGHT / 8 }
				t := f32(rl.GetTime()) * 100.0
				rl.DrawTextEx(assets.HudFont, LOSE_MSG, shadow_pos - rl.Vector2{2.0 + math.cos(t * 10.0), 1.0 - math.sin(t / 2.0)}, 72, 4.0, rl.BLACK)
				rl.DrawTextEx(assets.HudFont, LOSE_MSG, shadow_pos + rl.Vector2{2.0 + math.sin(t), 2.0 + math.cos(t)}, 72, 4.0, rl.RED)
				if new_record && (int(t) % 100) > 25 { 
					RECORD_MSG :: "ШITH A NEШ ЯECOЯД!"
					rl.DrawTextEx(assets.HudFont, RECORD_MSG, shadow_pos + rl.Vector2{192.0, 82.0}, 32, 1.0, rl.YELLOW)
				}
			}
		}

		when ODIN_DEBUG do rl.DrawFPS(4, 4)
		rl.EndDrawing()

		// Clear temporary allocations
		free_all(context.temp_allocator)
	}

	delete(za_warudo.ents)
}

draw_drop_shadow :: proc(drop_shadow: DropShadow) {
	x, y := world_to_screen_coords(drop_shadow.pos.x, drop_shadow.pos.y, drop_shadow.pos.z)
	rl.DrawEllipse(cast(i32)x, cast(i32)y, 8.0 * drop_shadow.scale, 4.0 * drop_shadow.scale, rl.Color{0, 0, 0, 128})
}

load_high_score :: proc() -> (high_score, low_score: f32) {
	if !os.exists(HIGH_SCORE_FILE_NAME) do return
	file, err := os.open(HIGH_SCORE_FILE_NAME)
	if err != nil {
		fmt.printfln("Error reading high score from file: %v.", os.error_string(err))
		return
	}
	defer os.close(file)

	data, succ := os.read_entire_file(file)
	if !succ {
		fmt.printfln("Could not read high score file.")
		return
	}
	defer delete(data)

	high_score, succ = endian.get_f32(data, .Little)
	if !succ {
		fmt.printfln("The high score is not a float!?")
		return
	}

	low_score, succ = endian.get_f32(data[4:], .Little)
	if !succ {
		fmt.printfln("The low score is not a float!?")
		return
	}

	return
}

save_high_score :: proc(high_score, low_score: f32) {
	mode: int
	when ODIN_OS != .Windows {
		mode = os.S_IRUSR|os.S_IWUSR|os.S_IRGRP|os.S_IROTH
	}
	file, err := os.open(HIGH_SCORE_FILE_NAME, os.O_WRONLY | os.O_CREATE | os.O_TRUNC, mode)
	if err != nil {
		fmt.printfln("Error opening high score file for writing: %v.", os.error_string(err))
		return
	}
	defer os.close(file)

	bytes: [8]u8
	endian.put_f32(bytes[:4], .Little, high_score)
	endian.put_f32(bytes[4:], .Little, low_score)

	_, err = os.write(file, bytes[:])
	if err != nil {
		fmt.printfln("Error writing high score: %v.", os.error_string(err))
		return
	}
}