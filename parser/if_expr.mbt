///|
pub(all) struct IfExpr {
  cond : Expr
  then_block : BlockExpr
  else_block : Either[IfExpr, BlockExpr]?
} derive(Show, Eq)

///|
pub fn parse_if_expr(
  tokens : ArrayView[Token],
) -> (IfExpr, ArrayView[Token]) raise ParseError {
  guard tokens is [{ kind: Keyword(If), .. }, .. tokens] else {
    println("Compiler ICE: Misuse parse_if_expr")
    panic()
  }
  let (cond, tokens) = parse_expr(tokens)
  let (then_block, tokens) = parse_block_expr(tokens)
  let (else_block, tokens) = if tokens
    is [{ kind: Keyword(Else), .. }, .. tokens] {
    if tokens is [{ kind: Keyword(If), .. }, ..] {
      let (else_if, tokens) = parse_if_expr(tokens)
      (Some(Either::Left(else_if)), tokens)
    } else {
      guard tokens is [{ kind: Bracket('{'), .. }, ..] else {
        raise ParseError("Expect '{' after else")
      }
      let (else_block, tokens) = parse_block_expr(tokens)
      (Some(Either::Right(else_block)), tokens)
    }
  } else {
    (None, tokens)
  }
  let if_expr = IfExpr::{ cond, then_block, else_block }
  (if_expr, tokens)
}
