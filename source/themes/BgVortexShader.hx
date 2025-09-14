package themes;


@:keep
class BgVortexShader extends FlxShader
{
	public var time(get, set):Float;

	@:glFragmentSource('
	       #pragma header

	       uniform float u_time;
	       uniform float u_speed;
	       uniform float u_scale;
	       uniform float u_mix;
	       uniform float u_iter;
	       uniform float u_hueshift;

	       vec3 hueRotate(vec3 c, float t) {
		       float a = t * 6.2831853;
		       float s = sin(a), co = cos(a);
		       mat3 m = mat3(
			       0.299 + 0.701*co + 0.168*s, 0.587 - 0.587*co + 0.330*s, 0.114 - 0.114*co - 0.497*s,
			       0.299 - 0.299*co - 0.328*s, 0.587 + 0.413*co + 0.035*s, 0.114 - 0.114*co + 0.292*s,
			       0.299 - 0.300*co + 1.250*s, 0.587 - 0.588*co - 1.050*s, 0.114 + 0.886*co - 0.203*s
		       );
		       return clamp(m * c, 0.0, 1.0);
	       }

	       float turb(vec2 p, float t, int iters) {
		       float acc = 0.0;
		       float amp = 0.5;
		       for (int i=0; i<8; i++) {
			       if (i < iters) {
				       acc += amp * (sin(p.x + t*0.7) + cos(p.y - t*0.51));
				       p = mat2(1.2, -0.7, 0.7, 1.2) * p + vec2(0.23, -0.31);
				       amp *= 0.6;
			       }
		       }
		       return acc;
	       }

	       void main() {
		       vec4 tex = flixel_texture2D(bitmap, openfl_TextureCoordv);

		       vec2 res = openfl_TextureSize;
		       vec2 uv  = openfl_TextureCoordv;

		       vec2 pxScale = max(res / 2.0, vec2(1.0));
		       uv = floor(uv * pxScale) / pxScale;

		       vec2 p = uv * 2.0 - 1.0;
		       if (res.x > 0.0 && res.y > 0.0) p.x *= res.x / res.y;
		       p *= max(u_scale, 0.001);

		       float t = u_time * u_speed;

		       float r = length(p);
		       float ang = atan(p.y, p.x) + (1.8 + 0.5*r) + 0.35 * sin(t*0.6 + r*3.0);
		       vec2 q = vec2(r * cos(ang), r * sin(ang)) * (1.0 + 0.15*sin(t*0.4));

		       int iters = int(clamp(u_iter, 1.0, 8.0));
		       float a = turb(q*2.2, t, iters);
		       float b = turb(q.yx*2.0 + a, t*1.1, iters);

		       float s1 = smoothstep(-0.6, 0.6, a - 0.3*b);
		       float s2 = 1.0 - s1;

		       vec3 c1 = hueRotate(vec3(0.98, 0.25, 0.20), u_hueshift + t*0.04);
		       vec3 c2 = hueRotate(vec3(0.10, 0.70, 1.00), u_hueshift + 0.33 + t*0.04);
		       vec3 darkish = vec3(0.15, 0.18, 0.19);

		       vec3 col = c1 * s1 + c2 * s2;
		       col = mix(col, darkish, u_mix * (0.5 + 0.5*sin(t*0.6 + a*0.7)));

		       float pulse = 0.06 * sin(t*0.8 + r*3.0);
		       col = clamp(col + pulse, 0.0, 1.0);

		       gl_FragColor = mix(vec4(col, 1.0), tex, 0.0);
	       }
       ')
	public function new()
	{
		super();
		data.u_time.value = [0.0];
		data.u_speed.value = [1.0];
		data.u_scale.value = [2.2];
		data.u_mix.value = [0.35];
		data.u_iter.value = [4.0];
		data.u_hueshift.value = [0.0];
	}

	private function get_time():Float
		return (data.u_time.value != null) ? data.u_time.value[0] : 0.0;

	private function set_time(v:Float):Float
	{
		data.u_time.value = [v];
		return v;
	}
}
