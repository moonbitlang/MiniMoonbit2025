// Cube root function - Comprehensive compiler capability test
// Ported from math.mbt/cbrt.mbt to test MiniMoonBit compiler
//
// This test exercises the following compiler features:
// 1. **Bitwise operations on Int64**: 
//    - Left shift (<<), right shift (>>), bitwise AND (&), bitwise OR (|)
//    - Critical for low-level bit manipulation
//
// 2. **Type reinterpretation (bitcast)**:
//    - Double.reinterpret_as_int64() and Int64.reinterpret_as_double()
//    - Tests the compiler's ability to reinterpret memory representations
//
// 3. **Type conversions**:
//    - Int64.to_int(), Int.to_int64()
//    - Tests proper truncation and sign extension
//
// 4. **Complex control flow**:
//    - Nested if-else expressions
//    - Multiple return paths
//    - Boolean short-circuit evaluation (||)
//
// 5. **Int64 literal handling**:
//    - Large hexadecimal constants (0x7FFFFFFFFFFFFFFFL, 0x4350000000000000L)
//    - Tests lexer and parser's ability to handle 64-bit literals
//
// 6. **Floating point operations**:
//    - Division, multiplication, addition, subtraction
//    - Mixing Int and Double in expressions
//
// 7. **Sign handling in integer division**:
//    - Division by constants
//    - Integer arithmetic with potentially "unsigned-like" semantics
//
// 8. **Function composition**:
//    - Multiple helper functions called in sequence
//    - Complex expressions with nested function calls
//
// 9. **IEEE 754 special values**:
//    - Infinity detection, NaN detection
//    - Zero and negative zero handling
//
// 10. **Extern C function integration**:
//     - Calling sqrt from C standard library

// Math functions we need from C library
extern "C" fn sqrt(x: Double) -> Double = "sqrt";

// Helper functions for double precision bit manipulation

// Get high 32 bits of a double as Int
fn __hi(x: Double) -> Int {
  let bits: Int64 = x.reinterpret_as_int64();
  let shifted: Int64 = bits >> 32L;
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
  let combined: Int64 = (hi64 << 32L) | low_masked;
  combined.reinterpret_as_double()
}

// Check if double is infinite
fn isinf(x: Double) -> Bool {
  let bits: Int64 = x.reinterpret_as_int64();
  let masked: Int64 = bits & 0x7FFFFFFFFFFFFFFFL;
  masked == 0x7FF0000000000000L
}

// Check if double is NaN
fn isnan(x: Double) -> Bool {
  let bits: Int64 = x.reinterpret_as_int64();
  let masked: Int64 = bits & 0x7FFFFFFFFFFFFFFFL;
  masked > 0x7FF0000000000000L
}

// Custom fabs using bit manipulation
fn fabs(x: Double) -> Double {
  let bits: Int64 = x.reinterpret_as_int64();
  let masked: Int64 = bits & 0x7FFFFFFFFFFFFFFFL;
  masked.reinterpret_as_double()
}

// Main cbrt function - computes cube root of x
fn cbrt(x: Double) -> Double {
  if isinf(x) || isnan(x) || x == 0.0 {
    return x;
  }
  
  // Constants for the algorithm
  let b1: Int = 715094163;  // B1 = (682-0.03306235651)*2**20
  let b2: Int = 696219795;  // B2 = (664-0.03306235651)*2**20
  let c = 5.42857142857142815906e-01;  // 19/35
  let d = -7.05306122448979611050e-01; // -864/1225
  let e = 1.41428571428571436819e+00;  // 99/70
  let f = 1.60714285714285720630e+00;  // 45/28
  let g = 3.57142857142857150787e-01;  // 5/14
  
  let sign = if x < 0.0 { true } else { false };
  let x_abs = fabs(x);
  let hx = __hi(x_abs);
  
  // Rough cbrt to 5 bits
  let t = if hx < 0x00100000 {
    // subnormal number
    let scale_bits: Int64 = 0x4350000000000000L;
    let scale: Double = scale_bits.reinterpret_as_double();
    let scaled = scale * x_abs;
    let scaled_hi = __hi(scaled);
    let divided = scaled_hi / 3;
    __combineW(divided + b2, 0)
  } else {
    // Normal number path
    let divided = hx / 3;
    __combineW(divided + b1, 0)
  };
  
  let r = t * t / x_abs;
  let s = c + r * t;
  let t = t * (g + f / (s + e + d / s));
  
  // Chop to 20 bits and make it larger than cbrt(x)
  let t = __combineW(__hi(t) + 0x00000001, 0);
  
  // One step Newton iteration to 53 bits with error less than 0.667 ulps
  let s = t * t;
  let r = x_abs / s;
  let w = t + t;
  let r = (r - t) / (w + r);
  let t = t + t * r;
  
  // Restore the sign bit
  if sign {
    -t
  } else {
    t
  }
}

// Test function
fn test_cbrt() -> Unit {
  println("Testing cbrt function:");
  
  // Test positive numbers
  println(cbrt(1.0));     // Should be 1.0
  println(cbrt(8.0));     // Should be 2.0
  println(cbrt(27.0));    // Should be 3.0
  println(cbrt(1000.0));  // Should be 10.0
  println(cbrt(2.0));     // Should be ~1.2599
  println(cbrt(3.0));     // Should be ~1.4422
  
  // Test negative numbers
  println(cbrt(-1.0));    // Should be -1.0
  println(cbrt(-8.0));    // Should be -2.0
  println(cbrt(-27.0));   // Should be -3.0
  
  // Test zero
  println(cbrt(0.0));     // Should be 0.0
  println(cbrt(-0.0));    // Should be -0.0
  
  // Test small numbers
  println(cbrt(0.125));   // Should be 0.5
  println(cbrt(0.001));   // Should be 0.1
  
  // Test larger numbers
  println(cbrt(100.0));   // Should be ~4.6416
  println(cbrt(10000.0)); // Should be ~21.5443
}

// Test helper functions
fn test_helpers() -> Unit {
  println("Testing helper functions:");
  
  // Test __hi and __low
  let x = 1.0;
  let hi = __hi(x);
  let low = __low(x);
  println(hi);
  println(low);
  
  // Test __combineW
  let reconstructed = __combineW(hi, low);
  println(reconstructed);
  
  // Test isinf
  let inf_bits: Int64 = 0x7FF0000000000000L;
  let inf_val = inf_bits.reinterpret_as_double();
  if isinf(inf_val) {
    println("Infinity detected correctly");
  } else {
    println("Infinity detection failed");
  }
  
  // Test isnan
  let nan_bits: Int64 = 0x7FF8000000000001L;
  let nan_val = nan_bits.reinterpret_as_double();
  if isnan(nan_val) {
    println("NaN detected correctly");
  } else {
    println("NaN detection failed");
  }
  
  // Test fabs
  println(fabs(-3.14));
  println(fabs(2.71));
}

// Test bitwise operations extensively
fn test_bitwise() -> Unit {
  println("Testing bitwise operations:");
  
  // Test reinterpret operations
  let d = 1.5;
  let i = d.reinterpret_as_int64();
  println(i);
  let d2 = i.reinterpret_as_double();
  println(d2);
  
  // Test bit shifts
  let val: Int64 = 0x123456789ABCDEFL;
  let shifted_right = val >> 32L;
  println(shifted_right);
  let shifted_left = shifted_right << 32L;
  println(shifted_left);
  
  // Test bit masking
  let masked = val & 0xFFFFFFFFL;
  println(masked);
  
  // Test bit OR
  let combined = (shifted_right << 32L) | masked;
  println(combined);
}

fn main {
  test_helpers();
  test_bitwise();
  test_cbrt();
}

