
fn print_bool(v: Bool) -> Unit {
  match v {
    true => println("It's true!")
    false => println("It's false!")
  }
}

fn main {
  print_bool(true)
  print_bool(false)
}
