// log1p(x) function - Compute log(1+x) accurately
// Ported from math.mbt to test MiniMoonBit compiler
//
// Compiler features tested:
// 1. **Mutable variables**: extensive use of mut for algorithm state
// 2. **Complex control flow**: nested if-else, early returns, complex boolean logic
// 3. **Type reinterpretation**: Double.reinterpret_as_int64() and Int64.reinterpret_as_double()
// 4. **Bit manipulation**: extracting and modifying IEEE 754 fields
// 5. **Special value handling**: NaN, Infinity, very small numbers

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

// ============================================
// log1p(x): Compute log(1+x) accurately
// ============================================

fn log1p(x: Double) -> Double {
  if x < -1.0 || isnan(x) {
    return get_nan();
  }
  if x == -1.0 {
    return get_neg_inf();
  }
  if isinf(x) {
    return get_pos_inf();
  }
  
  let ln2_hi = 6.93147180369123816490e-01;
  let ln2_lo = 1.90821492927058770002e-10;
  let two54 = 1.80143985094819840000e+16;
  let lp1 = 6.666666666666735130e-01;
  let lp2 = 3.999999999940941908e-01;
  let lp3 = 2.857142874366239149e-01;
  let lp4 = 2.222219843214978396e-01;
  let lp5 = 1.818357216161805012e-01;
  let lp6 = 1.531383769920937332e-01;
  let zero = 0.0;
  let lp7 = 1.479819860511658591e-01;
  
  let hx = __hi(x);
  let ax = hx & 0x7fffffff;
  
  let mut f = 0.0;
  let mut c = 0.0;
  let mut s = 0.0;
  let mut z = 0.0;
  let mut r = 0.0;
  let mut u = 0.0;
  let mut hu = 0;
  let mut k = 1;
  
  if hx < 0x3FDA827A {
    if ax < 0x3e200000 {
      if two54 + x > zero && ax < 0x3c900000 {
        return x;
      } else {
        return x - x * x * 0.5;
      }
    }
    // 0xbfd2bec3 is negative when interpreted as signed Int
    // Convert to signed: -(2^32 - 0xbfd2bec3) = -1077942077
    if hx > 0 || hx <= -1077942077 {
      k = 0;
      f = x;
      hu = 1;
    }
  }
  
  if k != 0 {
    if hx < 0x43400000 {
      u = 1.0 + x;
      hu = __hi(u);
      k = (hu >> 20) - 1023;
      c = if k > 0 { 1.0 - (u - x) } else { x - (u - 1.0) };
      c = c / u;
    } else {
      u = x;
      hu = __hi(u);
      k = (hu >> 20) - 1023;
      c = 0.0;
    }
    hu = hu & 0x000fffff;
    if hu < 0x6a09e {
      let hi_masked = (hu & 0xfffff) | 0x3ff00000;
      u = __combineW(hi_masked, __low(u));
    } else {
      k = k + 1;
      let hi_masked = (hu & 0xfffff) | 0x3fe00000;
      u = __combineW(hi_masked, __low(u));
      hu = (0x00100000 - hu) >> 2;
    }
    f = u - 1.0;
  }
  
  let hfsq = 0.5 * f * f;
  
  if hu == 0 {
    if f == zero {
      if k == 0 {
        return zero;
      } else {
        c = c + k.to_double() * ln2_lo;
        return k.to_double() * ln2_hi + c;
      }
    }
    r = hfsq * (1.0 - 0.66666666666666666 * f);
    if k == 0 {
      return f - r;
    } else {
      return k.to_double() * ln2_hi - (r - (k.to_double() * ln2_lo + c) - f);
    }
  }
  
  s = f / (2.0 + f);
  z = s * s;
  r = z * (lp1 + z * (lp2 + z * (lp3 + z * (lp4 + z * (lp5 + z * (lp6 + z * lp7))))));
  
  if k == 0 {
    return f - (hfsq - s * (hfsq + r));
  } else {
    return k.to_double() * ln2_hi - (hfsq - (s * (hfsq + r) + (k.to_double() * ln2_lo + c)) - f);
  }
}

// ============================================
// Test function
// ============================================

fn main {
  println("Testing log1p function:");
  
  // Basic tests
  println(log1p(0.0));    // Should be 0
  println(log1p(0.1));    // Should be ~0.0953102
  println(log1p(1.0));    // Should be ~0.693147 (same as log(2))
  println(log1p(-0.5));   // Should be ~-0.693147 (same as log(0.5))
  
  // Special values
  println(log1p(-1.0));   // Should be -inf
  
  // Small values where log1p is more accurate than log(1+x)
  println(log1p(0.0001)); // Should be ~0.00009999500033
  println(log1p(-0.0001));// Should be ~-0.00010000500034
  
  // Additional tests
  println(log1p(0.5));    // Should be ~0.405465
  println(log1p(2.0));    // Should be ~1.098612 (log(3))
  println(log1p(-0.9));   // Should be ~-2.302585 (log(0.1))
}

