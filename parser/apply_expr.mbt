pub(all) struct ApplyExpr {
  kind : ApplyExprKind
} derive(Show, Eq)

///|
pub(all) enum ApplyExprKind {
  AtomExpr(AtomExpr)
  ArrayAccess(ApplyExpr, Expr)
  FieldAccess(ApplyExpr, String)
  TupleAccess(ApplyExpr, Int)
  Call(ApplyExpr, Array[Expr])
} derive(Show, Eq)

