package assets

import "core:os"
import "core:fmt"
import "core:path/filepath"
import "core:encoding/json"
import "core:io"
import "core:strings"
import rl "vendor:raylib"

AnimSet :: struct {
    frames: map[string]Frame,
    meta: struct {
        name: string `json:"image"`,
        frameTags: []FrameTag,
        layers: []Layer,
        size: struct { w: f32, h: f32 }
    },
}

Layer :: struct {
    name: string,
}

FrameTag :: struct {
    name: string,
    from, to: u16,
    repeat: u8,
}

Frame :: struct {
    rect: struct { x: f32, y: f32, w: f32, h: f32 } `json:"frame"`,
    duration: u16,
}

AnimPlayer :: struct {
    anims: ^AnimSet,
    anim_idx: u16,
    layer_idx: u16,
    frame_idx: u16,
    timer: f32,
}

anim_player_current_frame :: proc (player: ^AnimPlayer) -> Frame {
    if player == nil || player.anims == nil {
        return Frame{}
    }

    frame_name: string
    if player.anims.meta.layers == nil || len(player.anims.meta.layers) <= 1 {
        frame_name = fmt.tprintf("%v %v.ase", 
            filepath.stem(player.anims.meta.name), 
            player.anims.meta.frameTags[player.anim_idx].from + player.frame_idx)
    } else {
        frame_name = fmt.tprintf("%v (%v) %v.ase", 
            filepath.stem(player.anims.meta.name), 
            player.anims.meta.layers[player.layer_idx].name, 
            player.anims.meta.frameTags[player.anim_idx].from + player.frame_idx)
    }

    return player.anims.frames[frame_name]
}

update_anim_player :: proc(player: ^AnimPlayer, delta_time: f32) {
    player.timer += delta_time

    if player.anims == nil {
        return
    }
    
    tag := player.anims.meta.frameTags[player.anim_idx]
    frame := anim_player_current_frame(player)

    if player.timer > f32(frame.duration) / 1000.0 {
        player.frame_idx += 1
        player.timer = 0.0
        if tag.from + player.frame_idx > tag.to {
            if tag.repeat == 0 {
                player.frame_idx = 0
            } else {
                player.frame_idx = tag.to
            }
        }
    }
}

anim_player_current_rect :: proc(player: ^AnimPlayer) -> rl.Rectangle {
    frame := anim_player_current_frame(player)
    return rl.Rectangle{
        x = frame.rect.x, y = frame.rect.y, width = frame.rect.w, height = frame.rect.h,
    }
}

anim_player_change_anim :: proc(player: ^AnimPlayer, new_anim_idx: u16) {
    if player == nil do return
    if player.anim_idx != new_anim_idx {
        player.frame_idx = 0
    }
    player.anim_idx = new_anim_idx
}