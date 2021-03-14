#
#
#   raylib [models] example - PBR material
#
#   NOTE: This example requires raylib OpenGL 3.3 for shaders support and only #version 330
#         is currently supported. OpenGL ES 2.0 platforms are not supported at the moment.
#  
#
#

import nimraylib_now/raylib
import strformat
import my_rlights

const 
    CUBEMAP_SIZE     = 1024  # Cubemap texture size
    IRRADIANCE_SIZE  = 32    # Irradiance texture size
    PREFILTERED_SIZE = 256   # Prefiltered HDR environment texture size
    BRDF_SIZE        = 512   # BRDF LUT texture size
    LIGHT_DISTANCE   = 1000.0f
    LIGHT_HEIGHT     = 1.0f

# PBR material loading
# Load PBR material (Supports: ALBEDO, NORMAL, METALNESS, ROUGHNESS, AO, EMMISIVE, HEIGHT maps)
# NOTE: PBR shader is loaded inside this function
proc LoadMaterialPBR(albedo: Color, metalness: float, roughness: float): Material = 

    var mat = loadMaterialDefault()  # Initialize material to default

    # Load PBR shader (requires several maps)

    when defined(web): # PLATFORM_RPI, PLATFORM_ANDROID, PLATFORM_WEB
        mat.shader = loadShader("resources/shaders/glsl100/pbr.vs", "resources/shaders/glsl100/pbr.fs")
    else: # by default : desktop
        mat.shader = loadShader("resources/shaders/glsl330/pbr.vs", "resources/shaders/glsl330/pbr.fs")


    # Get required locations points for PBR material
    # NOTE: Those location names must be available and used in the shader code
    mat.shader.locs[int Map_Albedo] = getShaderLocation(mat.shader, "albedo.sampler")
    mat.shader.locs[int MAP_METALNESS] = getShaderLocation(mat.shader, "metalness.sampler")
    mat.shader.locs[int MAP_NORMAL] = getShaderLocation(mat.shader, "normals.sampler")
    mat.shader.locs[int MAP_ROUGHNESS] = getShaderLocation(mat.shader, "roughness.sampler")
    mat.shader.locs[int MAP_OCCLUSION] = getShaderLocation(mat.shader, "occlusion.sampler")
    # mat.shader.locs[int MAP_EMISSION] = getShaderLocation(mat.shader, "emission.sampler")
    # mat.shader.locs[int MAP_HEIGHT] = getShaderLocation(mat.shader, "height.sampler")
    mat.shader.locs[int MAP_IRRADIANCE] = getShaderLocation(mat.shader, "irradianceMap")
    mat.shader.locs[int MAP_PREFILTER] = getShaderLocation(mat.shader, "prefilterMap")
    mat.shader.locs[int MAP_BRDF] = getShaderLocation(mat.shader, "brdfLUT")

    # Set view matrix location
    mat.shader.locs[int MATRIX_MODEL] = getShaderLocation(mat.shader, "matModel")
    # mat.shader.locs[LOC_MATRIX_VIEW] = getShaderLocation(mat.shader, "view")
    mat.shader.locs[int VECTOR_VIEW] = getShaderLocation(mat.shader, "viewPos")

    # Set PBR standard maps

    var
        texAlbedo : Texture2D = loadTexture("resources/pbr/trooper_albedo.png")
    mat.maps[ord ALBEDO].texture = texAlbedo
    mat.maps[ord NORMAL].texture = loadTexture("resources/pbr/trooper_normals.png")
    mat.maps[ord METALNESS].texture = loadTexture("resources/pbr/trooper_metalness.png")
    mat.maps[ord ROUGHNESS].texture = loadTexture("resources/pbr/trooper_roughness.png")
    mat.maps[ord OCCLUSION].texture = loadTexture("resources/pbr/trooper_ao.png")

    # Set textures filtering for better quality
    setTextureFilter(mat.maps[ord ALBEDO].texture, BILINEAR)
    setTextureFilter(mat.maps[ord NORMAL].texture, BILINEAR)
    setTextureFilter(mat.maps[ord METALNESS].texture, BILINEAR)
    setTextureFilter(mat.maps[ord ROUGHNESS].texture, BILINEAR)
    setTextureFilter(mat.maps[ord OCCLUSION].texture, BILINEAR)
    
    # this should only be read !!! 
    # this is used by setShaderValue( ..., value, ...)
    # and value here will be the pointer to only_one
    var one : cint = 1
    # Enable sample usage in shader for assigned textures
    setShaderValue(mat.shader, getShaderLocation(mat.shader, "albedo.useSampler"), one.addr, INT)
    setShaderValue(mat.shader, getShaderLocation(mat.shader, "normals.useSampler"), one.addr, INT)
    setShaderValue(mat.shader, getShaderLocation(mat.shader, "metalness.useSampler"), one.addr, INT)
    setShaderValue(mat.shader, getShaderLocation(mat.shader, "roughness.useSampler"), one.addr, INT)
    setShaderValue(mat.shader, getShaderLocation(mat.shader, "occlusion.useSampler"), one.addr, INT)

    var zero : cint = 0
    let renderModeLoc = getShaderLocation(mat.shader, "renderMode")
    setShaderValue(mat.shader, renderModeLoc, zero.addr, INT)

    # Set up material properties color
    mat.maps[ord ALBEDO].color = albedo
    mat.maps[ord NORMAL].color = Color(r: 128, g: 128, b: 255, a: 255)
    mat.maps[ord METALNESS].value = metalness
    mat.maps[ord ROUGHNESS].value = roughness
    mat.maps[ord OCCLUSION].value = 1.0f
    mat.maps[ord EMISSION].value = 0.5f
    mat.maps[ord HEIGHT].value = 0.5f
    
    # Generate cubemap from panorama texture
    #--------------------------------------------------------------------------------------------------------
    let panorama = loadTexture("resources/dresden_square_2k.hdr")
    # Load equirectangular to cubemap shader

    when defined(web): # PLATFORM_RPI, PLATFORM_ANDROID, PLATFORM_WEB
        let shdrCubemap = loadShader("resources/shaders/glsl100/cubemap.vs", "resources/shaders/glsl100/cubemap.fs")
    else: # default, no value : Desktop
        let shdrCubemap = loadShader("resources/shaders/glsl330/cubemap.vs", "resources/shaders/glsl330/cubemap.fs")

    echo "equirectangularMap"
    setShaderValue(shdrCubemap, getShaderLocation(shdrCubemap, "equirectangularMap"), zero.addr, INT)
    let cubemap = genTextureCubemap(shdrCubemap, panorama, CUBEMAP_SIZE, UNCOMPRESSED_R32G32B32)
    unloadTexture(panorama)
    unloadShader(shdrCubemap)
    #--------------------------------------------------------------------------------------------------------
    
    # Generate irradiance map from cubemap texture
    #--------------------------------------------------------------------------------------------------------
    # Load irradiance (GI) calculation shader
    when defined(web):
        let shdrIrradiance = loadShader("resources/shaders/glsl100/skybox.vs", "resources/shaders/glsl100/irradiance.fs")
    else:
        let shdrIrradiance = loadShader("resources/shaders/glsl330/skybox.vs", "resources/shaders/glsl330/irradiance.fs")

    setShaderValue(shdrIrradiance, getShaderLocation(shdrIrradiance, "environmentMap"), zero.addr, INT)
    mat.maps[int IRRADIANCE].texture = genTextureIrradiance(shdrIrradiance, cubemap, IRRADIANCE_SIZE)
    unloadShader(shdrIrradiance)

    #--------------------------------------------------------------------------------------------------------
    # Generate prefilter map from cubemap texture
    #--------------------------------------------------------------------------------------------------------
    # Load reflection prefilter calculation shader
    when defined(web):
        let shdrPrefilter = loadShader("resources/shaders/glsl100/skybox.vs", "resources/shaders/glsl100/prefilter.fs")
    else:
        let shdrPrefilter = loadShader("resources/shaders/glsl330/skybox.vs", "resources/shaders/glsl330/prefilter.fs")

    setShaderValue(shdrPrefilter, getShaderLocation(shdrPrefilter, "environmentMap"), zero.addr, INT)
    mat.maps[int PREFILTER].texture = genTexturePrefilter(shdrPrefilter, cubemap, PREFILTERED_SIZE)
    unloadTexture(cubemap)
    unloadShader(shdrPrefilter)

    #--------------------------------------------------------------------------------------------------------
    # Generate BRDF (bidirectional reflectance distribution function) texture (using shader)
    #--------------------------------------------------------------------------------------------------------
    when defined(web):
        let shdrBRDF = loadShader("resources/shaders/glsl100/brdf.vs", "resources/shaders/glsl100/brdf.fs")
    else:
        let shdrBRDF = loadShader("resources/shaders/glsl330/brdf.vs", "resources/shaders/glsl330/brdf.fs")

    mat.maps[int BRDF].texture = genTextureBRDF(shdrBRDF, BRDF_SIZE)
    unloadShader(shdrBRDF)

    #--------------------------------------------------------------------------------------------------------

    return mat


proc main() =

    # Initialization
    #--------------------------------------------------------------------------------------
    const screenWidth = 800 
    const screenHeight = 600

    setConfigFlags(MSAA_4X_HINT) # Enable Multi Sampling Anti Aliasing 4x (if available)
    initWindow(screenWidth, screenHeight, "raylib [models] example - pbr material")

    # Define the camera to look into our 3d world
    var camera = Camera()
    camera.position = Vector3(x: 4.0f,y: 4.0f,z: 4.0f ) # Camera position
    camera.target = Vector3(x:0.0f,y: 0.5f,z: 0.0f )    # Camera looking at point
    camera.up = Vector3(x: 0.0f,y: 1.0f,z: 0.0f )       # Camera up vector (rotation towards target)
    camera.fovy = 45.0f                                 # Camera field-of-view Y
    camera.`type` = PERSPECTIVE                         # Camera mode type

    # Load model and PBR material
    var model = loadModel("resources/pbr/trooper.obj")

    # Mesh tangents are generated... and uploaded to GPU
    # NOTE: New VBO for tangents is generated at default location and also binded to mesh VAO
    #MeshTangents(&model.meshes[0]);

    model.materials[0] = LoadMaterialPBR(Color(r: 255, g: 255, b: 255, a: 255 ), 1.0f, 1.0f)

    # Create lights
    # NOTE: Lights are added to an internal lights pool automatically
    let vec3Zero = tupleToVector3 (0f64,0f64,0f64)
    let red = tupleToColor (255, 0, 0, 255)
    let green = tupleToColor (255, 0, 0, 255)
    let blue = tupleToColor (255, 0, 0, 255)
    let purple = tupleToColor (255, 0, 255, 255)

    # discard createLight(ord(LIGHT_POINT), tupleToVector3 (LIGHT_DISTANCE.float, LIGHT_HEIGHT.float, 0.0f64),  vec3Zero, red, model.materials[0].shader)
    # discard createLight(ord(LIGHT_POINT), tupleToVector3 (0.0f64, LIGHT_HEIGHT.float, LIGHT_DISTANCE.float),  vec3Zero, green, model.materials[0].shader)
    # discard createLight(ord(LIGHT_POINT), tupleToVector3 (-LIGHT_DISTANCE.float, LIGHT_HEIGHT.float, 0.0f64), vec3Zero, blue, model.materials[0].shader)
    # discard createLight(ord(LIGHT_DIRECTIONAL), tupleToVector3 (0.0f64, LIGHT_HEIGHT*2.0f64, -LIGHT_DISTANCE.float), vec3Zero, purple, model.materials[0].shader)

    createLight(ord(LIGHT_POINT), tupleToVector3 (LIGHT_DISTANCE.float, LIGHT_HEIGHT.float, 0.0f64),  vec3Zero, red, model.materials[0].shader)
    createLight(ord(LIGHT_POINT), tupleToVector3 (0.0f64, LIGHT_HEIGHT.float, LIGHT_DISTANCE.float),  vec3Zero, green, model.materials[0].shader)
    createLight(ord(LIGHT_POINT), tupleToVector3 (-LIGHT_DISTANCE.float, LIGHT_HEIGHT.float, 0.0f64), vec3Zero, blue, model.materials[0].shader)
    createLight(ord(LIGHT_DIRECTIONAL), tupleToVector3 (0.0f64, LIGHT_HEIGHT*2.0f64, -LIGHT_DISTANCE.float), vec3Zero, purple, model.materials[0].shader)


    setCameraMode(camera, ORBITAL) # Set an orbital camera mode

    setTargetFPS(60)  # Set our game to run at 60 frames-per-second
    #--------------------------------------------------------------------------------------

    # Main game loop
    while not windowShouldClose():            # Detect window close button or ESC key
        # Update
        #----------------------------------------------------------------------------------
        updateCamera(camera.addr)  # Update camera

        # Send to material PBR shader camera view position
        # var cameraPos = Vector3(x: camera.position.x,y: camera.position.y,z: camera.position.z)
        var cameraPos = [camera.position.x, camera.position.y, camera.position.z]
        setShaderValue(model.materials[0].shader, model.materials[0].shader.locs[int VECTOR_VIEW], cameraPos.addr, VEC3);

        #----------------------------------------------------------------------------------
        # Draw
        #----------------------------------------------------------------------------------
        beginDrawing:
            clearBackground(RAYWHITE)
            beginMode3D(camera):
                drawModel(model, vec3Zero, 1.0f, WHITE)
                drawGrid(10, 1.0f)

            drawFPS(10, 10)

    # De-Initialization
    #--------------------------------------------------------------------------------------
    unloadMaterial(model.materials[0]) # Unload material: shader and textures
    unloadModel(model)                 # Unload model
    closeWindow()                      # Close window and OpenGL context
    


main()