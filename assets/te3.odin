package assets

import "core:encoding/base64"
import "core:encoding/endian"
import "core:fmt"

// Loads map files from Total Editor 3
Te3Map :: struct {
    tiles: struct {
        data: string,
        width, height, length: int,
        shapes: []string,
        textures: []string,
    },
    ents: []Te3Ent,
}

Te3Tile :: struct {
    model_id, angle, tex_id, pitch: i32
}

Te3Ent :: struct {
    position: [3]f32,
    angles: [3]f32,
    properties: map[string]string
}

load_tile_grid_from_te3_map :: proc(file: ^Te3Map, allocator := context.allocator, call_loc := #caller_location) -> [dynamic]Te3Tile {
    context.allocator = allocator

    if file == nil do return nil

    tiles := make([dynamic]Te3Tile, file.tiles.width * file.tiles.height * file.tiles.length)

    tile_bytes, err := base64.decode(file.tiles.data)
    if err != nil {
        fmt.printfln("Error loading tile grid from TE3 map on line %v: %v.", call_loc, err)
        return tiles
    }
    defer delete(tile_bytes)

    for t, byte_ofs := 0, 0; t < len(tiles); {
        tile: Te3Tile
        ok1, ok2, ok3, ok4: bool
        tile.model_id, ok1 = endian.get_i32(tile_bytes[byte_ofs:byte_ofs + 4], .Little)
        tile.angle, ok2 = endian.get_i32(tile_bytes[byte_ofs + 4:byte_ofs + 8], .Little)
        tile.tex_id, ok3 = endian.get_i32(tile_bytes[byte_ofs + 8:byte_ofs + 12], .Little)
        tile.pitch, ok4 = endian.get_i32(tile_bytes[byte_ofs + 12:byte_ofs + 16], .Little)
        byte_ofs += 16
        if tile.model_id < 0 {
            // Skip run of blank tiles.
            for tt in t..<(t - int(tile.model_id)) {
                tiles[tt] = Te3Tile{ model_id = -1, tex_id = -1 }
            }
            t += int(-tile.model_id)
        } else {
            tiles[t] = tile
            t += 1
        }
    }

    return tiles
}