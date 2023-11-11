# vrc-rtrti-basic
Very basic example of using VRC-RTRTI

## General Setup

For VCC
 * AudioLink
 * TXL - VideoTXL

In general VRC-RTRTI uses:
 * Enlighten for diffuse RTGI and Avatar auto-lighting by light probes, as well as to generate an LPPV for secondary ray lighting.
 * A baked-traversal AABB heirarchy, that secondary rays use to compute subtle aspects of surfaces.
 * An emission texture for any light you want to cast into the world, i.e. from a video player or AudioLink.

Primary rays that hit reflective surfaces (ones that either use rtrti-standard (for static, lightmapped objects) or rtrti-standard-dynamic (for dynamic objects) and the compute the secondary ray.  This ray is computed per pixel to determine what the reflected pixel should look like.

![Debug Image](https://raw.githubusercontent.com/cnlohr/vrc-rtrti-basic/master/DocImages/DebugImg.png)

### Geometry

For your world, you will need to generate three pieces of geometry:

* High-res world geometry
   * You can use whatever world geometry you wish for this.  You may use however many material slots you wish for this as well.  While people's GPUs will need to render all this geometry, having tens of thousands of polys is fine.  Additionally, you MAY have quads, and other nontrivial-to-interpret geometry elements in this part of the model.
* Emission source geometry
   * Emission sources are used to emit data into the Enlighten system, as well as appear to the user as general light sources in the world.  This geometry should be kept relatively simple, try to keep it to < about 1000 polygons.  This will be rendered into a light emission map on the GPU, read from the GPU onto the CPU, then Enlighten will compute all the real time GI from it.  Just be careful with it.
* Low-Res world geometry
   * Low res geometry is what is processed into the baked-traversal AABB.  This is what you need to *really* crank down on.  The demo scene has 1k triangles.  The baking algorithm then takes this, and generates a texture .asset file.  This texture is ultimately what is used to traverse the volume structure.  Be aware any geometry added here follows an O(n^3) algorithm to generate the structure.  So, while 1k tris takes about 2 seconds to process, 4k takes almost 2 minutes!  And more geometry here will lower the frame rate of your users.
   * Low res geometry must use UVs outside the 0..1 range, where the fractional portion of the UV value indicates its location within a UV map.  The whole number value represents which texture in the combined textures texture to sample from.
   * This is tricky, you can do this when combining the geometry, and decimating, going to uv mode, pressing `g` then `x` then typing the number of the texture as it appears in the composite texture (See below) to move the UVs to the correct place.

![Blender Example](https://raw.githubusercontent.com/cnlohr/vrc-rtrti-basic/master/DocImages/BlenderImg.png)

You may export your high-res and emission source geometry may be exported as FBXs or OBJs, or whatever, but, your Low-res world geometry *must* be exported as an OBJ file.  It *must* be triangularized.  You can do this easily by using the Blender OBJ exporer, and selecting "only export selected objects".

Once exported from Blender, you will need to run `bvhgen.exe` to produce the computed map.  There is a batch file showing example invocation in `regenerate_asset.bat` which reads LowDef.obj and outputs LowDef.asset.

As a note - the traversal tree is baked once for each cardinal direction, +x, -x, +y, -y, +z, -z, depending on which direction is dominant for the specific ray to accelerate the tracing at run time.  It effectively pre-sorts the volume traversal based on the dominant direction of the ray.

### Textures

You will need to use the "Combined" shader/material to generate a special texture that contains a map of all of the textures that rays may hit (including the video players).

You can do this by dropping in your extra materials into the material slots on this material.  It's currently hard-coded to 10 total textures, so any additional ones will take code modification.

![Composite Texture](https://raw.githubusercontent.com/cnlohr/vrc-rtrti-basic/master/DocImages/Composite.png)

### Materials

In the `Materials` folder, there are several materials.  For dynamic objects, they cannot be in other object's reflections, but they can receive reflected rays. For dynamic objects, use the -dynamic  shader.  For static objects, they must reference the lightmap.

## Detailed Instruction List

Steps to use this tool in all of its functioning.
 * Add AudioLink Object
 * Add AudioLink Controller
 * Add VideoTXL Player
   * Hide the Display Quad
 * Click the "Attach" to audiolink button and the connect to sub components button on the VideoTXL Player
 * Click the "Attach Audio Objects" for the AudioLink object.
 * Under the VideoTXL Player's Screen Manager, potentially remove the Materials Block Override
 * Create a new empty that contains a Screen Property Map.
   * This will specify where your textures go.
 * Under the VideoTXL Player's Screen Manager, add a "Render Texture Output"
   * Add CTCopy to the "Output Custom Render Textures"
 * Under Lighting, check "Realtime Global Illumination"
 * Select Ambient Mode -> Realtime
 * Select Light Mapper -> "Enlighten"
 * Regenerate lightmaps.
 * Add EmissiveUpdater2 to the mesh that's emitting light.
 * Create new empty, called PostProcessing
   * Add a Post-Processing Volume
   * Create new profile
   * Add Bloom -> Intensity = 1.5, Threshold = 0.8, Clamp = 3
   * Add Color Grading -> Mode = Aces
 * Make new empty that is called light probes.
   * Create new light probe group
   * Add your light probes.
 * Add a Light Probe Proxy Volume component.
   * Set it to Cell Corner
   * Assign it to your light probes.
 * Be sure you mimic the lighting settings for emissive and receiving (raytraced) objects.  Large static receiving scenes should use lightmaps.  Emissive objects must tightly adhere to the lighting settings held within.
 * Your high quality mesh, you can use a lightmap, but you will need to go into Debug, and then set Light Probe Usage = 2, and assign the light probe proxy volume.

 

Warnings:
 * The Emissive texture for RTGI is cursed.  PLEASE just copy-paste it and not mess with it.
   
Notes:
 * You can modify CustomRenderTexture/CTCopy to use custom areas in the texture to include dynamic lighting.

Future work:
 * Make toggle for grab pass.

## Working with the C tool

The core of this is a C program that lives in Assets/rtrti that converts .obj files into accelerated pre-baked structures.

To recompile, just install TCC (3.8 MB download) https://github.com/cnlohr/tinycc-win64-installer/releases/tag/v0_0.9.27

# Importing

Open .blend file in DemoScene/SoruceModel~  (The ~ is there to prevent Unity from importing the blend).

Export each object as a separate OBJ file. 
