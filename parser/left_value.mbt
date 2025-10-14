///|
pub(all) struct LeftValue {
  kind : LeftValueKind
} derive(Show, Eq)

///|
pub(all) enum LeftValueKind {
  Ident(String)
  ArrayAccess(LeftValue, Expr)
  FieldAccess(LeftValue, String)
} derive(Show, Eq)

