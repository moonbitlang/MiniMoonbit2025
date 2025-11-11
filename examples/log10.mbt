// log10(x) function - Base 10 logarithm
// Ported from math.mbt to test MiniMoonBit compiler
//
// Compiler features tested:
// 1. **Function composition**: log10 calls log internally
// 2. **Type reinterpretation**: Double.reinterpret_as_int64() and Int64.reinterpret_as_double()
// 3. **Bit manipulation**: IEEE 754 field extraction and modification
// 4. **Subnormal number handling**: scaling for tiny values

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
  let sign_bit: Int64 = 1L << 63;
  let neg_inf_bits: Int64 = pos_inf_bits | sign_bit;
  neg_inf_bits.reinterpret_as_double()
}

// ============================================
// frexp: Extract mantissa and exponent (needed by log)
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
  let sign_mask: Int64 = 1L << 63;
  let mantissa_mask: Int64 = (1L << 52) - 1L;
  let frac_bits: Int64 = (u & (sign_mask | mantissa_mask)) | (1022L << 52);
  let frac: Double = frac_bits.reinterpret_as_double();
  
  (frac, exp)
}

// ============================================
// log(x): Natural logarithm (needed by log10)
// ============================================

fn log(x: Double) -> Double {
  let l1 = 6.666666666666735130e-01;
  let l2 = 3.999999999940941908e-01;
  let l3 = 2.857142874366239149e-01;
  let l4 = 2.222219843214978396e-01;
  let l5 = 1.818357216161805012e-01;
  let l6 = 1.531383769920937332e-01;
  let l7 = 1.479819860511658591e-01;
  let ln2_hi = 6.93147180369123816490e-01;
  let ln2_lo = 1.90821492927058770002e-10;
  
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
// log10(x): Base 10 logarithm
// ============================================

fn log10(x: Double) -> Double {
  if x == 0.0 {
    return get_neg_inf();
  }
  if x < 0.0 || isnan(x) {
    return get_nan();
  }
  if isinf(x) {
    return get_pos_inf();
  }
  
  let mut x = x;
  let two54 = 1.80143985094819840000e+16; // 0x43500000, 0x00000000
  let ivln10 = 4.34294481903251816668e-01; // 0x3FDBCB7B, 0x1526E50E
  let log10_2hi = 3.01029995663611771306e-01; // 0x3FD34413, 0x509F6000
  let log10_2lo = 3.69423907715893078616e-13; // 0x3D59FEF3, 0x11F12B36
  
  let mut hx: Int = __hi(x);
  let lx: Int = __low(x);
  let mut k = 0;
  
  if hx < 0x00100000 {
    k = k - 54;
    x = x * two54; // subnormal number, scale up x
    hx = __hi(x); // high word of x
  }
  
  k = k + (hx >> 20) - 1023;
  
  // Extract sign bit of k to determine if k is negative
  let i: Int = if k < 0 { 1 } else { 0 };
  
  hx = (hx & 0x000fffff) | ((0x3ff - i) << 20);
  let y = (k + i).to_double();
  x = __combineW(hx, lx);
  let z = y * log10_2lo + ivln10 * log(x);
  z + y * log10_2hi
}

// ============================================
// Test function
// ============================================

fn main {
  println("Testing log10 function:");
  
  // Basic tests - powers of 10
  println(log10(1.0));    // Should be 0
  println(log10(10.0));   // Should be 1
  println(log10(100.0));  // Should be 2
  println(log10(1000.0)); // Should be 3
  println(log10(0.1));    // Should be -1
  println(log10(0.01));   // Should be -2
  
  // Other values
  println(log10(2.0));    // Should be ~0.30103
  println(log10(5.0));    // Should be ~0.69897
  
  // Special values
  println(log10(0.0));    // Should be -inf
  
  // Verify relationship: log10(x) = log(x) / log(10)
  let x = 123.456;
  println(log10(x));      // Direct computation
  println(log(x) / log(10.0)); // Via relationship
}

