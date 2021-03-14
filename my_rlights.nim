#
#
#   raylib.lights - Some useful functions to deal with lights data
#
#   CONFIGURATION:
#
#   #define RLIGHTS_IMPLEMENTATION
#       Generates the implementation of the library into the included file.
#       If not defined, the library is in header only mode and can be included in other headers 
#       or source files without problems. But only ONE file should hold the implementation.
#
#   LICENSE: zlib/libpng
#
#  Copyright (c) 2017-2020 Victor Fisac (@victorfisac) and Ramon Santamaria (@raysan5)
#
#   This software is provided "as-is", without any express or implied warranty. In no event
#   will the authors be held liable for any damages arising from the use of this software.
#
#   Permission is granted to anyone to use this software for any purpose, including commercial
#   applications, and to alter it and redistribute it freely, subject to the following restrictions:
#
#     1. The origin of this software must not be misrepresented; you must not claim that you
#     wrote the original software. If you use this software in a product, an acknowledgment
#     in the product documentation would be appreciated but is not required.
#
#     2. Altered source versions must be plainly marked as such, and must not be misrepresented
#     as being the original software.
#
#     3. This notice may not be removed or altered from any source distribution.
#
#

import nimraylib_now/raylib
import strformat
{.passC: "-DRLIGHTS_IMPLEMENTATION".}

#----------------------------------------------------------------------------------
# Defines and Macros
#----------------------------------------------------------------------------------
const MAX_LIGHTS* = 4 # Max dynamic lights supported by shader

#----------------------------------------------------------------------------------
# Types and Structures Definition
#----------------------------------------------------------------------------------

# Light data
type Light* = object    
    light_type*: cint
    position*: Vector3
    target*: Vector3
    color*: Color
    enabled*: bool
    
    # Shader locations
    enabledLoc*: cint
    typeLoc*: cint
    posLoc*: cint
    targetLoc*: cint
    colorLoc*: cint

# Light type
type LightType* = enum 
    LIGHT_DIRECTIONAL,
    LIGHT_POINT

var lightsCount* = 0  # Current amount of created lights

# Send light properties to shader
# NOTE: Light shader locations should be available 
proc updateLightValues*(shader: Shader, light: Light) =

    # Send to shader light enabled state and type
    var light_enabled: cint = cint light.enabled
    var light_type : cint = light.light_type
    setShaderValue(shader, light.enabledLoc, addr light_enabled, ShaderUniformDataType.INT)
    setShaderValue(shader, light.typeLoc, addr light_type, ShaderUniformDataType.INT)

    # Send to shader light position values
    echo "x = ", light.position.x
    var position : array[3, cfloat] = [ light.position.x, light.position.y, light.position.z ]
    setShaderValue(shader, light.posLoc, addr position, ShaderUniformDataType.VEC3)

    # Send to shader light target position values
    var target: array[3, cfloat] = [ light.target.x, light.target.y, light.target.z ]
    setShaderValue(shader, light.targetLoc, addr target, ShaderUniformDataType.VEC3)

    # Send to shader light color values
    echo &"color = {light.color}"
    var color: array[4, float] = [ light.color.r.float/255.float, light.color.g.float/255.float, 
                                   light.color.b.float/255.float, light.color.a.float/255.float ]
    setShaderValue(shader, light.colorLoc, addr color, ShaderUniformDataType.VEC4)

# Create a light and get shader locations
proc createLight*(light_type: int, position: Vector3, target: Vector3, color: Color, shader: Shader) =

    if lightsCount < MAX_LIGHTS:

        # TODO: Below code doesn't look good to me, 
        # it assumes a specific shader naming and structure
        # Probably this implementation could be improved
        let
            enabledName = &"lights[{lightsCount}].enabled"
            typeName    = &"lights[{lightsCount}].type"
            posName     = &"lights[{lightsCount}].position"
            targetName  = &"lights[{lightsCount}].target"
            colorName   = &"lights[{lightsCount}].color"
        

        var result = Light(
            light_type: light_type, 
            enabled: true,
            position: position,
            target: target,
            color: color,

            enabledLoc: getShaderLocation(shader, enabledName),
            typeLoc: getShaderLocation(shader, typeName),
            posLoc: getShaderLocation(shader, posName),
            targetLoc: getShaderLocation(shader, targetName),
            colorLoc: getShaderLocation(shader, colorName) )

        updateLightValues(shader, result)
        
        lightsCount += 1




