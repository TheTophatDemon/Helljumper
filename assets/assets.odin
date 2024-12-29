package assets

import "core:fmt"
import "core:mem"
import "core:encoding/json"
import rl "vendor:raylib"

GfxId :: enum {
    Tiles,
    Player,
}

Gfx: [GfxId]rl.Texture2D
Anims: [GfxId]AnimSet
Chunks: [dynamic]Te3Map

load :: proc() {
    tex_from_bytes :: proc(bytes: []u8) -> rl.Texture2D {
        img := rl.LoadImageFromMemory(".png", &bytes[0], cast(i32)len(bytes))
        defer rl.UnloadImage(img)
        return rl.LoadTextureFromImage(img)
    }

    Gfx = [GfxId]rl.Texture2D{
        .Tiles = tex_from_bytes(#load("gfx/tiles.png")),
        .Player = tex_from_bytes(#load("gfx/player.png")),
    }

    anims_from_bytes :: proc(bytes: []u8, call_expr := #caller_expression) -> AnimSet {
        anims: AnimSet
        err := json.unmarshal(bytes, &anims)
        if err != nil {
            fmt.printfln(`Error! Could not load animation data in "%v"`, call_expr)
        }
        return anims
    }

    Anims[.Player] = anims_from_bytes(#load("gfx/player.json"))

    chunk_files := #load_directory("chunks")

    Chunks = make([dynamic]Te3Map, 0, len(chunk_files))
    for file in chunk_files {
        te3_map: Te3Map
        err := json.unmarshal(file.data, &te3_map)
        if err != nil {
            fmt.printfln(`Error! Could not load TE3 map at "%v"`, file.name)
        } else {
            append(&Chunks, te3_map)
            fmt.printfln(`Loaded chunk file at "%v".`, file.name)
        }
    }

    // This memory is used until the end of the program, so nothing needs to be deallocated.
}