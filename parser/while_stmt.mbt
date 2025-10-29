///|
pub(all) struct WhileStmt {
  cond : Expr
  body : BlockExpr
} derive(Show, Eq)

///|
pub fn parse_while_stmt(
  tokens : ArrayView[Token],
) -> (WhileStmt, ArrayView[Token]) raise ParseError {
  guard tokens is [{ kind: Keyword(While), .. }, .. tokens] else {
    println("Compiler ICE: Misuse parse_while_stmt")
    panic()
  }
  let (cond, tokens) = parse_expr(tokens)
  let (body, tokens) = parse_block_expr(tokens)
  let while_stmt = WhileStmt::{ cond, body }
  (while_stmt, tokens)
}
