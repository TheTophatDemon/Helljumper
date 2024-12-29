package assets

import "core:fmt"
import "core:mem"
import "core:encoding/json"
import "base:runtime"

import rl "vendor:raylib"

GfxId :: enum {
    Tiles,
    Player,
}

Gfx: [GfxId]rl.Texture2D
Anims: [GfxId]AnimSet
HeavenChunks, HellChunks: [dynamic]Te3Map

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

    heaven_chunk_files := #load_directory("chunks/heaven")
    hell_chunk_files := #load_directory("chunks/hell")

    load_chunk :: proc(file: runtime.Load_Directory_File, arr: ^[dynamic]Te3Map) -> Te3Map {
        te3_map: Te3Map
        err := json.unmarshal(file.data, &te3_map)
        if err != nil {
            fmt.printfln(`Error! Could not load TE3 map at "%v"`, file.name)
        } else {
            append(arr, te3_map)
            fmt.printfln(`Loaded chunk file at "%v".`, file.name)
        }
        return te3_map
    }

    HeavenChunks = make([dynamic]Te3Map, 0, len(heaven_chunk_files))
    for file in heaven_chunk_files {
        load_chunk(file, &HeavenChunks)
    }

    HellChunks = make([dynamic]Te3Map, 0, len(hell_chunk_files))
    for file in hell_chunk_files {
        load_chunk(file, &HellChunks)
    }

    // This memory is used until the end of the program, so nothing needs to be deallocated.
}