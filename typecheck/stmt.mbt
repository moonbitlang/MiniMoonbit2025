///|
pub(all) struct Stmt {
  kind : StmtKind
} derive(Show)

///|
pub(all) enum StmtKind {
  LetStmt(LetStmt)
  LetMutStmt(LetMutStmt)
  AssignStmt(AssignStmt)
  WhileStmt(WhileStmt)
  ForStmt(ForStmt)
  ExprStmt(Expr)
  ReturnStmt(Expr?)
  LocalFunction(LocalFunction)
} derive(Show)

///|
pub fn Context::check_stmt(
  self : Context,
  stmt : @parser.Stmt,
) -> Stmt raise TypeCheckError {
  match stmt.kind {
    LetStmt(let_stmt) => {
      let checked_let = self.check_let_stmt(let_stmt)
      Stmt::{ kind: LetStmt(checked_let) }
    }
    LetMutStmt(let_mut_stmt) => {
      let checked_let_mut = self.check_let_mut_stmt(let_mut_stmt)
      Stmt::{ kind: LetMutStmt(checked_let_mut) }
    }
    AssignStmt(assign_stmt) => {
      let checked_assign = self.check_assign_stmt(assign_stmt)
      Stmt::{ kind: AssignStmt(checked_assign) }
    }
    ExprStmt(expr) => {
      let checked_expr = self.check_expr(expr)
      Stmt::{ kind: ExprStmt(checked_expr) }
    }
    ReturnStmt(None) => {
      guard self.current_func_ret_ty is Some(func_ret_ty) else {
        raise TypeCheckError("Return statement used outside of a function")
      }
      if !self.is_type_compatible(func_ret_ty, Unit) {
        raise TypeCheckError(
          "Return statement without value in function with non-unit return type",
        )
      }
      Stmt::{ kind: ReturnStmt(None) }
    }
    ReturnStmt(Some(expr)) => {
      let checked_expr = self.check_expr(expr)
      guard self.current_func_ret_ty is Some(func_ret_ty) else {
        raise TypeCheckError("Return statement used outside of a function")
      }
      if !self.is_type_compatible(func_ret_ty, checked_expr.ty) {
        raise TypeCheckError(
          "Return type mismatch, wanted: \{func_ret_ty}, got: \{checked_expr.ty}",
        )
      }
      Stmt::{ kind: ReturnStmt(Some(checked_expr)) }
    }
    WhileStmt(while_stmt) => {
      let checked_while = self.check_while_stmt(while_stmt)
      Stmt::{ kind: WhileStmt(checked_while) }
    }
    ForStmt(for_stmt) => {
      let checked_for = self.check_for_stmt(for_stmt)
      Stmt::{ kind: ForStmt(checked_for) }
    }
    LocalFunction(local_function) => {
      let checked_local_function = self.check_local_function(local_function)
      Stmt::{ kind: LocalFunction(checked_local_function) }
    }
    NoopStmt => raise TypeCheckError("Error happened in Parser Phase")
  }
}
