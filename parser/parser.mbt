///|
pub(all) struct Program {
  top_lets : Map[String, TopLet]
  top_functions : Map[String, TopFunction]
  extern_funcions : Map[String, ExternFunction]
  struct_defs : Map[String, StructDef]
} derive(Show)

///|
pub fn parse(tokens : Array[Token]) -> Program raise ParseError {
  let top_lets = Map::new()
  let top_functions = Map::new()
  let extern_funcions = Map::new()
  let struct_defs = Map::new()
  loop tokens[:] {
    [{ kind: Keyword(Extern), ..  }, ..] as tokens => {
      let (extern_fn, rest) = parse_extern_function(tokens)
      extern_funcions.set(extern_fn.fname, extern_fn)
      continue rest
    }
    [{ kind: Keyword(Fn), ..  }, ..] as tokens => {
      let (top_fn, rest) = parse_top_function(tokens)
      top_functions.set(top_fn.fname, top_fn)
      continue rest
    }
    [{ kind: Keyword(Let), ..  }, ..] as tokens => {
      let (top_let, rest) = parse_top_let(tokens)
      top_lets.set(top_let.name, top_let)
      continue rest
    }
    [{ kind: Keyword(Struct), ..  }, ..] as tokens => {
      let (struct_def, rest) = parse_struct_def(tokens)
      struct_defs.set(struct_def.name, struct_def)
      continue rest
    }
    [{ kind: EOF, ..  }, ..] => break
    [] => {
      println("Compiler ICE: Empty Token ArrayView")
      panic()
    }
    tokens => raise ParseError("Unexpected token in top level: \{tokens[0]}")
  }
  let prog = Program::{ top_lets, top_functions, extern_funcions, struct_defs }
  prog
}
