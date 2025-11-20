package main

import "core:strconv"
import str "core:strings"
import imgui "shared:odin-imgui"
import imsdl "shared:odin-imgui/imgui_impl_sdl2"
import imgl "shared:odin-imgui/imgui_impl_opengl3"

update_imgui :: proc(es: ^Editor_State, dynamic_lgs: #soa[dynamic]Level_Geometry) {
    imgl.new_frame()
    imsdl.new_frame()
    imgui.new_frame()

    imgui.begin("Level Editor")
    imgui.text("Level Geometry")
    imgui.begin_child("Scrolling")
    {
        for lg, lg_idx in dynamic_lgs {
            color: imgui.Vec4 = es.selected_entity == lg_idx ? {1, 0, 0, 1} : {1, 1, 1, 1}
            buf: [4]byte
            num_string := strconv.itoa(buf[:], lg_idx)
            shape_string := SHAPE_NAME[lg.shape]
            display_name := str.concatenate({num_string, ": ", shape_string})
            defer delete(display_name)
            imgui.text_colored(color, str.unsafe_string_to_cstring(display_name))
            if imgui.is_item_clicked(imgui.Mouse_Button.Left) {
                es.selected_entity = lg_idx 
            }
        }
    }
    imgui.end_child()
    imgui.end()

    imgui.render()
    imgl.render_draw_data(imgui.get_draw_data())
}
