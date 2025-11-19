// 深空导航系统 - 星际航行路径规划和姿态控制

extern "C" fn sqrt(x: Double) -> Double = "sqrt"
extern "C" fn truncate(x: Double) -> Int = "trunc"

enum ManeuverType {
  Prograde;
  Retrograde;
  Normal;
  AntiNormal;
}

enum NavigationMode {
  Cruise;
  Approach;
  Station_Keeping;
  Emergency;
}

struct Vector3D {
  x: Double;
  y: Double;
  z: Double;
}

struct Quaternion {
  w: Double;
  x: Double;
  y: Double;
  z: Double;
}

struct Spacecraft {
  position: Vector3D;
  velocity: Vector3D;
  orientation: Quaternion;
  mass: Double;
  fuel: Double;
}

struct Maneuver {
  delta_v: Vector3D;
  burn_time: Double;
  fuel_cost: Double;
}

struct CelestialBody {
  position: Vector3D;
  velocity: Vector3D;
  mass: Double;
  radius: Double;
}

struct TrajectoryPoint {
  position: Vector3D;
  velocity: Vector3D;
  time: Double;
}

fn make_vector3d(x: Double, y: Double, z: Double) -> Vector3D {
  Vector3D::{ x: x, y: y, z: z }
}

fn make_quaternion(w: Double, x: Double, y: Double, z: Double) -> Quaternion {
  Quaternion::{ w: w, x: x, y: y, z: z }
}

fn make_spacecraft(
  pos: Vector3D,
  vel: Vector3D,
  orient: Quaternion,
  mass: Double,
  fuel: Double
) -> Spacecraft {
  Spacecraft::{
    position: pos,
    velocity: vel,
    orientation: orient,
    mass: mass,
    fuel: fuel
  }
}

fn make_body(pos: Vector3D, vel: Vector3D, mass: Double, radius: Double) -> CelestialBody {
  CelestialBody::{
    position: pos,
    velocity: vel,
    mass: mass,
    radius: radius
  }
}

fn vector_add(v1: Vector3D, v2: Vector3D) -> Vector3D {
  make_vector3d(v1.x + v2.x, v1.y + v2.y, v1.z + v2.z)
}

fn vector_sub(v1: Vector3D, v2: Vector3D) -> Vector3D {
  make_vector3d(v1.x - v2.x, v1.y - v2.y, v1.z - v2.z)
}

fn vector_scale(v: Vector3D, s: Double) -> Vector3D {
  make_vector3d(v.x * s, v.y * s, v.z * s)
}

fn vector_magnitude(v: Vector3D) -> Double {
  sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
}

fn vector_normalize(v: Vector3D) -> Vector3D {
  let mag = vector_magnitude(v);
  if mag > 0.0 {
    vector_scale(v, 1.0 / mag)
  } else {
    make_vector3d(0.0, 0.0, 0.0)
  }
}

fn vector_dot(v1: Vector3D, v2: Vector3D) -> Double {
  v1.x * v2.x + v1.y * v2.y + v1.z * v2.z
}

fn vector_cross(v1: Vector3D, v2: Vector3D) -> Vector3D {
  make_vector3d(
    v1.y * v2.z - v1.z * v2.y,
    v1.z * v2.x - v1.x * v2.z,
    v1.x * v2.y - v1.y * v2.x
  )
}

fn gravitational_acceleration(pos: Vector3D, body: CelestialBody, g_const: Double) -> Vector3D {
  let r = vector_sub(body.position, pos);
  let dist = vector_magnitude(r);
  
  if dist < body.radius {
    make_vector3d(0.0, 0.0, 0.0)
  } else {
    let acc_mag = g_const * body.mass / (dist * dist);
    let dir = vector_normalize(r);
    vector_scale(dir, acc_mag)
  }
}

fn update_spacecraft_position(
  craft: Spacecraft,
  bodies: Array[CelestialBody],
  num_bodies: Int,
  g_const: Double,
  dt: Double
) -> Spacecraft {
  let mut total_acc = make_vector3d(0.0, 0.0, 0.0);
  
  let mut i = 0;
  while i < num_bodies {
    let acc = gravitational_acceleration(craft.position, bodies[i], g_const);
    total_acc = vector_add(total_acc, acc);
    i = i + 1;
  }
  
  let new_vel = vector_add(craft.velocity, vector_scale(total_acc, dt));
  let new_pos = vector_add(craft.position, vector_scale(new_vel, dt));
  
  Spacecraft::{
    position: new_pos,
    velocity: new_vel,
    orientation: craft.orientation,
    mass: craft.mass,
    fuel: craft.fuel
  }
}

fn calculate_hohmann_transfer(r1: Double, r2: Double, mu: Double) -> (Double, Double) {
  let a = (r1 + r2) / 2.0;
  let v1 = sqrt(mu / r1);
  let v_transfer1 = sqrt(mu * (2.0 / r1 - 1.0 / a));
  let delta_v1 = v_transfer1 - v1;
  
  let v2 = sqrt(mu / r2);
  let v_transfer2 = sqrt(mu * (2.0 / r2 - 1.0 / a));
  let delta_v2 = v2 - v_transfer2;
  
  (delta_v1, delta_v2)
}

fn calculate_escape_velocity(radius: Double, mass: Double, g_const: Double) -> Double {
  sqrt(2.0 * g_const * mass / radius)
}

fn calculate_orbital_period(semi_major_axis: Double, mu: Double) -> Double {
  let pi = 3.14159;
  2.0 * pi * sqrt(semi_major_axis * semi_major_axis * semi_major_axis / mu)
}

fn apply_thrust(
  craft: Spacecraft,
  direction: Vector3D,
  thrust: Double,
  dt: Double,
  isp: Double
) -> Spacecraft {
  let acceleration = vector_scale(direction, thrust / craft.mass);
  let new_vel = vector_add(craft.velocity, vector_scale(acceleration, dt));
  
  let fuel_consumption = thrust * dt / isp;
  let new_fuel = craft.fuel - fuel_consumption;
  
  if new_fuel < 0.0 {
    craft
  } else {
    Spacecraft::{
      position: craft.position,
      velocity: new_vel,
      orientation: craft.orientation,
      mass: craft.mass,
      fuel: new_fuel
    }
  }
}

fn quaternion_multiply(q1: Quaternion, q2: Quaternion) -> Quaternion {
  make_quaternion(
    q1.w * q2.w - q1.x * q2.x - q1.y * q2.y - q1.z * q2.z,
    q1.w * q2.x + q1.x * q2.w + q1.y * q2.z - q1.z * q2.y,
    q1.w * q2.y - q1.x * q2.z + q1.y * q2.w + q1.z * q2.x,
    q1.w * q2.z + q1.x * q2.y - q1.y * q2.x + q1.z * q2.w
  )
}

fn quaternion_normalize(q: Quaternion) -> Quaternion {
  let mag = sqrt(q.w * q.w + q.x * q.x + q.y * q.y + q.z * q.z);
  if mag > 0.0 {
    make_quaternion(q.w / mag, q.x / mag, q.y / mag, q.z / mag)
  } else {
    make_quaternion(1.0, 0.0, 0.0, 0.0)
  }
}

fn rotate_spacecraft(craft: Spacecraft, rotation: Quaternion) -> Spacecraft {
  let new_orientation = quaternion_normalize(quaternion_multiply(craft.orientation, rotation));
  
  Spacecraft::{
    position: craft.position,
    velocity: craft.velocity,
    orientation: new_orientation,
    mass: craft.mass,
    fuel: craft.fuel
  }
}

fn determine_navigation_mode(distance: Double, velocity_mag: Double) -> NavigationMode {
  if distance < 10.0 {
    Station_Keeping
  } else if distance < 100.0 {
    Approach
  } else if velocity_mag > 50.0 {
    Emergency
  } else {
    Cruise
  }
}

fn mode_to_int(mode: NavigationMode) -> Int {
  match mode {
    Cruise => 0;
    Approach => 1;
    Station_Keeping => 2;
    Emergency => 3;
  }
}

fn print_vector(v: Vector3D) -> Unit {
  println(truncate(v.x * 10.0));
  println(truncate(v.y * 10.0));
  println(truncate(v.z * 10.0));
}

fn test_vector_operations() -> Unit {
  let v1 = make_vector3d(1.0, 2.0, 3.0);
  let v2 = make_vector3d(4.0, 5.0, 6.0);
  
  let sum = vector_add(v1, v2);
  print_vector(sum);
  
  let mag = vector_magnitude(v1);
  println(truncate(mag * 10.0));
}

fn test_orbital_mechanics() -> Unit {
  let r1 = 10000.0;
  let r2 = 20000.0;
  let mu = 1000000.0;
  
  let (dv1, dv2) = calculate_hohmann_transfer(r1, r2, mu);
  println(truncate(dv1 * 10.0));
  println(truncate(dv2 * 10.0));
}

fn test_spacecraft_motion() -> Unit {
  let pos = make_vector3d(10000.0, 0.0, 0.0);
  let vel = make_vector3d(0.0, 100.0, 0.0);
  let orient = make_quaternion(1.0, 0.0, 0.0, 0.0);
  let craft = make_spacecraft(pos, vel, orient, 1000.0, 500.0);
  
  let body_pos = make_vector3d(0.0, 0.0, 0.0);
  let body_vel = make_vector3d(0.0, 0.0, 0.0);
  let body = make_body(body_pos, body_vel, 1000000.0, 1000.0);
  
  let bodies = [body];
  let result = update_spacecraft_position(craft, bodies, 1, 1.0, 1.0);
  
  print_vector(result.position);
  print_vector(result.velocity);
}

fn test_thrust_application() -> Unit {
  let pos = make_vector3d(10000.0, 0.0, 0.0);
  let vel = make_vector3d(0.0, 100.0, 0.0);
  let orient = make_quaternion(1.0, 0.0, 0.0, 0.0);
  let craft = make_spacecraft(pos, vel, orient, 1000.0, 500.0);
  
  let thrust_dir = make_vector3d(1.0, 0.0, 0.0);
  let result = apply_thrust(craft, thrust_dir, 100.0, 10.0, 300.0);
  
  print_vector(result.velocity);
  println(truncate(result.fuel));
}

fn test_navigation_modes() -> Unit {
  let mode1 = determine_navigation_mode(5.0, 10.0);
  let mode2 = determine_navigation_mode(50.0, 20.0);
  let mode3 = determine_navigation_mode(200.0, 30.0);
  let mode4 = determine_navigation_mode(100.0, 60.0);
  
  println(mode_to_int(mode1));
  println(mode_to_int(mode2));
  println(mode_to_int(mode3));
  println(mode_to_int(mode4));
}

fn main {
  test_vector_operations();
  test_orbital_mechanics();
  test_spacecraft_motion();
  test_thrust_application();
  test_navigation_modes();
}

