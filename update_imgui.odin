package main

import "core:strconv"
import "core:fmt"
import str "core:strings"
import imgui "shared:odin-imgui"
import imsdl "shared:odin-imgui/imgui_impl_sdl2"
import imgl "shared:odin-imgui/imgui_impl_opengl3"

update_imgui :: proc(es: ^Editor_State, dynamic_lgs: ^#soa[dynamic]Level_Geometry) {
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
            if imgui.is_item_activated() || imgui.is_item_clicked(imgui.Mouse_Button.Left) {
                es.selected_entity = lg_idx 
            }
        }
    }
    imgui.end_child()
    imgui.end()


    imgui.begin("Shape")
    {
        shape_items: [len(SHAPE_NAME)]cstring
        for shape_name, idx in SHAPE_NAME {
            shape_items[idx] = str.unsafe_string_to_cstring(shape_name)
        }
        imgui.combo("", &es.displayed_shape, shape_items[0], 4)
        if imgui.is_item_edited() {
            dynamic_lgs[es.selected_entity].shape = SHAPE(es.displayed_shape)
            // editor_sort_lgs(dynamic_lgs, es.selected_entity)
        }
    }
    imgui.end()


    for attribute in Level_Geometry_Component {
        if attribute in dynamic_lgs[es.selected_entity].attributes {
            es.displayed_attributes[attribute] = true
        } else {
            es.displayed_attributes[attribute] = false
        }
    }

    imgui.begin("Attributes")
    {
        for attribute_name, idx in Level_Geometry_Component_Name {
            imgui.checkbox(str.unsafe_string_to_cstring(attribute_name), &es.displayed_attributes[idx])
        }
    }
    imgui.end()

    selected_lg := &dynamic_lgs[es.selected_entity]

    for value, attribute in es.displayed_attributes {
        if value {
            selected_lg.attributes += {attribute}
        }
    }

    imgui.render()
    imgl.render_draw_data(imgui.get_draw_data())
}
