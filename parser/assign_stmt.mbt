pub(all) struct AssignStmt {
  left_value : LeftValue
  op : AssignOp
  expr : Expr
} derive(Show, Eq)

pub(all) enum AssignOp {
  Assign
  AddAssign
  SubAssign
  MulAssign
  DivAssign
} derive(Show, Eq)
