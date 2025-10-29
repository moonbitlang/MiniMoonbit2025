///|
pub(all) struct LetStmt {
  pattern : Pattern
  ty : Type?
  expr : Expr
} derive(Show, Eq)

///|
pub fn parse_let_stmt(
  tokens : ArrayView[Token],
) -> (LetStmt, ArrayView[Token]) raise ParseError {
  guard tokens is [{ kind: Keyword(Let), .. }, .. tokens] else {
    println("Compiler ICE: Misuse parse_let_stmt")
    panic()
  }
  let (pattern, tokens) = parse_pattern(tokens)
  let (ty, tokens) = if tokens is [{ kind: Symbol(":"), .. }, .. tokens] {
    let (ty, tokens) = parse_type(tokens)
    (Some(ty), tokens)
  } else {
    (None, tokens)
  }
  guard tokens is [{ kind: AssignOp(Assign), .. }, .. tokens] else {
    raise ParseError("Expect '='")
  }
  let (expr, tokens) = parse_expr(tokens)
  let let_stmt = LetStmt::{ pattern, ty, expr }
  guard tokens is [{ kind: Symbol(";"), .. }, .. tokens] else {
    raise ParseError("Expect ';' after let statement")
  }
  (let_stmt, tokens)
}
