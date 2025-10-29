///|
pub struct TopLet {
  name : String
  ty : Type?
  expr : Expr
} derive(Show, Eq)

///|
pub fn parse_top_let(
  tokens : ArrayView[Token],
) -> (TopLet, ArrayView[Token]) raise ParseError {
  guard tokens is [{ kind: Keyword(Let), ..  }, .. tokens] else {
    println("Compiler ICE: Misuse parse_top_let")
    panic()
  }
  guard tokens is [{ kind: Lower(name), ..  }, .. tokens] else {
    raise ParseError("Expect a lower ident")
  }
  let (ty, tokens) = if tokens is [{ kind: Symbol(":"), ..  }, .. tokens] {
    let (ty, rest) = parse_type(tokens)
    (Some(ty), rest)
  } else {
    (None, tokens)
  }
  guard tokens is [{ kind: AssignOp(Assign), ..  }, .. tokens] else {
    raise ParseError("Expect '='")
  }
  let (expr, tokens) = parse_expr(tokens)
  guard tokens is [{ kind: Symbol(";"), ..  }, .. tokens] else {
    raise ParseError("Failed Parsing Top Let: Expect ';'")
  }
  let top_let = TopLet::{ name, ty, expr }
  (top_let, tokens)
}
