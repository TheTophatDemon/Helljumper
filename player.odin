package main

import rl "vendor:raylib"

PlayerProps :: struct {
    fwd_accel: f32
}

update_player :: proc(player: ^Ent, world: ^World, delta_time: f32) {
    STRAFE_SPEED :: 6.0
    JUMP_FORCE :: 12.0
    REGULAR_SPEED :: 8.0
    MAX_SPEED :: 16.0
    FWD_ACCEL :: 10.0
    FRICTION :: 20.0
    
    update_ent(player, world, delta_time)

    if .Front in player.touch_flags {
        player.vel.z = 0.0
    } else {
        player.vel.z += FWD_ACCEL * delta_time
        if player.vel.z > player.max_speed {
            player.vel.z = max(0.0, player.vel.z - FRICTION * delta_time)
        }
    }

    player.vel.x = 0.0
    if rl.IsGamepadAvailable(0) {
        player.vel.x = rl.GetGamepadAxisMovement(0, .LEFT_X) * STRAFE_SPEED
    }
    if rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D) {
        player.vel.x = STRAFE_SPEED
    } else if rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A) {
        player.vel.x = -STRAFE_SPEED
    }

    trynna_jump := rl.IsKeyDown(.SPACE) || rl.IsKeyDown(.Z) || (rl.IsGamepadAvailable(0) && rl.GetGamepadButtonPressed() == .RIGHT_FACE_DOWN)

    if .Bottom in player.touch_flags {
        player.anim_player.anim_idx = 0
        if trynna_jump {
            player.vel.y = JUMP_FORCE
        }
        if rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT) || (rl.IsGamepadAvailable(0) && rl.GetGamepadAxisMovement(0, .LEFT_TRIGGER) > 0.0) {
            player.max_speed = MAX_SPEED
        } else {
            player.max_speed = REGULAR_SPEED
        }
    } else {
        if player.vel.y > 0.0 {
            player.anim_player.anim_idx = 1
        } else {
            player.anim_player.anim_idx = 2
        }
        if player.vel.y > 5.0 && !trynna_jump {
            player.vel.y = 5.0
        }
    }
}