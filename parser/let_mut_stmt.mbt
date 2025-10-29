///|
pub(all) struct LetMutStmt {
  name : String
  ty : Type?
  expr : Expr
} derive(Show, Eq)

///|
pub fn parse_let_mut_stmt(
  tokens : ArrayView[Token],
) -> (LetMutStmt, ArrayView[Token]) raise ParseError {
  guard tokens
    is [{ kind: Keyword(Let), .. }, { kind: Keyword(Mut), .. }, .. tokens] else {
    println("Compiler ICE: Misuse parse_let_mut_stmt")
    panic()
  }
  guard tokens is [{ kind: Lower(name), .. }, .. tokens] else {
    raise ParseError("Expect a lower ident")
  }
  let (ty, tokens) = if tokens is [{ kind: Symbol(":"), .. }, .. tokens] {
    let (ty, tokens) = parse_type(tokens)
    (Some(ty), tokens)
  } else {
    (None, tokens)
  }
  guard tokens is [{ kind: AssignOp(Assign), ..  }, .. tokens] else {
    raise ParseError("Expect '='")
  }
  let (expr, tokens) = parse_expr(tokens)
  let let_mut_stmt = LetMutStmt::{ name, ty, expr }
  guard tokens is [{ kind: Symbol(";"), .. }, .. tokens] else {
    raise ParseError("Expect ';' at the end of let mut statement")
  }
  (let_mut_stmt, tokens)
}
