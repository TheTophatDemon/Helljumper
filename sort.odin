package main

import rl "vendor:raylib"

sort_drawables :: proc(drawables: []Drawable) {
    work_arr := make([dynamic]Drawable, len(drawables))
    defer delete(work_arr)
    copy(work_arr[:], drawables)

    split_merge :: proc(b: []Drawable, a: []Drawable) {
        if b == nil || len(b) == 1 {
            return
        }

        mid := len(b) / 2
        split_merge(a[:mid], b[:mid])
        split_merge(a[mid:], b[mid:])

        // Merge back into drawables array
        i := 0
        j := mid
        for k in 0..<len(a) {
            if i < mid && (j >= len(a) || drawable_less(a[i], a[j])) {
                b[k] = a[i]
                i += 1
            } else {
                b[k] = a[j]
                j += 1
            }
        }
    }

    split_merge(drawables[:], work_arr[:])
}

drawable_less :: proc(a, b: Drawable) -> bool {
    a_pos: rl.Vector3
    switch x in a {
        case ^Ent: a_pos = x.pos
        case ChunkTile: a_pos = rl.Vector3{f32(x.coords[0]), f32(x.coords[1]), f32(x.coords[2])} + x.chunk.pos
        case DropShadow: a_pos = x.pos
    }
    b_pos: rl.Vector3
    switch x in b {
        case ^Ent: b_pos = x.pos
        case ChunkTile: b_pos = rl.Vector3{f32(x.coords[0]), f32(x.coords[1]), f32(x.coords[2])} + x.chunk.pos
        case DropShadow: b_pos = x.pos
    }

    return b_pos.y + b_pos.x - b_pos.z > a_pos.y + a_pos.x - a_pos.z
}