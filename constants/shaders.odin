package constants

import gl "vendor:OpenGL"

import st "../../state"
import enm "../enums"

EDIT :: true

PROGRAM_CONFIGS := [enm.ProgramName]Program{
    .Trail = {
        pipeline = EDIT ? {"simplevertex", "simplefrag"} : {"thumpervertex", "tessellationctrl", "tessellationeval", "thumpergeometry", "trailfrag"},
        shader_types = EDIT ? {.VERTEX_SHADER, .FRAGMENT_SHADER} : {.VERTEX_SHADER, .TESS_CONTROL_SHADER, .TESS_EVALUATION_SHADER, .GEOMETRY_SHADER, .FRAGMENT_SHADER},
        uniforms = EDIT ? {"projection"} : {"player_trail", "player_pos", "crunch_time", "crunch_pt", "time", "projection", "sonar_time"},
        init_proc = proc() {
            // gl.PolygonMode(gl.FRONT, gl.FILL)
        },
    },
    .Player = {
        pipeline = {"playervertex", "playerfrag"},
        shader_types = {.VERTEX_SHADER, .FRAGMENT_SHADER},
        uniforms = {"transform", "i_time", "dash_time", "dash_end_time", "projection", "p_color", "constrain_dir"},
        init_proc = proc() {
            // gl.PolygonMode(gl.FRONT, gl.FILL)
        },
    },
    .Player_Particle = {
        pipeline = {"particlevertex", "particlefrag"},
        shader_types = {.VERTEX_SHADER, .FRAGMENT_SHADER},
        uniforms = {"projection", "player_pos", "i_time", "radius", "constrain_dir", "dash_time", "dash_end_time"},
        init_proc = proc() {
            // gl.PolygonMode(gl.FRONT, gl.FILL)
        },
    },
    .Simple = {
        pipeline = {"simplevertex", "simplefrag"},
        shader_types = {.VERTEX_SHADER, .FRAGMENT_SHADER},
        uniforms = {"projection"},
        init_proc = proc() {
            // gl.PolygonMode(gl.FRONT, gl.FILL)
        }
    },
    .Background = {
        pipeline = {"backgroundvertex", "backgroundfrag"},
        shader_types = {.VERTEX_SHADER, .FRAGMENT_SHADER},
        uniforms = {"i_time"},
        init_proc = proc(){
            // gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL)
        }
    },
    .Outline = {
        pipeline = {"outlinevertex", "outlinefrag"},
        shader_types = {.VERTEX_SHADER, .FRAGMENT_SHADER},
        uniforms = {"projection", "color"},
        init_proc = proc() {
            // gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINES)
        }
    },
    .Line = {
        pipeline = {"linevertex", "linegeometry", "linefrag"},
        shader_types = {.VERTEX_SHADER, .GEOMETRY_SHADER, .FRAGMENT_SHADER},
        uniforms = {"projection", "color", "line_dir", "dash_time", "i_time", "dash_dir", "resolution"},
        init_proc = proc() {

        }
    },
    .Text = {
        pipeline = {"textvertex", "textfrag"},
        shader_types = {.VERTEX_SHADER, .FRAGMENT_SHADER},
        uniforms = {"projection", "transform"},
        init_proc = proc() {}
    },
}
