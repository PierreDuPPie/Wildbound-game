shader_type spatial;
render_mode diffuse_burley;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
 float patch=noise(world_position.xz*0.22);
 float detail=noise(world_position.xz*3.5);
 vec3 earth=mix(vec3(0.31,0.36,0.20),vec3(0.58,0.51,0.33),patch)*mix(0.93,1.03,detail);
 // Shader albedo is linear; keep the authored earth palette from washing out.
 ALBEDO=pow(earth,vec3(2.2));
 ROUGHNESS=0.96;
}
