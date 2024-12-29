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
HudFont: rl.Font

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

    font_bytes := #load("gfx/Awe Mono Gold.ttf")
    // codepoints := [?]rune{
    //     'T', 'r', 'a', 'v', 'e', 'l', 'd', ':',
    //     'а','б','в','г','д','е','ё','ж','з','и','й','к','л','м','н','о','п','р','с','т','у','ф','х','ц','ч','ш',
    //     'щ','ъ','ы','ь','э','ю','я','А','Б','В','Г','Д','Е','Ё','Ж','З','И','Й','К','Л','М','Н','О','П','Р','С','Т','У','Ф','Ц','Ч',
    //     'Ш','Щ','Ъ','Ы','Ь','Э','Ю','Я',
    // }
    codepoints := make([dynamic]rune, 0, 200)
    defer delete(codepoints)
    for ru in ' '..='~' {
        append(&codepoints, ru)
    }
    for ru in 'А'..='я' {
        append(&codepoints, ru)
    }

    HudFont = rl.LoadFontFromMemory(".ttf", &font_bytes[0], cast(i32)len(font_bytes), 16, &codepoints[0], cast(i32)len(codepoints))

    // This memory is used until the end of the program, so nothing needs to be deallocated.
}