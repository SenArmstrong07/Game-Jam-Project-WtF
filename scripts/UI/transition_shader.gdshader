shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture;

uniform float glitch_strength : hint_range(0.0, 1.0) = 0.0;
uniform float block_size = 80.0;

float random(float x)
{
    return fract(sin(x * 127.1) * 43758.5453123);
}

void fragment()
{
    vec2 uv = SCREEN_UV;

    float row = floor(uv.y * block_size);
    float r = random(row);

    uv.x += (r - 0.5) * glitch_strength;

    COLOR = texture(screen_texture, uv);
}