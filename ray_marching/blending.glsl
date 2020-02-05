const float epsilon = 0.0001;
const int max_ray_march_steps = 64;

float sphere_sdf(vec3 sphere_center, float radius, vec3 point) {
 	return length(point - sphere_center) - radius;   
}

float cube_sdf(vec3 cube_center, float side, vec3 point) {
    vec3 p = abs(point - cube_center);
    vec3 r = p - vec3(side * 0.5);
    return length(max(r, vec3(0.0))) + min(0.0, max(r.x, max(r.y, r.z)));
}

float smooth_min(float a, float b, float k) {
	float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * h * k / 6.0;
}

float scene_sdf(vec3 point) {
    float sphere = sphere_sdf(vec3(2.0 * sin(iTime / 2.0), 0, -1), 0.5, point);
    float cube = cube_sdf(vec3(0, 0, -1), 1.0, point);
 	return smooth_min(sphere, cube, 1.3);
}

float ray_march(vec3 eye, vec3 dir, float near, float far) {
	float depth = near;
    for(int i = 0; i < max_ray_march_steps && depth < far; ++i) {
        float dist = scene_sdf(eye + dir * depth);
        if(dist < epsilon) {
            return depth;
        }
        
        depth += dist;
    }
    
    return far;
}

vec3 normal_at_point(vec3 p) {
    float x = scene_sdf(vec3(p.x + epsilon, p.y, p.z)) - scene_sdf(vec3(p.x - epsilon, p.y, p.z));
    float y = scene_sdf(vec3(p.x, p.y + epsilon, p.z)) - scene_sdf(vec3(p.x, p.y - epsilon, p.z));
    float z = scene_sdf(vec3(p.x, p.y, p.z + epsilon)) - scene_sdf(vec3(p.x, p.y, p.z - epsilon));
 	return normalize(vec3(x, y, z));
}

vec3 compute_ray_dir(float fov, vec2 viewport_size, vec2 frag_coord) {
	vec2 xy = frag_coord - viewport_size * 0.5;
    float z = viewport_size.y * 0.5 / tan(fov * 0.5);
    return normalize(vec3(xy, -z));
}

struct Point_Light {
 	vec3 pos;
    vec3 color;
    float intensity;
};
    
vec3 shade(Point_Light light, vec3 surface, vec3 normal, vec3 color, vec3 view_vec) {
    float light_dist_squared = dot(light.pos - surface, light.pos - surface);
    float attentuation = 1.0 / (light_dist_squared + 1.0);
    vec3 light_dir = normalize(light.pos - surface);
	float dotted = max(dot(light_dir, normal), 0.0);
    vec3 diffuse = color * dotted * light.intensity * light.color * attentuation;
    return diffuse;
}

void mainImage(out vec4 frag_color, in vec2 frag_coord) {
    const float camera_far = 100.0;
    const float camera_near = 0.003;
    vec3 ray = compute_ray_dir(radians(70.0), iResolution.xy, frag_coord);
    vec3 eye = vec3(0, 0, 2);
    float dist = ray_march(eye, ray, camera_near, camera_far);
    
    Point_Light lights[2];
    float angle = iTime;
    vec3 light_pos = vec3(cos(angle), .75, sin(angle)) * 2.0;
    lights[0] = Point_Light(light_pos, vec3(1), 2.5);
    lights[1] = Point_Light(vec3(-1, -1, 2), vec3(1), 2.3);
    
    if(dist < camera_far - epsilon) {
        vec3 surface_color = vec3(1, 0, 0);
        vec3 surface = eye + ray * dist;
        vec3 normal = normal_at_point(surface);
        
        vec3 out_color = surface_color * 0.1;
        for(int i = 0; i < 2; ++i) {
         	out_color += shade(lights[i], surface, normal, surface_color, -ray);
        }
        
		frag_color = vec4(out_color, 1.0);
    } else {
     	frag_color = vec4(0, 0, 0, 1);   
    }
}
