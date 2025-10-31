// ============================================
// Ray Tracing in One Weekend - MiniMoonBit移植
// ============================================

// ============================================
// 阶段 0: Extern声明和全局常量
// ============================================

// 数学函数
extern "C" fn sqrt(x: Double) -> Double = "sqrt";
extern "C" fn sin(x: Double) -> Double = "sin";
extern "C" fn cos(x: Double) -> Double = "cos";
extern "C" fn tan(x: Double) -> Double = "tan";
extern "C" fn pow(x: Double, y: Double) -> Double = "pow";

// 类型转换
extern "C" fn int_of_float(x: Double) -> Int = "int_of_float";
extern "C" fn float_of_int(x: Int) -> Double = "float_of_int";

// 数学常量
let pi: Double = 3.14159265358979323846;
let infinity: Double = 100000000.0;

// 随机数生成器状态
let rng_state: Array[Int] = [12345];

// ============================================
// 阶段 1: 工具函数和随机数生成器
// ============================================

fn simple_rand() -> Int {
  rng_state[0] = rng_state[0] * 1103515245 + 12345;
  let temp = rng_state[0] / 65536 % 32768;
  if temp < 0 { -temp } else { temp }
}

fn simple_srand(seed: Int) -> Unit {
  rng_state[0] = seed;
}

fn random_double() -> Double {
  float_of_int(simple_rand()) / 32768.0
}

fn random_double_in_range(min: Double, max: Double) -> Double {
  min + (max - min) * random_double()
}

fn degrees_to_radians(degrees: Double) -> Double {
  degrees * pi / 180.0
}

fn clamp(x: Double, min: Double, max: Double) -> Double {
  if x < min {
    min
  } else if x > max {
    max
  } else {
    x
  }
}

fn min_double(a: Double, b: Double) -> Double {
  if a < b { a } else { b }
}

fn abs_double(x: Double) -> Double {
  if x < 0.0 { -x } else { x }
}

// ============================================
// 阶段 2: Vec3结构体和所有向量运算
// ============================================

struct Vec3 {
  x: Double
  y: Double
  z: Double
}

// 构造和访问
fn Vec3::new(x: Double, y: Double, z: Double) -> Vec3 {
  Vec3::{ x: x, y: y, z: z }
}

fn Vec3::x(self: Vec3) -> Double {
  self.x
}

fn Vec3::y(self: Vec3) -> Double {
  self.y
}

fn Vec3::z(self: Vec3) -> Double {
  self.z
}

fn Vec3::zero() -> Vec3 {
  Vec3::{ x: 0.0, y: 0.0, z: 0.0 }
}

// 基本运算
fn Vec3::add(self: Vec3, other: Vec3) -> Vec3 {
  Vec3::{ x: self.x + other.x, y: self.y + other.y, z: self.z + other.z }
}

fn Vec3::sub(self: Vec3, other: Vec3) -> Vec3 {
  Vec3::{ x: self.x - other.x, y: self.y - other.y, z: self.z - other.z }
}

fn Vec3::mul(self: Vec3, other: Vec3) -> Vec3 {
  Vec3::{ x: self.x * other.x, y: self.y * other.y, z: self.z * other.z }
}

fn Vec3::neg(self: Vec3) -> Vec3 {
  Vec3::{ x: -self.x, y: -self.y, z: -self.z }
}

fn Vec3::mul_scalar(self: Vec3, t: Double) -> Vec3 {
  Vec3::{ x: self.x * t, y: self.y * t, z: self.z * t }
}

fn Vec3::div_scalar(self: Vec3, t: Double) -> Vec3 {
  self.mul_scalar(1.0 / t)
}

fn Vec3::length_squared(self: Vec3) -> Double {
  self.x * self.x + self.y * self.y + self.z * self.z
}

fn Vec3::length(self: Vec3) -> Double {
  sqrt(self.length_squared())
}

fn Vec3::dot(self: Vec3, other: Vec3) -> Double {
  self.x * other.x + self.y * other.y + self.z * other.z
}

fn Vec3::cross(self: Vec3, other: Vec3) -> Vec3 {
  Vec3::{
    x: self.y * other.z - self.z * other.y,
    y: self.z * other.x - self.x * other.z,
    z: self.x * other.y - self.y * other.x
  }
}

fn Vec3::unit_vector(self: Vec3) -> Vec3 {
  self.div_scalar(self.length())
}

// Vec3随机函数
fn Vec3::random() -> Vec3 {
  Vec3::{ x: random_double(), y: random_double(), z: random_double() }
}

fn Vec3::random_in_range(min: Double, max: Double) -> Vec3 {
  Vec3::{
    x: random_double_in_range(min, max),
    y: random_double_in_range(min, max),
    z: random_double_in_range(min, max)
  }
}

fn random_unit_vector() -> Vec3 {
  let a = random_double_in_range(0.0, 2.0 * pi);
  let z = random_double_in_range(-1.0, 1.0);
  let r = sqrt(1.0 - z * z);
  Vec3::{ x: r * cos(a), y: r * sin(a), z: z }
}

fn random_vec3_in_unit_sphere() -> Vec3 {
  let mut p = Vec3::random_in_range(-1.0, 1.0);
  while p.length_squared() >= 1.0 {
    p = Vec3::random_in_range(-1.0, 1.0);
  }
  p
}

fn random_in_unit_disk() -> Vec3 {
  let mut p = Vec3::{ x: random_double_in_range(-1.0, 1.0), y: random_double_in_range(-1.0, 1.0), z: 0.0 };
  while p.length_squared() >= 1.0 {
    p = Vec3::{ x: random_double_in_range(-1.0, 1.0), y: random_double_in_range(-1.0, 1.0), z: 0.0 };
  }
  p
}

// 反射和折射
fn Vec3::reflect(v: Vec3, n: Vec3) -> Vec3 {
  v.sub(n.mul_scalar(2.0 * v.dot(n)))
}

fn Vec3::refract(uv: Vec3, n: Vec3, etai_over_etat: Double) -> Vec3 {
  let cos_theta = uv.neg().dot(n);
  let r_out_parallel = uv.add(n.mul_scalar(cos_theta)).mul_scalar(etai_over_etat);
  let r_out_perp = n.mul_scalar(-sqrt(1.0 - r_out_parallel.length_squared()));
  r_out_parallel.add(r_out_perp)
}

// ============================================
// 阶段 3: Color输出函数
// ============================================

fn write_color(pixel_color: Vec3, samples_per_pixel: Int) -> Unit {
  let mut r = pixel_color.x();
  let mut g = pixel_color.y();
  let mut b = pixel_color.z();
  
  // Gamma校正 (gamma=2.0)
  let scale = 1.0 / float_of_int(samples_per_pixel);
  r = sqrt(scale * r);
  g = sqrt(scale * g);
  b = sqrt(scale * b);
  
  // 输出 [0, 255] 的整数
  let ir = int_of_float(256.0 * clamp(r, 0.0, 0.999));
  let ig = int_of_float(256.0 * clamp(g, 0.0, 0.999));
  let ib = int_of_float(256.0 * clamp(b, 0.0, 0.999));
  
  println(ir.to_string() + " " + ig.to_string() + " " + ib.to_string());
}

// ============================================
// 阶段 4: Ray结构体
// ============================================

struct Ray {
  origin: Vec3
  direction: Vec3
}

fn Ray::new(origin: Vec3, direction: Vec3) -> Ray {
  Ray::{ origin: origin, direction: direction }
}

fn Ray::origin(self: Ray) -> Vec3 {
  self.origin
}

fn Ray::direction(self: Ray) -> Vec3 {
  self.direction
}

fn Ray::at(self: Ray, t: Double) -> Vec3 {
  self.origin.add(self.direction.mul_scalar(t))
}

// ============================================
// 阶段 5: 材质系统 (Tag-Based Dispatch)
// ============================================

// 材质类型标签
let mat_lambertian: Int = 0;
let mat_metal: Int = 1;
let mat_dielectric: Int = 2;

struct Material {
  mat_type: Int
  albedo: Vec3
  fuzz: Double
  ref_idx: Double
}

// 材质构造函数
fn Material::lambertian(albedo: Vec3) -> Material {
  Material::{
    mat_type: mat_lambertian,
    albedo: albedo,
    fuzz: 0.0,
    ref_idx: 0.0
  }
}

fn Material::metal(albedo: Vec3, fuzz: Double) -> Material {
  Material::{
    mat_type: mat_metal,
    albedo: albedo,
    fuzz: if fuzz < 1.0 { fuzz } else { 1.0 },
    ref_idx: 0.0
  }
}

fn Material::dielectric(ref_idx: Double) -> Material {
  Material::{
    mat_type: mat_dielectric,
    albedo: Vec3::new(1.0, 1.0, 1.0),
    fuzz: 0.0,
    ref_idx: ref_idx
  }
}

// Schlick近似
fn schlick(cosine: Double, ref_idx: Double) -> Double {
  let mut r0 = (1.0 - ref_idx) / (1.0 + ref_idx);
  r0 = r0 * r0;
  r0 + (1.0 - r0) * pow(1.0 - cosine, 5.0)
}

// Material scatter函数
fn material_scatter(
  mat: Material,
  r_in: Ray,
  normal: Vec3,
  hit_point: Vec3,
  front_face: Bool
) -> (Bool, Vec3, Ray) {
  if mat.mat_type == mat_lambertian {
    // Lambertian材质：随机漫反射
    let scatter_direction = normal.add(random_unit_vector());
    let scattered = Ray::new(hit_point, scatter_direction);
    (true, mat.albedo, scattered)
  } else if mat.mat_type == mat_metal {
    // Metal材质：镜面反射 + 模糊
    let reflected = Vec3::reflect(r_in.direction().unit_vector(), normal);
    let scattered = Ray::new(
      hit_point,
      reflected.add(random_vec3_in_unit_sphere().mul_scalar(mat.fuzz))
    );
    let did_scatter = scattered.direction().dot(normal) > 0.0;
    (did_scatter, mat.albedo, scattered)
  } else if mat.mat_type == mat_dielectric {
    // Dielectric材质：折射/反射
    let attenuation = Vec3::new(1.0, 1.0, 1.0);
    let etai_over_etat = if front_face {
      1.0 / mat.ref_idx
    } else {
      mat.ref_idx
    };
    let unit_direction = r_in.direction().unit_vector();
    let cos_theta = min_double(unit_direction.neg().dot(normal), 1.0);
    let sin_theta = sqrt(1.0 - cos_theta * cos_theta);
    
    // 判断是否全反射
    if etai_over_etat * sin_theta > 1.0 {
      let reflected = Vec3::reflect(unit_direction, normal);
      let scattered = Ray::new(hit_point, reflected);
      (true, attenuation, scattered)
    } else {
      // Schlick近似
      let reflect_prob = schlick(cos_theta, etai_over_etat);
      if random_double() < reflect_prob {
        let reflected = Vec3::reflect(unit_direction, normal);
        let scattered = Ray::new(hit_point, reflected);
        (true, attenuation, scattered)
      } else {
        let refracted = Vec3::refract(unit_direction, normal, etai_over_etat);
        let scattered = Ray::new(hit_point, refracted);
        (true, attenuation, scattered)
      }
    }
  } else {
    // 不应该到这里
    (false, Vec3::zero(), Ray::new(Vec3::zero(), Vec3::zero()))
  }
}

// ============================================
// 阶段 6: HitRecord和Sphere
// ============================================

struct HitRecord {
  p: Vec3
  normal: Vec3
  t: Double
  front_face: Bool
  mat_ref: Int
}

fn set_face_normal(rec: HitRecord, r: Ray, outward_normal: Vec3) -> HitRecord {
  let front = r.direction().dot(outward_normal) < 0.0;
  let normal = if front { outward_normal } else { outward_normal.neg() };
  HitRecord::{
    p: rec.p,
    normal: normal,
    t: rec.t,
    front_face: front,
    mat_ref: rec.mat_ref
  }
}

struct Sphere {
  center: Vec3
  radius: Double
  mat_ref: Int
}

fn Sphere::new(center: Vec3, radius: Double, mat_ref: Int) -> Sphere {
  Sphere::{ center: center, radius: radius, mat_ref: mat_ref }
}

fn sphere_hit(
  sphere: Sphere,
  r: Ray,
  t_min: Double,
  t_max: Double
) -> (Bool, HitRecord) {
  let oc = r.origin().sub(sphere.center);
  let a = r.direction().length_squared();
  let half_b = oc.dot(r.direction());
  let c = oc.length_squared() - sphere.radius * sphere.radius;
  let discriminant = half_b * half_b - a * c;
  
  if discriminant < 0.0 {
    (false, HitRecord::{
      p: Vec3::zero(),
      normal: Vec3::zero(),
      t: 0.0,
      front_face: false,
      mat_ref: 0
    })
  } else {
    let sqrtd = sqrt(discriminant);
    let mut root = (0.0 - half_b - sqrtd) / a;
    
    if root < t_min || root > t_max {
      root = (0.0 - half_b + sqrtd) / a;
      if root < t_min || root > t_max {
        (false, HitRecord::{
          p: Vec3::zero(),
          normal: Vec3::zero(),
          t: 0.0,
          front_face: false,
          mat_ref: 0
        })
      } else {
        let p = r.at(root);
        let outward_normal = p.sub(sphere.center).div_scalar(sphere.radius);
        let rec = HitRecord::{
          p: p,
          normal: outward_normal,
          t: root,
          front_face: false,
          mat_ref: sphere.mat_ref
        };
        let rec = set_face_normal(rec, r, outward_normal);
        (true, rec)
      }
    } else {
      let p = r.at(root);
      let outward_normal = p.sub(sphere.center).div_scalar(sphere.radius);
      let rec = HitRecord::{
        p: p,
        normal: outward_normal,
        t: root,
        front_face: false,
        mat_ref: sphere.mat_ref
      };
      let rec = set_face_normal(rec, r, outward_normal);
      (true, rec)
    }
  }
}

// 全局世界数据
let world_spheres: Array[Sphere] = Array::make(500, Sphere::{
  center: Vec3::zero(),
  radius: 0.0,
  mat_ref: 0
});
let world_sphere_count: Array[Int] = [0];

fn world_add_sphere(sphere: Sphere) -> Unit {
  let idx = world_sphere_count[0];
  world_spheres[idx] = sphere;
  world_sphere_count[0] = idx + 1;
}

fn world_hit(r: Ray, t_min: Double, t_max: Double) -> (Bool, HitRecord) {
  let mut hit_anything = false;
  let mut closest_so_far = t_max;
  let mut best_rec = HitRecord::{
    p: Vec3::zero(),
    normal: Vec3::zero(),
    t: 0.0,
    front_face: false,
    mat_ref: 0
  };
  
  let mut i = 0;
  while i < world_sphere_count[0] {
    let (did_hit, rec) = sphere_hit(world_spheres[i], r, t_min, closest_so_far);
    if did_hit {
      hit_anything = true;
      closest_so_far = rec.t;
      best_rec = rec;
    }
    i = i + 1;
  }
  
  (hit_anything, best_rec)
}

// 全局材质数组
let world_materials: Array[Material] = Array::make(500, Material::{
  mat_type: mat_lambertian,
  albedo: Vec3::zero(),
  fuzz: 0.0,
  ref_idx: 0.0
});
let world_material_count: Array[Int] = [0];

fn world_add_material(mat: Material) -> Int {
  let idx = world_material_count[0];
  world_materials[idx] = mat;
  world_material_count[0] = idx + 1;
  idx
}

// ============================================
// 阶段 7: Camera结构体
// ============================================

struct Camera {
  origin: Vec3
  lower_left_corner: Vec3
  horizontal: Vec3
  vertical: Vec3
  u: Vec3
  v: Vec3
  w: Vec3
  lens_radius: Double
}

fn Camera::new(
  lookfrom: Vec3,
  lookat: Vec3,
  vup: Vec3,
  vfov: Double,
  aspect_ratio: Double,
  aperture: Double,
  focus_dist: Double
) -> Camera {
  let theta = degrees_to_radians(vfov);
  let h = tan(theta / 2.0);
  let viewport_height = 2.0 * h;
  let viewport_width = aspect_ratio * viewport_height;
  
  let w = lookfrom.sub(lookat).unit_vector();
  let u = vup.cross(w).unit_vector();
  let v = w.cross(u);
  
  let origin = lookfrom;
  let horizontal = u.mul_scalar(viewport_width).mul_scalar(focus_dist);
  let vertical = v.mul_scalar(viewport_height).mul_scalar(focus_dist);
  let temp1 = origin.sub(horizontal.div_scalar(2.0));
  let temp2 = temp1.sub(vertical.div_scalar(2.0));
  let lower_left_corner = temp2.sub(w.mul_scalar(focus_dist));
  
  let lens_radius = aperture / 2.0;
  
  Camera::{
    origin: origin,
    lower_left_corner: lower_left_corner,
    horizontal: horizontal,
    vertical: vertical,
    u: u,
    v: v,
    w: w,
    lens_radius: lens_radius
  }
}

fn Camera::get_ray(self: Camera, s: Double, t: Double) -> Ray {
  let rd = random_in_unit_disk().mul_scalar(self.lens_radius);
  let offset = self.u.mul_scalar(rd.x()).add(self.v.mul_scalar(rd.y()));
  
  let ray_origin = self.origin.add(offset);
  let temp1 = self.lower_left_corner.add(self.horizontal.mul_scalar(s));
  let temp2 = temp1.add(self.vertical.mul_scalar(t));
  let temp3 = temp2.sub(self.origin);
  let ray_direction = temp3.sub(offset);
  
  Ray::new(ray_origin, ray_direction)
}

// ============================================
// 阶段 8: 核心渲染逻辑
// ============================================

fn ray_color(r: Ray, depth: Int) -> Vec3 {
  // 超过递归深度，返回黑色
  if depth <= 0 {
    Vec3::zero()
  } else {
    let (hit, rec) = world_hit(r, 0.001, infinity);
    
    if hit {
      // 获取材质
      let mat = world_materials[rec.mat_ref];
      let (did_scatter, attenuation, scattered) = material_scatter(
        mat, r, rec.normal, rec.p, rec.front_face
      );
      
      if did_scatter {
        let color = ray_color(scattered, depth - 1);
        Vec3::{
          x: attenuation.x * color.x,
          y: attenuation.y * color.y,
          z: attenuation.z * color.z
        }
      } else {
        Vec3::zero()
      }
    } else {
      // 背景渐变（天空）
      let unit_direction = r.direction().unit_vector();
      let t = 0.5 * (unit_direction.y() + 1.0);
      let white = Vec3::new(1.0, 1.0, 1.0);
      let blue = Vec3::new(0.5, 0.7, 1.0);
      white.mul_scalar(1.0 - t).add(blue.mul_scalar(t))
    }
  }
}

fn random_scene() -> Unit {
  // 清空世界
  world_sphere_count[0] = 0;
  world_material_count[0] = 0;
  
  // 地面
  let ground_mat = world_add_material(Material::lambertian(
    Vec3::new(0.5, 0.5, 0.5)
  ));
  world_add_sphere(Sphere::new(
    Vec3::new(0.0, -1000.0, 0.0),
    1000.0,
    ground_mat
  ));
  
  // 小球
  let mut a = -11;
  while a < 11 {
    let mut b = -11;
    while b < 11 {
      let choose_mat = random_double();
      let center = Vec3::new(
        float_of_int(a) + 0.9 * random_double(),
        0.2,
        float_of_int(b) + 0.9 * random_double()
      );
      
      if center.sub(Vec3::new(4.0, 0.2, 0.0)).length() > 0.9 {
        if choose_mat < 0.8 {
          // 漫反射材质
          let albedo = Vec3::random().mul(Vec3::random());
          let mat_idx = world_add_material(Material::lambertian(albedo));
          world_add_sphere(Sphere::new(center, 0.2, mat_idx));
        } else if choose_mat < 0.95 {
          // 金属材质
          let albedo = Vec3::random_in_range(0.5, 1.0);
          let fuzz = random_double_in_range(0.0, 0.5);
          let mat_idx = world_add_material(Material::metal(albedo, fuzz));
          world_add_sphere(Sphere::new(center, 0.2, mat_idx));
        } else {
          // 玻璃材质
          let mat_idx = world_add_material(Material::dielectric(1.5));
          world_add_sphere(Sphere::new(center, 0.2, mat_idx));
        }
      }
      
      b = b + 1;
    }
    a = a + 1;
  }
  
  // 三个大球
  let mat1 = world_add_material(Material::dielectric(1.5));
  world_add_sphere(Sphere::new(Vec3::new(0.0, 1.0, 0.0), 1.0, mat1));
  
  let mat2 = world_add_material(Material::lambertian(Vec3::new(0.4, 0.2, 0.1)));
  world_add_sphere(Sphere::new(Vec3::new(-4.0, 1.0, 0.0), 1.0, mat2));
  
  let mat3 = world_add_material(Material::metal(Vec3::new(0.7, 0.6, 0.5), 0.0));
  world_add_sphere(Sphere::new(Vec3::new(4.0, 1.0, 0.0), 1.0, mat3));
}

// ============================================
// 阶段 9: Main函数和渲染循环
// ============================================

fn main {
  // 图像参数
  let aspect_ratio = 3.0 / 2.0;
  let image_width = 200;
  let image_height = int_of_float(float_of_int(image_width) / aspect_ratio);
  let samples_per_pixel = 10;
  let max_depth = 10;
  
  // 初始化随机数种子
  simple_srand(42);
  
  // 创建场景
  random_scene();
  
  // 相机设置
  let lookfrom = Vec3::new(13.0, 2.0, 3.0);
  let lookat = Vec3::new(0.0, 0.0, 0.0);
  let vup = Vec3::new(0.0, 1.0, 0.0);
  let dist_to_focus = 10.0;
  let aperture = 0.1;
  
  let cam = Camera::new(
    lookfrom, lookat, vup,
    20.0, aspect_ratio, aperture, dist_to_focus
  );
  
  // PPM文件头
  println("P3");
  println(image_width.to_string() + " " + image_height.to_string());
  println("255");
  
  // 渲染循环（从上到下）
  let mut j = image_height - 1;
  while j >= 0 {
    let mut i = 0;
    while i < image_width {
      let mut pixel_color = Vec3::zero();
      
      // 多重采样
      let mut s = 0;
      while s < samples_per_pixel {
        let u = (float_of_int(i) + random_double()) / float_of_int(image_width - 1);
        let v = (float_of_int(j) + random_double()) / float_of_int(image_height - 1);
        let r = cam.get_ray(u, v);
        pixel_color = pixel_color.add(ray_color(r, max_depth));
        s = s + 1;
      }
      
      write_color(pixel_color, samples_per_pixel);
      i = i + 1;
    }
    j = j - 1;
  }
}

