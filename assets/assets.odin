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

    // This memory is used until the end of the program, so nothing needs to be deallocated.
}