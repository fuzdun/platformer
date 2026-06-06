package main

import "core:strconv"
import str "core:strings"
import imgui "shared:odin-imgui"
import imsdl "shared:odin-imgui/imgui_impl_sdl3"
import imgl "shared:odin-imgui/imgui_impl_opengl3"
import hm "core:container/handle_map"

update_imgui :: proc(es: ^Editor_State, dynamic_lgs: ^Level_Geometry_State) {
    // imgl.new_frame()
    // imsdl.new_frame()
    // imgui.new_frame()
    //
    // imgui.begin("level editor")
    // imgui.text("level geometry")
    // imgui.begin_child("scrolling")
    // {
    //     hm_it := hm.iterator_make(dynamic_lgs)
    //     for lg, lg_idx in hm.iterate(&hm_it) {
    //         color: imgui.vec4 = es.selected_entity == lg_idx ? {1, 0, 0, 1} : {1, 1, 1, 1}
    //         buf: [4]byte
    //         num_string := strconv.write_int(buf[:], i64(lg_idx.idx), 10)
    //         shape_string := shape_name[lg.shape]
    //         display_name := str.concatenate({num_string, ": ", shape_string})
    //         defer delete(display_name)
    //         cname := str.clone_to_cstring(display_name)
    //         defer delete(cname)
    //         imgui.text_colored(color, cname)
    //         // imgui.text_colored(color, str.unsafe_string_to_cstring(display_name))
    //         if imgui.is_item_activated() || imgui.is_item_clicked(imgui.mouse_button.left) {
    //             es.selected_entity = lg_idx 
    //         }
    //     }
    // }
    // imgui.end_child()
    // imgui.end()
    //
    // selected_lg := hm.get(dynamic_lgs, es.selected_entity)
    // es.displayed_shape = i32(selected_lg.shape)
    //
    // imgui.begin("shape")
    // {
    //     shape_items: [len(shape_name)]cstring
    //     for shape_name, idx in shape_name {
    //         shape_items[idx] = str.clone_to_cstring(shape_name)
    //     }
    //     imgui.combo_char("", &es.displayed_shape, raw_data(shape_items[:]), i32(len(shape_items)), 8)
    //     if imgui.is_item_edited() {
    //         selected_lg.shape = shape(es.displayed_shape)
    //         es.selected_entity = editor_sort_lgs(dynamic_lgs, es.selected_entity)
    //     }
    //     for shape in shape_items {
    //         delete(shape)
    //     }
    //
    // }
    // imgui.end()
    //
    // es.displayed_render_type = i32(selected_lg.render_type)
    //
    // imgui.begin("render type")
    // {
    //     render_type_items: [len(level_geometry_render_type_name)]cstring
    //     for render_type_name, idx in level_geometry_render_type_name {
    //         render_type_items[idx] = str.clone_to_cstring(render_type_name)
    //     }
    //     imgui.combo_char("", &es.displayed_shape, raw_data(render_type_items[:]), i32(len(render_type_items)), 8)
    //     if imgui.is_item_edited() {
    //         selected_lg.render_type = level_geometry_render_type(es.displayed_render_type)
    //         es.selected_entity = editor_sort_lgs(dynamic_lgs, es.selected_entity)
    //     }
    //     for type in render_type_items {
    //         delete(type)
    //     }
    // }
    // imgui.end()
    //
    //
    // for attribute in level_geometry_component {
    //     if attribute in dynamic_lgs[es.selected_entity].attributes {
    //         es.displayed_attributes[attribute] = true
    //     } else {
    //         es.displayed_attributes[attribute] = false
    //     }
    // }
    //
    // imgui.begin("attributes")
    // {
    //     for attribute_name, idx in level_geometry_component_name {
    //         // imgui.checkbox(str.unsafe_string_to_cstring(attribute_name), &es.displayed_attributes[idx])
    //         cname := str.clone_to_cstring(attribute_name)
    //         defer delete(cname)
    //         imgui.checkbox(cname, &es.displayed_attributes[idx])
    //     }
    // }
    // imgui.end()
    //
    // selected_lg := &dynamic_lgs[es.selected_entity]
    //
    // new_attributes: bit_set[level_geometry_component; u64]
    // for value, attribute in es.displayed_attributes {
    //     if value {
    //         new_attributes += {attribute}
    //     }
    // }
    // selected_lg.attributes = new_attributes
    //
    // imgui.render()
    // imgl.render_draw_data(imgui.get_draw_data())
}
