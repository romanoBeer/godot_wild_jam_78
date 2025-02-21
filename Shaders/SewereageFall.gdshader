shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_schlick_ggx;

// Textures
uniform sampler2D refraction_map : filter_linear_mipmap;
uniform sampler2D water_mask : filter_linear_mipmap;

// Water parameters
uniform vec2 gap_stretch = vec2(0.8, 0.05);
uniform vec2 refraction_stretch = vec2(2.0, 0.8);
uniform float refraction_strength : hint_range(0.0, 0.1) = 0.02;
uniform vec4 water_tint : source_color = vec4(0.2, 0.6, 1.0, 0.1);
uniform vec4 water_highlight : source_color = vec4(1.0, 1.0, 1.0, 0.3);
uniform float speed = 1.0;
uniform float flow_gaps : hint_range(0.0, 1.0) = 0.33;
uniform float highlight_width : hint_range(0.0, 0.3) = 0.02;

// 3D specific parameters
uniform float roughness : hint_range(0.0, 1.0) = 0.1;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float specular : hint_range(0.0, 1.0) = 0.5;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
    
    // Add vertex displacement based on water mask
    vec2 vertex_uv = UV * gap_stretch;
    float displacement = texture(water_mask, vertex_uv + vec2(0.0, TIME * speed)).r;
    VERTEX += NORMAL * displacement * 0.1;
}

void fragment() {
    // Calculate flow UVs
    vec2 flow_uv = UV * refraction_stretch;
    vec2 time_offset = vec2(0.0, TIME * speed);
    
    // Sample noise textures with flow
    vec2 refraction_offset = texture(refraction_map, flow_uv - time_offset * 0.5).xy;
    vec2 gap_mask = texture(water_mask, flow_uv - time_offset).xy;
    
    // Center the refraction offset
    refraction_offset = refraction_offset * 2.0 - 1.0;
    
    // Calculate water color and transparency
    vec4 color = water_tint;
    float inner_edge = flow_gaps + highlight_width;
    
    // Apply water highlight on edges
    if (gap_mask.x < inner_edge) {
        color = mix(color, water_highlight, water_highlight.a);
    }
    
    // Create flow gaps
    float alpha = (gap_mask.x < flow_gaps) ? 0.0 : 1.0;
    
    // Edge effects
    float edge_fade = 1.0;
    
    // Vertical edges
    edge_fade *= smoothstep(0.0, 0.1, UV.x) * smoothstep(1.0, 0.9, UV.x);
    // Horizontal edges
    edge_fade *= smoothstep(0.0, 0.1, UV.y) * smoothstep(1.0, 0.9, UV.y);
    
    // Apply edge fade to alpha
    alpha *= edge_fade;
    
    // Calculate fresnel effect
    vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_pos);
    float fresnel = pow(1.0 - dot(normalize(world_normal), view_dir), 5.0);
    
    // Set final material properties
    ALBEDO = color.rgb;
    ALPHA = alpha * color.a;
    METALLIC = metallic;
    ROUGHNESS = roughness;
    SPECULAR = specular + fresnel * 0.2;
    
    // Add refraction to normal map
    NORMAL_MAP = vec3(refraction_offset, 1.0);
    NORMAL_MAP_DEPTH = refraction_strength;
    
    // Add rim lighting
    RIM = 0.2;
    RIM_TINT = 0.5;
}