
pub(all) struct Program {
  top_lets: Map[String, TopLet]
  top_functions: Map[String, TopFunction]
  struct_defs: Map[String, StructDef]
}

pub fn parse(tokens: Array[Token]) -> Program raise ParseError {
  let top_lets = Map::new()
  let top_functions = Map::new()
  let struct_defs = Map::new()
  loop tokens[:] {
    [{ kind: Keyword(Fn) }, ..] as tokens => {
      let (top_fn, rest) = parse_top_function(tokens)
      top_functions.set(top_fn.fname, top_fn)
      continue rest
    }
    [{ kind: Keyword(Let) }, ..] as tokens => {
      let (top_let, rest) = parse_top_let(tokens)
      top_lets.set(top_let.name, top_let)
      continue rest
    }
    [{kind: Keyword(Struct) }, ..] as tokens => {
      let (struct_def, rest) = parse_struct_def(tokens)
      struct_defs.set(struct_def.name, struct_def)
      continue rest
    }
    [{ kind: EOF }, ..] => break
    [] => {
      println("Compiler ICE: Empty Token ArrayView")
      panic()
    }
    tokens => raise ParseError("Unexpected token in top level: \{tokens[0]}")
  }
  let prog = Program::{ top_lets, top_functions, struct_defs }
  prog
}

test "Parse Program Test" {
  let code = 
    #|struct Circle {
    #|  radius: Double;
    #|}
    #|
    #|struct Rectangle {
    #|  a: Double;
    #|  b: Double;
    #|  c: Double;
    #|}
    #|
    #|let pi: Double = 3.14;
    #|
    #|fn area_circle(c: Circle) -> Double {
    #|  if c.radius < 0.0 {
    #|    return 0.0;
    #|  };
    #|  pi * c.radius * c.radius;
    #|}
    #|
    #|fn area_rectangle(r: Rectangle) -> Double {
    #|   let p = (r.a + r.b + r.c) / 2.0;
    #|   let x = p - r.a;
    #|   let y = p - r.b;
    #|   let z = p - r.c;
    #|   sqrt(p * x * y * z);
    #|}
    #|
    #|fn main {
    #|  let c = Circle::{ radius: 2.0 };
    #|  let r = Rectangle::{ a: 3.0, b: 4.0, c: 5.0 };
    #|  let ac = area_circle(c);
    #|  let ar = area_rectangle(r);
    #|  if ac > ar { print_int(1); } else { print_int(0); };
    #|}
  

  let tokens = @lexer.tokenize(code)
  let program = parse(tokens)
  assert_true(program.struct_defs.size() is 2)
  assert_true(program.top_lets.size() is 1)
  assert_true(program.top_functions.size() is 3)
  assert_true(program.struct_defs.get("Circle") is Some(_))
  assert_true(program.struct_defs.get("Rectangle") is Some(_))
  assert_true(program.top_lets.get("pi") is Some(_))
  assert_true(program.top_functions.get("area_circle") is Some(_))
  assert_true(program.top_functions.get("area_rectangle") is Some(_))
  assert_true(program.top_functions.get("main") is Some(_))
}
