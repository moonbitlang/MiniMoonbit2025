// 信号处理 - 数字滤波器和FFT

extern "C" fn sin(x: Double) -> Double = "sin"
extern "C" fn float_of_int(x: Int) -> Double = "float_of_int"
extern "C" fn truncate(x: Double) -> Int = "truncate"
extern "C" fn abs_float(x: Double) -> Double = "abs_float"
extern "C" fn sqrt(x: Double) -> Double = "sqrt"

struct Signal {
  data: Array[Double];
  length: Int;
  sample_rate: Double;
}

fn make_signal(length: Int, sample_rate: Double) -> Signal {
  let data = Array::make(length, 0.0);
  Signal::{ data: data, length: length, sample_rate: sample_rate }
}

fn generate_sine_wave(sig: Signal, frequency: Double, amplitude: Double) -> Unit {
  let mut i = 0;
  while i < sig.length {
    let t = float_of_int(i) / sig.sample_rate;
    sig.data[i] = amplitude * sin(2.0 * 3.14159 * frequency * t);
    i = i + 1;
  }
}

fn add_noise(sig: Signal, noise_level: Double) -> Unit {
  let mut i = 0;
  while i < sig.length {
    let noise = (float_of_int((i * 1103515245 + 12345) % 2147483647) / 2147483647.0 - 0.5) * noise_level;
    sig.data[i] = sig.data[i] + noise;
    i = i + 1;
  }
}

fn low_pass_filter(sig: Signal, output: Signal, alpha: Double) -> Unit {
  if sig.length > 0 {
    output.data[0] = sig.data[0];
    
    let mut i = 1;
    while i < sig.length {
      output.data[i] = alpha * sig.data[i] + (1.0 - alpha) * output.data[i - 1];
      i = i + 1;
    }
  }
}

fn high_pass_filter(sig: Signal, output: Signal, alpha: Double) -> Unit {
  if sig.length > 0 {
    output.data[0] = sig.data[0];
    
    let mut i = 1;
    while i < sig.length {
      output.data[i] = alpha * (output.data[i - 1] + sig.data[i] - sig.data[i - 1]);
      i = i + 1;
    }
  }
}

fn moving_average(sig: Signal, output: Signal, window_size: Int) -> Unit {
  let mut i = 0;
  while i < sig.length {
    let start = if i >= window_size { i - window_size + 1 } else { 0 };
    let mut sum = 0.0;
    let mut count = 0;
    
    let mut j = start;
    while j <= i {
      sum = sum + sig.data[j];
      count = count + 1;
      j = j + 1;
    }
    
    output.data[i] = sum / float_of_int(count);
    i = i + 1;
  }
}

fn compute_rms(sig: Signal) -> Double {
  let mut sum_squares = 0.0;
  let mut i = 0;
  
  while i < sig.length {
    sum_squares = sum_squares + sig.data[i] * sig.data[i];
    i = i + 1;
  }
  
  sqrt(sum_squares / float_of_int(sig.length))
}

fn compute_peak_to_peak(sig: Signal) -> Double {
  if sig.length == 0 {
    0.0
  } else {
    let mut min_val = sig.data[0];
    let mut max_val = sig.data[0];
    let mut i = 1;
    
    while i < sig.length {
      if sig.data[i] < min_val {
        min_val = sig.data[i];
      };
      if sig.data[i] > max_val {
        max_val = sig.data[i];
      };
      i = i + 1;
    }
    
    max_val - min_val
  }
}

fn normalize_signal(sig: Signal) -> Unit {
  let max_abs = {
    let mut max_val = 0.0;
    let mut i = 0;
    while i < sig.length {
      let abs_val = abs_float(sig.data[i]);
      if abs_val > max_val {
        max_val = abs_val;
      };
      i = i + 1;
    }
    max_val
  };
  
  if max_abs > 0.0 {
    let mut i = 0;
    while i < sig.length {
      sig.data[i] = sig.data[i] / max_abs;
      i = i + 1;
    }
  }
}

fn convolve(sig1: Signal, sig2: Signal, output: Signal) -> Unit {
  let mut i = 0;
  while i < output.length {
    let mut sum = 0.0;
    let mut j = 0;
    
    while j < sig2.length {
      let idx = i - j;
      if idx >= 0 && idx < sig1.length {
        sum = sum + sig1.data[idx] * sig2.data[j];
      };
      j = j + 1;
    }
    
    output.data[i] = sum;
    i = i + 1;
  }
}

fn print_signal_samples(sig: Signal, num_samples: Int) -> Unit {
  let samples = if num_samples < sig.length { num_samples } else { sig.length };
  let mut i = 0;
  while i < samples {
    println(truncate(sig.data[i] * 100.0));
    i = i + 1;
  }
}

fn test_sine_wave_generation() -> Unit {
  let sig = make_signal(20, 100.0);
  generate_sine_wave(sig, 5.0, 1.0);
  print_signal_samples(sig, 10);
}

fn test_low_pass_filtering() -> Unit {
  let sig = make_signal(15, 100.0);
  generate_sine_wave(sig, 10.0, 1.0);
  add_noise(sig, 0.3);
  
  let filtered = make_signal(15, 100.0);
  low_pass_filter(sig, filtered, 0.3);
  
  print_signal_samples(filtered, 10);
}

fn test_moving_average() -> Unit {
  let sig = make_signal(12, 100.0);
  generate_sine_wave(sig, 5.0, 1.0);
  add_noise(sig, 0.5);
  
  let smoothed = make_signal(12, 100.0);
  moving_average(sig, smoothed, 3);
  
  print_signal_samples(smoothed, 10);
}

fn test_rms_calculation() -> Unit {
  let sig = make_signal(10, 100.0);
  generate_sine_wave(sig, 5.0, 1.0);
  
  let rms = compute_rms(sig);
  println(truncate(rms * 100.0));
}

fn test_peak_to_peak() -> Unit {
  let sig = make_signal(15, 100.0);
  generate_sine_wave(sig, 5.0, 2.0);
  
  let ptp = compute_peak_to_peak(sig);
  println(truncate(ptp * 100.0));
}

fn test_normalization() -> Unit {
  let sig = make_signal(10, 100.0);
  generate_sine_wave(sig, 5.0, 3.0);
  
  normalize_signal(sig);
  print_signal_samples(sig, 10);
}

fn test_high_pass_filter() -> Unit {
  let sig = make_signal(15, 100.0);
  generate_sine_wave(sig, 5.0, 1.0);
  
  let filtered = make_signal(15, 100.0);
  high_pass_filter(sig, filtered, 0.9);
  
  print_signal_samples(filtered, 10);
}

fn main {
  test_sine_wave_generation();
  test_low_pass_filtering();
  test_moving_average();
  test_rms_calculation();
  test_peak_to_peak();
  test_normalization();
  test_high_pass_filter();
}

