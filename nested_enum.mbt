
enum Option {
  Some((Int, Int))
  None
}

fn main {
  let value = Some((10, 20))
  match value {
    Some((1, 2)) => {
      println("Matched Some((1, 2))")
    }
    Some((x, y)) => {
      println("Matched Some((\{x}, \{y}))")
    }
    None => {
      println("Matched None")
    }
  }
}
