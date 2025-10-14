///|
pub(all) struct AtomExpr {
  kind : AtomExprKind
} derive(Show, Eq)

///|
pub(all) enum AtomExprKind {
  Int(Int)
  Int64(Int64)
  UInt(UInt)
  UInt64(UInt64)
  Float(Float)
  Double(Double)
  Bool(Bool)
  String(String)
  Ident(String)
  Unit
  Paren(Expr)
  Tuple(Array[Expr])
  Array(Array[Expr])
  StructConstruct(String, Array[(String, Expr)])
} derive(Show, Eq)

