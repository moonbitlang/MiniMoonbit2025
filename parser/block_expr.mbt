///|
pub(all) struct BlockExpr {
  stmts : Array[Stmt]
} derive(Show, Eq)

///|
pub fn parse_block_expr(
  tokens : ArrayView[Token],
) -> (BlockExpr, ArrayView[Token]) raise ParseError {
  guard tokens is [{ kind: Bracket('{'), .. }, .. tokens] else {
    println("Compiler ICE: Misuse parse_block_expr")
    panic()
  }
  let stmts : Array[Stmt] = Array::new()
  let tokens = loop tokens {
    [{ kind: Bracket('}'), .. }, .. rest] => break rest
    [] => {
      println("Compiler ICE: Failed Parsing BlockExpr, Empty Token ArrayView")
      panic()
    }
    tokens => {
      let (stmt, tokens) = parse_stmt(tokens)
      stmts.push(stmt)
      continue tokens
    }
  }
  let block_expr = BlockExpr::{ stmts, }
  (block_expr, tokens)
}
