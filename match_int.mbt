fn match_tuple(x: Int, y: Int, z: Int) -> Unit {
  match (x, (y, z)) {
    (1, (2, 3)) => ()
    (4, (5, 6)) => ()
    _ => ()
  }
}

fn main {

}
