// exp(x) function - Exponential function
// Ported from math.mbt to test MiniMoonBit compiler
//
// Compiler features tested:
// 1. **Complex arithmetic with arrays**: halF, ln2HI, ln2LO array indexing
// 2. **Extensive bit manipulation**: extracting and setting IEEE 754 fields
// 3. **Type reinterpretation**: Double.reinterpret_as_int64() and Int64.reinterpret_as_double()
// 4. **Unsigned-like behavior with signed Int/Int64**: careful masking and shifting
// 5. **Complex control flow**: multiple if-else branches, early returns
// 6. **Special value handling**: NaN, Infinity, overflow, underflow
// 7. **Mutable variables**: extensive use of mut for algorithm state
// 8. **Array operations**: accessing constant arrays

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
// exp(x): Exponential function
// ============================================

fn exp(input: Double) -> Double {
  let mut x = input;
  let one = 1.0;
  let halF = [0.5, -0.5];
  let o_threshold = 7.09782712893383973096e+02;
  let u_threshold = -7.45133219101941108420e+02;
  let ln2HI = [6.93147180369123816490e-01, -6.93147180369123816490e-01];
  let ln2LO = [1.90821492927058770002e-10, -1.90821492927058770002e-10];
  let invln2 = 1.44269504088896338700e+00;
  let p1 = 1.66666666666666019037e-01;
  let p2 = -2.77777777770155933842e-03;
  let p3 = 6.61375632143793436117e-05;
  let p4 = -1.65339022054652515390e-06;
  let p5 = 4.13813679705723846039e-08;
  let e = 2.718281828459045;
  let mut hi = 0.0;
  let mut lo = 0.0;
  let huge = 1.0e+300;
  let twom1000 = 9.33263618503218878990e-302;
  let two1023 = 8.988465674311579539e307;
  let mut k: Int = 0;
  
  // Extract high word and sign bit
  let mut hx: Int = __hi(input);
  // xsb is the sign bit (0 for positive, 1 for negative)
  // Construct sign bit mask using bit shift: 1L << 31 = 0x80000000
  let sign_mask: Int = (1L << 31).to_int();
  let xsb: Int = uint_shr(hx & sign_mask, 31);
  // Mask off sign bit
  hx = hx & 0x7FFFFFFF;
  
  // Check for special cases
  if uint_gte(hx, 0x40862E42) {
    if uint_gte(hx, 0x7FF00000) {
      let lx: Int = __low(input);
      if ((hx & 0xFFFFF) | lx) != 0 {
        // NaN
        return input + input;
      } else if xsb == 0 {
        // +Inf
        return input;
      } else {
        // -Inf
        return 0.0;
      }
    }
    if input > o_threshold {
      // Overflow
      return huge * huge;
    }
    if input < u_threshold {
      // Underflow
      return twom1000 * twom1000;
    }
  }
  
  // Argument reduction
  if uint_gte(hx, 0x3FD62E42 + 1) {
    if hx < 0x3FF0A2B2 {
      // |x| < 0.5 ln2
      if input == 1.0 {
        return e;
      }
      hi = input - ln2HI[xsb];
      lo = ln2LO[xsb];
      k = 1 - xsb - xsb;
    } else {
      k = (invln2 * input + halF[xsb]).to_int();
      let t = k.to_double();
      hi = input - t * ln2HI[0];
      lo = t * ln2LO[0];
    }
    x = hi - lo;
  } else if hx < 0x3E300000 {
    // |x| < 2^-28, return 1 + x
    if huge + x > one {
      return one + x;
    }
  } else {
    k = 0;
  }
  
  // Compute exp(r) where r = x - k*ln2
  let t = x * x;
  
  // Construct 2^k
  let twopk = if k >= -1021 {
    // Normal case
    let exp_bits: Int = 0x3FF00000 + (k << 20);
    __combineW(exp_bits, 0)
  } else {
    // Subnormal case
    let exp_bits: Int = 0x3FF00000 + ((k + 1000) << 20);
    __combineW(exp_bits, 0)
  };
  
  let c = x - t * (p1 + t * (p2 + t * (p3 + t * (p4 + t * p5))));
  
  if k == 0 {
    return one - (x * c / (c - 2.0) - x);
  }
  
  let y = one - (lo - x * c / (2.0 - c) - hi);
  
  if k >= -1021 {
    if k == 1024 {
      return y * 2.0 * two1023;
    } else {
      return y * twopk;
    }
  } else {
    return y * twopk * twom1000;
  }
}

// ============================================
// Test function
// ============================================

fn main {
  println("Testing exp function:");
  
  // Basic tests
  println(exp(0.0));      // Should be 1
  println(exp(1.0));      // Should be ~2.71828 (e)
  println(exp(-1.0));     // Should be ~0.36788
  println(exp(2.0));      // Should be ~7.38906
  println(exp(-2.0));     // Should be ~0.13534
  
  // More tests
  println(exp(3.0));      // Should be ~20.0855
  println(exp(-3.0));     // Should be ~0.04979
  println(exp(5.0));      // Should be ~148.413
  println(exp(10.0));     // Should be ~22026.5
  
  // Small values
  println(exp(0.1));      // Should be ~1.10517
  println(exp(-0.1));     // Should be ~0.90484
  
  // Edge cases
  println(exp(100.0));    // Large positive
  println(exp(-100.0));   // Small positive (near zero)
  
  // Special values (commented out as they might need special handling)
  // println(exp(1000.0));  // Should overflow to +inf
  // println(exp(-1000.0)); // Should underflow to 0
}

