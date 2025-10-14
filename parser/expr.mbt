///|
pub(all) struct Expr {
  kind : ExprKind
} derive(Show, Eq)

///|
pub(all) enum ExprKind {
  ApplyExpr(ApplyExpr)
  BlockExpr(BlockExpr)
  NotExpr(Expr)
  NegExpr(Expr)
  BinaryExpr(BinaryOp, Expr, Expr)
  IfExpr(IfExpr)
  //MatchExpr(MatchExpr)
} derive(Show, Eq)

pub(all) enum BinaryOp {
  Add
  Sub
  Mul
  Div
  Mod
  Eq
  Ne
  Lt
  Gt
  Le
  Ge
  And
  Or
} derive(Show, Eq)
