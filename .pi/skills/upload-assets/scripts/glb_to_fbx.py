#!/usr/bin/env python3
"""
GLB to FBX converter with texture baking for Roblox.

PROBLEM
-------
Roblox's Open Cloud API only accepts FBX for 3D models, not GLB/glTF.
Naive Blender conversion (import GLB → export FBX) loses textures because:

1. glTF uses packed textures (e.g., metallicRoughness combines two channels)
2. Blender's glTF importer creates intermediate nodes (like "Separate Color")
3. Blender's FBX exporter only recognizes DIRECT Image Texture → Principled BSDF

Additionally, Blender's DIFFUSE bake type returns BLACK for metallic materials
because PBR metallic surfaces have no diffuse component (they're purely specular).
This affects models from AI generators like TRELLIS which often output high metalness.

SOLUTION
--------
This script uses emission-based texture baking:
1. Import GLB with all its complex material nodes
2. For each channel, temporarily connect the source to an Emission shader
3. Bake EMIT type (captures the actual texture values, ignoring PBR physics)
4. Build a clean material with direct texture connections
5. Export FBX with textures embedded

USAGE
-----
    blender --background --python glb_to_fbx.py -- input.glb output.fbx
    blender --background --python glb_to_fbx.py -- input.glb output.fbx --no-metallic

Options:
    --no-metallic    Skip metallic texture (use for organic models like characters,
                     animals, plants that shouldn't have metallic reflections)

REQUIREMENTS
------------
    - Blender 3.0+ (tested with 4.3)
    - Cycles render engine (included with Blender)
"""

import bpy
import os
import sys
import tempfile

# Configuration
BAKE_RESOLUTION = 1024  # Output texture resolution
BAKE_MARGIN = 16        # Pixel margin to prevent UV seam artifacts
BAKE_SAMPLES = 16       # Cycles samples (low is fine for baking)


def clear_scene():
    """Remove all objects from the scene."""
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_glb(filepath: str) -> list:
    """Import GLB and return list of mesh objects."""
    bpy.ops.import_scene.gltf(filepath=filepath)
    return [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']


def setup_bake_settings():
    """Configure Cycles for fast, accurate baking."""
    bpy.context.scene.render.engine = 'CYCLES'
    bpy.context.scene.cycles.device = 'CPU'
    bpy.context.scene.cycles.samples = BAKE_SAMPLES
    bpy.context.scene.cycles.use_denoising = False
    bpy.context.scene.render.bake.margin = BAKE_MARGIN
    bpy.context.scene.render.bake.margin_type = 'EXTEND'
    bpy.context.scene.render.bake.use_clear = True


def ensure_uv_map(obj) -> bool:
    """Ensure object has a UV map. Creates one via smart project if missing."""
    if obj.data.uv_layers:
        return True
    
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    try:
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.uv.smart_project(angle_limit=66, island_margin=0.02)
        bpy.ops.object.mode_set(mode='OBJECT')
        print(f"  Created UV map via smart project")
        return True
    except Exception as e:
        print(f"  WARNING: Could not create UV map: {e}")
        return False


def create_bake_image(name: str, is_data: bool, temp_dir: str) -> bpy.types.Image:
    """Create image for baking and save to disk for FBX embedding."""
    img = bpy.data.images.new(
        name=name,
        width=BAKE_RESOLUTION,
        height=BAKE_RESOLUTION,
        alpha=False,
        float_buffer=False,
        is_data=is_data
    )
    
    # Fill with appropriate default (gray for data, light gray for color)
    default = 0.5 if is_data else 0.8
    img.pixels[:] = [default, default, default, 1.0] * (BAKE_RESOLUTION * BAKE_RESOLUTION)
    
    # Save to disk - required for FBX embedding
    filepath = os.path.join(temp_dir, f"{name}.png")
    img.filepath_raw = filepath
    img.file_format = 'PNG'
    img.save()
    
    return img


def add_bake_target(material, image) -> bpy.types.Node:
    """
    Add Image Texture node as bake target.
    
    CRITICAL: The bake target must be the ONLY selected node. If multiple
    Image Texture nodes are selected, Blender doesn't know which to bake to.
    """
    nodes = material.node_tree.nodes
    
    # Deselect ALL nodes first
    for node in nodes:
        node.select = False
    
    tex_node = nodes.new('ShaderNodeTexImage')
    tex_node.image = image
    tex_node.select = True
    nodes.active = tex_node
    return tex_node


def bake_via_emission(obj, material, temp_dir: str, channel_name: str, 
                      source_input_name: str, is_data: bool) -> bpy.types.Image:
    """
    Bake a material channel using the emission trick.
    
    Why emission? Blender's DIFFUSE bake returns black for metallic materials
    because PBR metals have no diffuse component. By routing the texture through
    an Emission shader and baking EMIT, we capture the raw texture values.
    """
    print(f"    Baking {channel_name}...")
    img = create_bake_image(f"{obj.name}_{channel_name}", is_data=is_data, temp_dir=temp_dir)
    
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    
    # Find Principled BSDF and output
    principled = next((n for n in nodes if n.type == 'BSDF_PRINCIPLED'), None)
    output = next((n for n in nodes if n.type == 'OUTPUT_MATERIAL'), None)
    
    if not principled or not output:
        print(f"    WARNING: No Principled BSDF found, skipping {channel_name}")
        return img
    
    # Store original surface connection
    original_link = None
    for link in links:
        if link.to_node == output and link.to_socket.name == 'Surface':
            original_link = (link.from_node, link.from_socket.name)
            break
    
    # Create emission shader driven by the source channel
    emit = nodes.new('ShaderNodeEmission')
    source_input = principled.inputs[source_input_name]
    
    if source_input.is_linked:
        source = source_input.links[0].from_socket
        links.new(source, emit.inputs['Color'])
    else:
        # Use the default value
        val = source_input.default_value
        if isinstance(val, (int, float)):
            emit.inputs['Color'].default_value = (val, val, val, 1.0)
        else:
            emit.inputs['Color'].default_value = val
    
    # Connect emission to output
    links.new(emit.outputs['Emission'], output.inputs['Surface'])
    
    # Add bake target and bake
    tex_node = add_bake_target(material, img)
    bpy.ops.object.bake(type='EMIT')
    img.save()
    
    # Restore original connection
    if original_link:
        from_node, socket_name = original_link
        links.new(from_node.outputs[socket_name], output.inputs['Surface'])
    
    # Cleanup
    nodes.remove(emit)
    nodes.remove(tex_node)
    return img


def bake_roughness(obj, material, temp_dir: str) -> bpy.types.Image:
    """Bake roughness channel (has native bake type, doesn't need emission trick)."""
    print(f"    Baking roughness...")
    img = create_bake_image(f"{obj.name}_roughness", is_data=True, temp_dir=temp_dir)
    tex_node = add_bake_target(material, img)
    
    bpy.ops.object.bake(type='ROUGHNESS')
    
    img.save()
    material.node_tree.nodes.remove(tex_node)
    return img


def create_clean_material(name: str, diffuse_img, roughness_img, metallic_img):
    """
    Create material with direct texture→BSDF connections.
    
    This structure is guaranteed to export correctly to FBX because there are
    no intermediate nodes between Image Texture and Principled BSDF inputs.
    """
    mat = bpy.data.materials.new(name=f"{name}_baked")
    mat.use_nodes = True
    
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()
    
    # Principled BSDF + Output
    principled = nodes.new('ShaderNodeBsdfPrincipled')
    principled.location = (0, 0)
    output = nodes.new('ShaderNodeOutputMaterial')
    output.location = (300, 0)
    links.new(principled.outputs['BSDF'], output.inputs['Surface'])
    
    # Connect textures directly (no intermediary nodes!)
    if diffuse_img:
        tex = nodes.new('ShaderNodeTexImage')
        tex.image = diffuse_img
        tex.location = (-400, 200)
        links.new(tex.outputs['Color'], principled.inputs['Base Color'])
    
    if roughness_img:
        tex = nodes.new('ShaderNodeTexImage')
        tex.image = roughness_img
        tex.image.colorspace_settings.name = 'Non-Color'
        tex.location = (-400, -100)
        links.new(tex.outputs['Color'], principled.inputs['Roughness'])
    
    if metallic_img:
        tex = nodes.new('ShaderNodeTexImage')
        tex.image = metallic_img
        tex.image.colorspace_settings.name = 'Non-Color'
        tex.location = (-400, -400)
        links.new(tex.outputs['Color'], principled.inputs['Metallic'])
    
    return mat


def export_fbx(filepath: str):
    """Export scene to FBX with embedded textures."""
    bpy.ops.export_scene.fbx(
        filepath=filepath,
        use_selection=False,
        global_scale=1.0,
        apply_unit_scale=True,
        apply_scale_options='FBX_SCALE_ALL',
        object_types={'MESH'},
        use_mesh_modifiers=True,
        mesh_smooth_type='OFF',
        path_mode='COPY',
        embed_textures=True,
    )


def convert(input_path: str, output_path: str, skip_metallic: bool = False) -> bool:
    """Convert GLB to FBX with baked textures. Returns True on success."""
    print(f"\n{'='*60}")
    print(f"Converting: {os.path.basename(input_path)}")
    if skip_metallic:
        print(f"  (skipping metallic texture)")
    print(f"{'='*60}")
    
    temp_dir = tempfile.mkdtemp(prefix="glb_to_fbx_")
    
    clear_scene()
    setup_bake_settings()
    
    print(f"Importing GLB...")
    mesh_objects = import_glb(input_path)
    
    if not mesh_objects:
        print("ERROR: No mesh objects found")
        return False
    
    print(f"Found {len(mesh_objects)} mesh(es)")
    
    for obj in mesh_objects:
        print(f"\nProcessing: {obj.name}")
        
        if not ensure_uv_map(obj):
            print(f"  SKIP: No UV map")
            continue
        
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        
        if not obj.material_slots or not obj.material_slots[0].material:
            print(f"  SKIP: No material")
            continue
        
        original_mat = obj.material_slots[0].material
        if not original_mat.use_nodes:
            print(f"  SKIP: Material not using nodes")
            continue
        
        print(f"  Material: {original_mat.name}")
        
        # Bake channels using emission trick (works for metallic materials)
        diffuse = bake_via_emission(obj, original_mat, temp_dir, "diffuse", "Base Color", is_data=False)
        roughness = bake_roughness(obj, original_mat, temp_dir)
        metallic = None
        if not skip_metallic:
            metallic = bake_via_emission(obj, original_mat, temp_dir, "metallic", "Metallic", is_data=True)
        
        # Replace with clean material
        clean_mat = create_clean_material(obj.name, diffuse, roughness, metallic)
        obj.material_slots[0].material = clean_mat
        print(f"  Created: {clean_mat.name}")
    
    print(f"\nExporting: {output_path}")
    export_fbx(output_path)
    
    if os.path.exists(output_path):
        size = os.path.getsize(output_path)
        print(f"SUCCESS: {size:,} bytes")
        return True
    
    print("ERROR: Export failed")
    return False


if __name__ == "__main__":
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        argv = []
    
    # Parse options
    skip_metallic = "--no-metallic" in argv
    argv = [a for a in argv if not a.startswith("--")]
    
    if len(argv) < 2:
        print(__doc__)
        sys.exit(1)
    
    input_path, output_path = argv[0], argv[1]
    
    if not os.path.exists(input_path):
        print(f"ERROR: File not found: {input_path}")
        sys.exit(1)
    
    success = convert(input_path, output_path, skip_metallic=skip_metallic)
    sys.exit(0 if success else 1)
