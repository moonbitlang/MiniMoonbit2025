
///|
pub(all) struct Stmt {
  lineno : Int
  column : Int
  end_lineno : Int
  end_column : Int
  kind : StmtKind
} derive(Show, Eq)

///|
pub(all) enum StmtKind {
  LetStmt(LetStmt)
  LetMutStmt(LetMutStmt)
  AssignStmt(AssignStmt)
  WhileStmt(WhileStmt)
  ExprStmt(Expr)
  ReturnStmt(Expr?)
} derive(Show, Eq)
