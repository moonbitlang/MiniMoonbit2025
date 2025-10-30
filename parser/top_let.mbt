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
  guard tokens is [{ kind: Keyword(Let), .. }, .. tokens] else {
    println("Compiler ICE: Misuse parse_top_let")
    panic()
  }
  guard tokens is [{ kind: Lower(name), .. }, .. tokens] else {
    @lexer.throw_(tokens[0], "Parse Error: Expect a lower ident after 'let'", Error)
    raise ParseError("Expect a lower ident")
  }
  let (ty, tokens) = if tokens is [{ kind: Symbol(":"), .. }, .. tokens] {
    let (ty, rest) = parse_type(tokens)
    (Some(ty), rest)
  } else {
    (None, tokens)
  }
  guard tokens is [{ kind: AssignOp(Assign), .. }, .. tokens] else {
    @lexer.throw_(tokens[0], "Parse Error: Expect '=' after top let", Error)
    let line = tokens[0].line
    let rest = loop tokens {
      [{ kind: Symbol(";"), .. }, .. tokens] => break tokens
      [tok, ..] as tokens if tok.line != line => break tokens
      [{ kind: Bracket('}'), .. }, ..] as tokens => break tokens
      [] as tokens => break tokens
      [_, .. tokens] => continue tokens
    }
    let expr = Expr::unit()
    let top_let = TopLet::{ name, ty, expr }
    return (top_let, rest)
  }
  let (expr, tokens) = parse_expr(tokens)
  let tokens = if tokens is [{ kind: Symbol(";"), .. }, .. tokens] {
    tokens
  } else if tokens is [tok, ..] && tok.line != expr.toks[expr.toks.length() - 1].line {
    tokens
  } else {
    @lexer.throw_(tokens[0], "Parse Error: Expect ';' or newline after top let", Error)
    tokens
  }
  let top_let = TopLet::{ name, ty, expr }
  (top_let, tokens)
}
