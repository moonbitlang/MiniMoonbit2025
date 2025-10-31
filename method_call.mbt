
extern "C" fn sqrt(x: Double) -> Double = "sqrt";

struct Vec2 {
  x: Double
  y: Double
}

fn Vec2::new(x: Double, y: Double) -> Vec2 {
  Vec2::{ x: x, y: y }
}

fn Vec2::length(self: Vec2) -> Double {
  sqrt(self.x * self.x + self.y * self.y)
}

fn main {
  let v = Vec2::new(3.0, 4.0);
  let len = v.length();
  println("Length of vector: " + len.to_string() + "\n");
}
