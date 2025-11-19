// 一维热传导方程数值模拟

extern "C" fn truncate(x: Double) -> Int = "truncate"
extern "C" fn float_of_int(x: Int) -> Double = "float_of_int"

struct HeatSystem {
  temperature: Array[Double];
  size: Int;
  alpha: Double;
  dx: Double;
  dt: Double;
}

fn make_heat_system(size: Int, alpha: Double, dx: Double, dt: Double) -> HeatSystem {
  let temp = Array::make(size, 0.0);
  HeatSystem::{
    temperature: temp,
    size: size,
    alpha: alpha,
    dx: dx,
    dt: dt
  }
}

fn initialize_temperature(sys: HeatSystem, init_func: (Int) -> Double) -> Unit {
  let mut i = 0;
  while i < sys.size {
    sys.temperature[i] = init_func(i);
    i = i + 1;
  }
}

fn step(sys: HeatSystem, new_temp: Array[Double]) -> Unit {
  let r = sys.alpha * sys.dt / (sys.dx * sys.dx);
  
  new_temp[0] = sys.temperature[0];
  new_temp[sys.size - 1] = sys.temperature[sys.size - 1];
  
  let mut i = 1;
  while i < sys.size - 1 {
    let left = sys.temperature[i - 1];
    let center = sys.temperature[i];
    let right = sys.temperature[i + 1];
    
    new_temp[i] = center + r * (left - 2.0 * center + right);
    i = i + 1;
  }
  
  let mut j = 0;
  while j < sys.size {
    sys.temperature[j] = new_temp[j];
    j = j + 1;
  }
}

fn simulate(sys: HeatSystem, steps: Int) -> Unit {
  let new_temp = Array::make(sys.size, 0.0);
  let mut step_count = 0;
  
  while step_count < steps {
    step(sys, new_temp);
    step_count = step_count + 1;
  }
}

fn get_max_temperature(sys: HeatSystem) -> Double {
  let mut max_temp = sys.temperature[0];
  let mut i = 1;
  
  while i < sys.size {
    if sys.temperature[i] > max_temp {
      max_temp = sys.temperature[i];
    };
    i = i + 1;
  }
  
  max_temp
}

fn get_min_temperature(sys: HeatSystem) -> Double {
  let mut min_temp = sys.temperature[0];
  let mut i = 1;
  
  while i < sys.size {
    if sys.temperature[i] < min_temp {
      min_temp = sys.temperature[i];
    };
    i = i + 1;
  }
  
  min_temp
}

fn get_average_temperature(sys: HeatSystem) -> Double {
  let mut sum = 0.0;
  let mut i = 0;
  
  while i < sys.size {
    sum = sum + sys.temperature[i];
    i = i + 1;
  }
  
  sum / float_of_int(sys.size)
}

fn print_temperature(sys: HeatSystem) -> Unit {
  let mut i = 0;
  while i < sys.size {
    println(truncate(sys.temperature[i] * 100.0));
    i = i + 1;
  }
}

fn test_uniform_initial() -> Unit {
  let sys = make_heat_system(10, 0.1, 0.1, 0.01);
  
  fn init(i: Int) -> Double {
    50.0
  }
  
  initialize_temperature(sys, init);
  simulate(sys, 100);
  
  let avg = get_average_temperature(sys);
  println(truncate(avg));
}

fn test_step_initial() -> Unit {
  let sys = make_heat_system(11, 0.1, 0.1, 0.01);
  
  fn init(i: Int) -> Double {
    if i < 5 {
      0.0
    } else {
      100.0
    }
  }
  
  initialize_temperature(sys, init);
  simulate(sys, 50);
  
  print_temperature(sys);
}

fn test_gaussian_initial() -> Unit {
  let sys = make_heat_system(21, 0.1, 0.1, 0.01);
  
  fn init(i: Int) -> Double {
    let center = 10.0;
    let x = float_of_int(i);
    let diff = x - center;
    100.0 * (1.0 - diff * diff / 100.0)
  }
  
  initialize_temperature(sys, init);
  simulate(sys, 100);
  
  print_temperature(sys);
}

fn test_boundary_conditions() -> Unit {
  let sys = make_heat_system(10, 0.1, 0.1, 0.01);
  
  fn init(i: Int) -> Double {
    if i == 0 {
      100.0
    } else if i == 9 {
      0.0
    } else {
      50.0
    }
  }
  
  initialize_temperature(sys, init);
  simulate(sys, 200);
  
  println(truncate(sys.temperature[0]));
  println(truncate(sys.temperature[9]));
  println(truncate(get_average_temperature(sys)));
}

fn test_multiple_peaks() -> Unit {
  let sys = make_heat_system(15, 0.1, 0.1, 0.01);
  
  fn init(i: Int) -> Double {
    if i == 3 {
      80.0
    } else if i == 11 {
      60.0
    } else {
      20.0
    }
  }
  
  initialize_temperature(sys, init);
  simulate(sys, 150);
  
  print_temperature(sys);
}

fn test_cooling() -> Unit {
  let sys = make_heat_system(8, 0.1, 0.1, 0.01);
  
  fn init(i: Int) -> Double {
    100.0
  }
  
  initialize_temperature(sys, init);
  
  sys.temperature[0] = 0.0;
  sys.temperature[7] = 0.0;
  
  simulate(sys, 300);
  
  print_temperature(sys);
}

fn test_heating() -> Unit {
  let sys = make_heat_system(10, 0.1, 0.1, 0.01);
  
  fn init(i: Int) -> Double {
    0.0
  }
  
  initialize_temperature(sys, init);
  
  sys.temperature[0] = 100.0;
  sys.temperature[9] = 100.0;
  
  simulate(sys, 250);
  
  print_temperature(sys);
}

fn test_asymmetric() -> Unit {
  let sys = make_heat_system(12, 0.1, 0.1, 0.01);
  
  fn init(i: Int) -> Double {
    float_of_int(i * 10)
  }
  
  initialize_temperature(sys, init);
  simulate(sys, 200);
  
  print_temperature(sys);
}

fn main {
  test_uniform_initial();
  test_step_initial();
  test_gaussian_initial();
  test_boundary_conditions();
  test_multiple_peaks();
  test_cooling();
  test_heating();
  test_asymmetric();
}

