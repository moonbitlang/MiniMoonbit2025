
enum ColorA {
  RGB(Int, Int, Int)
  RGBA(Int, Int, Int, Int)
}

fn main {
  let a = RGB(255, 0, 0)

  match a {
    RGB(a, 0, 0) if a < 100 => println("Red in RGB")
    RGB(255, 0, 0) => println("Red in RGB")
    RGBA(255, 0, 0, 255) => println("Red in RGBA")
  }
}
