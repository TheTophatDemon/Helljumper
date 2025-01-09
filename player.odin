package main

import rl "vendor:raylib"

import "assets"

update_player :: proc(player: ^Ent, world: ^World, delta_time: f32) {
    STRAFE_SPEED :: 6.0
    JUMP_FORCE :: 12.0
    REGULAR_SPEED :: 11.0
    MAX_SPEED :: 16.0
    FWD_ACCEL :: 15.0
    FRICTION :: 20.0
    SPRING_JUMP_FORCE :: JUMP_FORCE * 1.5
    
    update_ent(player, world, delta_time)

    if world.game_lost {
        assets.anim_player_change_anim(&player.anim_player, 4)
        player.vel.xz = {}
    } else if world.heaven_transition {
        assets.anim_player_change_anim(&player.anim_player, 1)
        player.vel.y -= player.gravity * 2.0 * delta_time
        player.extents = {}
        for &ent in world.ents {
            if ent.variant == .Shallot && ent.extents == {} {
                ent.vel = player.vel
            }
        }
    } else {
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
        if !world.heaven do player.vel.x = -player.vel.x
    
        trynna_jump := rl.IsKeyDown(.SPACE) || rl.IsKeyDown(.Z) || (rl.IsGamepadAvailable(0) && rl.IsGamepadButtonPressed(0, .RIGHT_FACE_DOWN))
        stopped_trynna_jump := rl.IsKeyReleased(.SPACE) || rl.IsKeyReleased(.Z) || (rl.IsGamepadAvailable(0) && rl.IsGamepadButtonReleased(0, .RIGHT_FACE_DOWN))
    
        moon_jump := false
        when ODIN_DEBUG {
            if rl.IsKeyDown(.TAB) do moon_jump = true
        }
        if .Bottom in player.touch_flags || moon_jump {
            if trynna_jump {
                player.vel.y = JUMP_FORCE
                rl.PlaySound(assets.Sounds[.Jump])
            }
            if .Spring in player.touched_tiles {
                player.vel.y = SPRING_JUMP_FORCE
                rl.PlaySound(assets.Sounds[.Spring])
            }
            if rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT) || (rl.IsGamepadAvailable(0) && rl.GetGamepadAxisMovement(0, .LEFT_TRIGGER) > 0.0) {
                player.max_speed = MAX_SPEED
                assets.anim_player_change_anim(&player.anim_player, 3)
            } else {
                player.max_speed = REGULAR_SPEED
                assets.anim_player_change_anim(&player.anim_player, 0)
            }
        } else {
            if player.vel.y > 0.0 {
                if .Top in player.touch_flags {
                    player.vel.y = 0.0
                } else {
                    assets.anim_player_change_anim(&player.anim_player, 1)
                }
            } else {
                assets.anim_player_change_anim(&player.anim_player, 2)
            }
            
            if player.vel.y > 5.0 && stopped_trynna_jump {
                player.vel.y = 5.0
            }
        }

        if .Spike in player.touched_tiles {
            world_lose_game(world)
        }
    
        // Collide with entities
        for &ent in world.ents {
            if &ent == player do continue
            
            if !rl.CheckCollisionBoxes(ent_bbox(player), ent_bbox(&ent)) do continue
    
            #partial switch ent.variant {
            case .Shallot:
                world.heaven_transition = true
                ent.extents = {}
                rl.PlaySound(assets.Sounds[.Ascend])
            case .Hazard:
                world_lose_game(world)
            }
        }
    }

}