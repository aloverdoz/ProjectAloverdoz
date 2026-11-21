shader_type spatial;
// Тот же шейдер деталей, но без отсечения задних граней: листья, травинки, лепестки (одна плоскость).
render_mode cull_disabled;
#define FOLIAGE
#include "res://shaders/part_core.gdshaderinc"
