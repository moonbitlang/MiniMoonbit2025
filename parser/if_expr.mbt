
pub(all) enum Either[L, R] {
  Left(L)
  Right(R)
} derive(Show, Eq)

pub(all) struct IfExpr {
  lineno : Int
  column : Int
  end_lineno : Int
  end_column : Int
  cond : Expr
  then_block : BlockExpr
  else_block : Either[IfExpr, BlockExpr]?
} derive(Show, Eq)
