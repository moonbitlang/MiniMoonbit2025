// expm1(x) function - Compute exp(x) - 1 accurately
// Ported from math.mbt to test MiniMoonBit compiler
//
// Compiler features tested:
// 1. **Mutable variables**: extensive use of mut for algorithm state
// 2. **Complex control flow**: nested if-else, early returns, complex boolean logic
// 3. **Type reinterpretation**: Double.reinterpret_as_int64() and Int64.reinterpret_as_double()
// 4. **Bit manipulation**: extracting and modifying IEEE 754 fields
// 5. **Special value handling**: NaN, Infinity, very small numbers
// 6. **Shadowing**: multiple let bindings with same name in different scopes

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

// Constants
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

// Simulate unsigned comparison for Int
// Returns true if a >= b when both are treated as unsigned
fn uint_gte(a: Int, b: Int) -> Bool {
  // Convert to Int64 and mask to get unsigned 32-bit values
  let a64: Int64 = a.to_int64() & 0xFFFFFFFFL;
  let b64: Int64 = b.to_int64() & 0xFFFFFFFFL;
  a64 >= b64
}

// Simulate unsigned right shift for Int
// Shifts right by n bits, filling with zeros
fn uint_shr(value: Int, n: Int) -> Int {
  let value64: Int64 = value.to_int64() & 0xFFFFFFFFL;
  let shifted: Int64 = value64 >> n;
  shifted.to_int()
}

// ============================================
// expm1(x): Compute exp(x) - 1 accurately
// ============================================

fn expm1(x: Double) -> Double {
  if isnan(x) {
    return get_nan();
  }
  
  let o_threshold = 7.09782712893383973096e+02;
  if x > o_threshold {
    return get_pos_inf();
  }
  
  if isinf(x) {
    // x is -inf
    return -1.0;
  }
  
  let one = 1.0;
  let huge = 1.0e+300;
  let tiny = 1.0e-300;
  let ln2_hi = 6.93147180369123816490e-01;
  let ln2_lo = 1.90821492927058770002e-10;
  let invln2 = 1.44269504088896338700e+00;
  let q1 = -3.33333333333331316428e-02;
  let q2 = 1.58730158725481460165e-03;
  let q3 = -7.93650757867487942473e-05;
  let q4 = 4.00821782732936239552e-06;
  let q5 = -2.01099218183624371326e-07;
  
  let mut x = x;
  let mut hx = __hi(x);
  // Construct sign bit mask using bit shift: 1L << 31 = 0x80000000
  let sign_mask: Int = (1L << 31).to_int();
  let xsb: Int = hx & sign_mask;
  let mut y: Double = if xsb == 0 { x } else { -x };
  hx = hx & 0x7fffffff;
  
  // Filter out huge argument
  if uint_gte(hx, 0x4043687A) {
    // if |x| >= 56*ln2
    if xsb != 0 {
      // x < -56*ln2, return -1
      if x + tiny < 0.0 {
        return tiny - one;
      }
    }
  }
  
  let mut hi = 0.0;
  let mut lo = 0.0;
  let mut k = 0;
  let mut c = 0.0;
  let mut t = 0.0;
  
  // Argument reduction
  if uint_gte(hx, 0x3fd62e42 + 1) {
    // if |x| > 0.5 ln2
    if hx < 0x3FF0A2B2 {
      // if |x| < 1.5 ln2
      hi = if xsb == 0 { x - ln2_hi } else { x + ln2_hi };
      lo = if xsb == 0 { ln2_lo } else { -ln2_lo };
      k = if xsb == 0 { 1 } else { -1 };
    } else {
      k = (invln2 * x + (if xsb == 0 { 0.5 } else { -0.5 })).to_int();
      t = k.to_double();
      hi = x - t * ln2_hi;
      lo = t * ln2_lo;
    }
    x = hi - lo;
    c = hi - x - lo;
  } else if hx < 0x3c900000 {
    // |x| < 2^-54, return x
    t = huge + x;
    return x - (t - (huge + x));
  } else {
    k = 0;
  }
  
  // Compute expm1(x) for reduced x
  let hfx: Double = 0.5 * x;
  let hxs: Double = x * hfx;
  let r1: Double = one + hxs * (q1 + hxs * (q2 + hxs * (q3 + hxs * (q4 + hxs * q5))));
  let t: Double = 3.0 - r1 * hfx;
  let e: Double = hxs * ((r1 - t) / (6.0 - x * t));
  
  if k == 0 {
    return x - (x * e - hxs);
  } else {
    let e: Double = x * (e - c) - c;
    let e: Double = e - hxs;
    if k == -1 {
      return 0.5 * (x - e) - 0.5;
    }
    if k == 1 {
      return if x < -0.25 {
        -2.0 * (e - (x + 0.5))
      } else {
        one + 2.0 * (x - e)
      };
    }
    if k <= -2 || k > 56 {
      y = one - (e - x);
      let new_hi = __hi(y) + (k << 20);
      y = __combineW(new_hi, __low(y));
      return y - one;
    }
    let mut t: Double = one;
    if k < 20 {
      let new_hi = (0x3ff00000 - uint_shr(0x200000, k));
      t = __combineW(new_hi, 0);
      y = t - (e - x);
      let new_hi = __hi(y) + (k << 20);
      y = __combineW(new_hi, __low(y));
    } else {
      let new_hi = ((0x3ff - k) << 20);
      t = __combineW(new_hi, 0);
      y = x - (e + t) + one;
      let new_hi = __hi(y) + (k << 20);
      y = __combineW(new_hi, __low(y));
    }
  }
  y
}

// ============================================
// Test function
// ============================================

fn main {
  println("Testing expm1 function:");
  
  // Basic tests
  println(expm1(0.0));    // Should be 0
  println(expm1(1.0));    // Should be ~1.71828 (e - 1)
  println(expm1(-1.0));   // Should be ~-0.63212
  println(expm1(2.0));    // Should be ~6.38906
  println(expm1(-2.0));   // Should be ~-0.86466
  
  // Small values where expm1 is more accurate than exp(x) - 1
  println(expm1(0.0001)); // Should be ~0.00010000500033
  println(expm1(-0.0001));// Should be ~-0.00009999500033
  println(expm1(0.1));    // Should be ~0.10517
  println(expm1(-0.1));   // Should be ~-0.09516
  
  // Larger values
  println(expm1(3.0));    // Should be ~19.0855
  println(expm1(-3.0));   // Should be ~-0.95021
  println(expm1(5.0));    // Should be ~147.413
  println(expm1(10.0));   // Should be ~22025.5
  
  // Edge cases
  println(expm1(-1.0));   // Should be -0.63212
  println(expm1(0.5));    // Should be ~0.64872
  println(expm1(-0.5));   // Should be ~-0.39347
  
  // Special values
  println(expm1(-100.0)); // Should be close to -1
}

