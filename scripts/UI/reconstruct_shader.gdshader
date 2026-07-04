shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture;
uniform float pixel_size = 1.0;

void fragment()
{
    vec2 resolution = vec2(1.0) / SCREEN_PIXEL_SIZE;

    vec2 uv = SCREEN_UV;

    vec2 pixel = pixel_size / resolution;

    uv = floor(uv / pixel) * pixel;

    COLOR = texture(screen_texture, uv);
}