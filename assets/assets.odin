package assets

import "core:fmt"
import "core:mem"
import "core:encoding/json"
import "core:strconv"
import "base:runtime"

import rl "vendor:raylib"

GfxId :: enum {
    Tiles,
    Player,
    Shallot,
    Fire,
    SpikeOutline,
    Lightning,
    Logo,
}

SoundId :: enum {
    Jump,
    Ascend,
    Descend,
    Lose,
    Lightning,
    Spring,
}

SongId :: enum {
    IgnisMagnis,
    TheLonging,
}

ChunkInfo :: struct {
    te3_map: Te3Map,
    distance_threshold: f32, // The total distance traveled after which this chunk should start appearing.
}

Gfx: [GfxId]rl.Texture2D
Sounds: [SoundId]rl.Sound
Songs: [SongId]rl.Music
Anims: [GfxId]AnimSet
HeavenChunks, HellChunks: [dynamic]ChunkInfo
HudFont: rl.Font

asset_arena: mem.Arena
asset_memory: [1_500_000]u8

load :: proc() {
    mem.arena_init(&asset_arena, asset_memory[:])
    context.allocator = mem.arena_allocator(&asset_arena)

    tex_from_bytes :: proc(bytes: []u8) -> rl.Texture2D {
        img := rl.LoadImageFromMemory(".png", &bytes[0], cast(i32)len(bytes))
        defer rl.UnloadImage(img)
        return rl.LoadTextureFromImage(img)
    }

    Gfx = [GfxId]rl.Texture2D {
        .Tiles = tex_from_bytes(#load("gfx/tiles.png")),
        .Player = tex_from_bytes(#load("gfx/player.png")),
        .Shallot = tex_from_bytes(#load("gfx/shallot.png")),
        .Fire = tex_from_bytes(#load("gfx/fire.png")),
        .SpikeOutline = tex_from_bytes(#load("gfx/spike_outline.png")),
        .Lightning = tex_from_bytes(#load("gfx/lightning.png")),
        .Logo = tex_from_bytes(#load("gfx/logo.png")),
    }

    sound_from_bytes :: proc(bytes: []u8) -> rl.Sound {
        wave := rl.LoadWaveFromMemory(".wav", &bytes[0], cast(i32)len(bytes))
        defer rl.UnloadWave(wave)
        return rl.LoadSoundFromWave(wave)
    }

    Sounds = [SoundId]rl.Sound {
        .Jump = sound_from_bytes(#load("sounds/jump.wav")),
        .Ascend = sound_from_bytes(#load("sounds/ascend.wav")),
        .Descend = sound_from_bytes(#load("sounds/descend.wav")),
        .Lose = sound_from_bytes(#load("sounds/lose.wav")),
        .Lightning = sound_from_bytes(#load("sounds/lightning.wav")),
        .Spring = sound_from_bytes(#load("sounds/spring.wav")),
    }

    song_from_bytes :: proc(bytes: []u8) -> rl.Music {
        return rl.LoadMusicStreamFromMemory(".ogg", &bytes[0], cast(i32)len(bytes))
    }

    Songs = [SongId]rl.Music {
        .IgnisMagnis = song_from_bytes(#load("music/ignis_magnis.ogg")),
        .TheLonging = song_from_bytes(#load("music/the_longing.ogg")),
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
    Anims[.Fire] = anims_from_bytes(#load("gfx/fire.json"))
    Anims[.Lightning] = anims_from_bytes(#load("gfx/lightning.json"))

    heaven_chunk_files := #load_directory("chunks/heaven")
    hell_chunk_files := #load_directory("chunks/hell")

    load_chunk :: proc(file: runtime.Load_Directory_File, arr: ^[dynamic]ChunkInfo) {
        te3_map: Te3Map
        err := json.unmarshal(file.data, &te3_map)
        if err != nil {
            fmt.printfln(`Error! Could not load TE3 map at "%v"`, file.name)
        } else {
            chunk_info := ChunkInfo{
                te3_map = te3_map,
            }

            for ent in te3_map.ents {
                if ent.properties["name"] != "meta" do continue
                if dist_str, ok := ent.properties["distance threshold"]; ok {
                    chunk_info.distance_threshold, ok = strconv.parse_f32(dist_str)
                    if !ok do fmt.println(`Error parsing level chunk at "%v": Could not parse meta entity distance threshold.`)
                }
            }

            append(arr, chunk_info)
            fmt.printfln(`Loaded chunk file at "%v".`, file.name)
        }
    }

    HeavenChunks = make([dynamic]ChunkInfo, 0, len(heaven_chunk_files))
    for file in heaven_chunk_files {
        load_chunk(file, &HeavenChunks)
    }

    HellChunks = make([dynamic]ChunkInfo, 0, len(hell_chunk_files))
    for file in hell_chunk_files {
        load_chunk(file, &HellChunks)
    }

    font_bytes := #load("gfx/Awe Mono Gold.ttf")
    codepoints := make([dynamic]rune, 0, 200)
    
    for ru in ' '..='~' {
        append(&codepoints, ru)
    }
    for ru in 'А'..='я' {
        append(&codepoints, ru)
    }

    HudFont = rl.LoadFontFromMemory(".ttf", &font_bytes[0], cast(i32)len(font_bytes), 16, &codepoints[0], cast(i32)len(codepoints))
}

unload :: proc() {
    for &tex in Gfx {
        rl.UnloadTexture(tex)
    }

    for &sound in Sounds {
        rl.UnloadSound(sound)
    }

    for &song in Songs {
        rl.UnloadMusicStream(song)
    }

    rl.UnloadFont(HudFont)

    mem.arena_free_all(&asset_arena)
}