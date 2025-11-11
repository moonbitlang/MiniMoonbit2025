// Natural logarithm function - log(x)
// Ported from math.mbt to test MiniMoonBit compiler
//
// Compiler features tested:
// 1. **Int64 bitwise operations**: <<, >>, &, |, arithmetic right shift handling
// 2. **Type reinterpretation**: Double.reinterpret_as_int64() and Int64.reinterpret_as_double()
// 3. **Complex floating point arithmetic**: polynomial evaluation, multi-step algorithms
// 4. **Special value handling**: NaN, Infinity, negative zero, subnormal numbers
// 5. **Helper function composition**: frexp, bit manipulation utilities

// ============================================
// Helper functions for double precision bit manipulation
// ============================================

// Get high 32 bits of a double as Int
fn __hi(x: Double) -> Int {
  let bits: Int64 = x.reinterpret_as_int64();
  let shifted: Int64 = bits >> 32;
  shifted.to_int()
}

// Get low 32 bits of a double as Int
fn __low(x: Double) -> Int {
  let bits: Int64 = x.reinterpret_as_int64();
  bits.to_int()
}

// Combine high and low 32-bit integers to form a double
fn __combineW(hi: Int, low: Int) -> Double {
  let hi64: Int64 = hi.to_int64();
  let low64: Int64 = low.to_int64();
  // Mask low64 to ensure it's treated as unsigned 32 bits
  let low_masked: Int64 = low64 & 0xFFFFFFFFL;
  let combined: Int64 = (hi64 << 32) | low_masked;
  combined.reinterpret_as_double()
}

// Check if double is NaN
fn isnan(x: Double) -> Bool {
  let bits: Int64 = x.reinterpret_as_int64();
  let masked: Int64 = bits & 0x7FFFFFFFFFFFFFFFL;
  masked > 0x7FF0000000000000L
}

// Check if double is infinite
fn isinf(x: Double) -> Bool {
  let bits: Int64 = x.reinterpret_as_int64();
  let masked: Int64 = bits & 0x7FFFFFFFFFFFFFFFL;
  masked == 0x7FF0000000000000L
}

// Absolute value using bit manipulation
fn fabs(x: Double) -> Double {
  let bits: Int64 = x.reinterpret_as_int64();
  let masked: Int64 = bits & 0x7FFFFFFFFFFFFFFFL;
  masked.reinterpret_as_double()
}

// Constants
let sqrt2: Double = 1.41421356237309504880;
let double_min_positive: Double = 2.2250738585072014E-308;
let nan_bits: Int64 = 0x7FF8000000000000L;
let pos_inf_bits: Int64 = 0x7FF0000000000000L;

// Get NaN value
fn get_nan() -> Double {
  nan_bits.reinterpret_as_double()
}

// Get positive infinity
fn get_pos_inf() -> Double {
  pos_inf_bits.reinterpret_as_double()
}

// Get negative infinity
fn get_neg_inf() -> Double {
  // Construct -inf by setting sign bit of +inf
  // Use shift to avoid large hex literal
  let sign_bit: Int64 = 1L << 63;
  let neg_inf_bits: Int64 = pos_inf_bits | sign_bit;
  neg_inf_bits.reinterpret_as_double()
}

// ============================================
// frexp: Extract mantissa and exponent
// ============================================

fn normalize(f: Double) -> (Double, Int) {
  if fabs(f) < double_min_positive {
    let scale: Int64 = 1L << 52;
    let scaled: Double = f * scale.to_double();
    (scaled, -52)
  } else {
    (f, 0)
  }
}

fn frexp(f: Double) -> (Double, Int) {
  if f == 0.0 || isinf(f) || isnan(f) {
    return (f, 0);
  }
  
  let (norm_f, exp) = normalize(f);
  let u: Int64 = norm_f.reinterpret_as_int64();
  let exp_bits: Int64 = (u >> 52) & 0x7FFL;
  let exp = exp + exp_bits.to_int() - 1022;
  
  // Create fraction with exponent = 1022 (which gives 0.5 <= frac < 1.0)
  // Mask out exponent bits and set to 1022
  let sign_mask: Int64 = 1L << 63;
  let mantissa_mask: Int64 = (1L << 52) - 1L;
  let frac_bits: Int64 = (u & (sign_mask | mantissa_mask)) | (1022L << 52);
  let frac: Double = frac_bits.reinterpret_as_double();
  
  (frac, exp)
}

// ============================================
// log(x): Natural logarithm
// ============================================

fn log(x: Double) -> Double {
  let l1 = 6.666666666666735130e-01; // 3FE55555 55555593
  let l2 = 3.999999999940941908e-01; // 3FD99999 9997FA04
  let l3 = 2.857142874366239149e-01; // 3FD24924 94229359
  let l4 = 2.222219843214978396e-01; // 3FCC71C5 1D8E78AF
  let l5 = 1.818357216161805012e-01; // 3FC74664 96CB03DE
  let l6 = 1.531383769920937332e-01; // 3FC39A09 D078C69F
  let l7 = 1.479819860511658591e-01; // 3FC2F112 DF3E5244
  let ln2_hi = 6.93147180369123816490e-01; // 3fe62e42 fee00000
  let ln2_lo = 1.90821492927058770002e-10; // 3dea39ef 35793c76
  
  if x < 0.0 {
    return get_nan();
  } else if isnan(x) || isinf(x) {
    return x;
  } else if x == 0.0 {
    return get_neg_inf();
  }
  
  let (f1, ki) = frexp(x);
  let (f, k) = if f1 < sqrt2 / 2.0 {
    (f1 * 2.0 - 1.0, (ki - 1).to_double())
  } else {
    (f1 - 1.0, ki.to_double())
  };
  
  let s = f / (2.0 + f);
  let s2 = s * s;
  let s4 = s2 * s2;
  let t1 = s2 * (l1 + s4 * (l3 + s4 * (l5 + s4 * l7)));
  let t2 = s4 * (l2 + s4 * (l4 + s4 * l6));
  let r = t1 + t2;
  let hfsq = 0.5 * f * f;
  k * ln2_hi - (hfsq - (s * (hfsq + r) + k * ln2_lo) - f)
}

// ============================================
// Test function
// ============================================

fn main {
  println("Testing log function:");
  
  // Basic tests
  println(log(1.0));      // Should be 0
  println(log(2.0));      // Should be ~0.693147
  println(log(10.0));     // Should be ~2.302585
  println(log(0.1));      // Should be ~-2.302585
  
  // Special values
  println(log(0.0));      // Should be -inf
  
  // More precise tests
  println(log(2.718281828459045)); // Should be ~1 (e)
  println(log(0.5));      // Should be ~-0.693147
  
  // Additional tests
  println(log(100.0));    // Should be ~4.605170
  println(log(0.01));     // Should be ~-4.605170
  println(log(1.5));      // Should be ~0.405465
}

