
fn fib(n : Int) -> Int {
  if n <= 1 {
    return n
  }
  fib(n - 1) + fib(n - 2)
}

fn main {
  let result = fib(37)
  println(result)
}
