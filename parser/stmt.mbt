///|
pub(all) struct Stmt {
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
  LocalFunction(LocalFunction)
} derive(Show, Eq)

///|
pub fn parse_stmt(
  tokens : ArrayView[Token],
) -> (Stmt, ArrayView[Token]) raise ParseError {
  match tokens {
    [{ kind: Keyword(Let), .. }, { kind: Keyword(Mut), .. }, ..] as tokens => {
      let (let_mut_stmt, rest) = parse_let_mut_stmt(tokens)
      let stmt = Stmt::{ kind: StmtKind::LetMutStmt(let_mut_stmt) }
      (stmt, rest)
    }
    [{ kind: Keyword(Let), .. }, ..] as tokens => {
      let (let_stmt, rest) = parse_let_stmt(tokens)
      let stmt = Stmt::{ kind: StmtKind::LetStmt(let_stmt) }
      (stmt, rest)
    }
    [{ kind: Keyword(Return), .. }, .. tokens] => {
      let (expr, rest) = if tokens is [{ kind: Symbol(";"), .. }, .. tokens] {
        (None, tokens)
      } else {
        let (expr, tokens) = parse_expr(tokens)
        guard tokens is [{ kind: Symbol(";"), .. }, .. tokens] else {
          raise ParseError("Expected ';' after return expression")
        }
        (Some(expr), tokens)
      }
      let stmt = Stmt::{ kind: StmtKind::ReturnStmt(expr) }
      (stmt, rest)
    }
    // Assignment must start with a lower ident
    // but starting with a lower ident does not
    // mean it's an assignment.
    //
    // Hence need to parse a left value first and
    // check if it's followed by an assignment operator.
    [{ kind: Lower(_), .. }, ..] as tokens => {
      let (_, rest) = parse_left_value(tokens)
      if rest is [{ kind: AssignOp(_), .. }, ..] {
        let (assign_stmt, rest) = parse_assign_stmt(tokens)
        let stmt = Stmt::{ kind: StmtKind::AssignStmt(assign_stmt) }
        (stmt, rest)
      } else {
        let (expr, rest) = parse_expr(tokens)
        let stmt = Stmt::{ kind: StmtKind::ExprStmt(expr) }
        let rest = if rest is [{ kind: Symbol(";"), .. }, .. rest] {
          rest
        } else if rest is [{ kind: Bracket('}'), .. }, ..] {
          rest
        } else {
          raise ParseError("Expected ';' after expression statement")
        }
        (stmt, rest)
      }
    }
    [{ kind: Keyword(While), .. }, ..] as tokens => {
      let (while_stmt, rest) = parse_while_stmt(tokens)
      let stmt = Stmt::{ kind: StmtKind::WhileStmt(while_stmt) }
      (stmt, rest)
    }
    [{ kind: Keyword(Fn), .. }, ..] as tokens => {
      let (local_function, rest) = parse_local_function(tokens)
      let stmt = Stmt::{ kind: StmtKind::LocalFunction(local_function) }
      (stmt, rest)
    }
    [] => {
      println("Compiler ICE: Empty Token ArrayView")
      panic()
    }
    tokens => {
      let (expr, rest) = parse_expr(tokens)
      let stmt = Stmt::{ kind: StmtKind::ExprStmt(expr) }
      let rest = if rest is [{ kind: Symbol(";"), .. }, .. rest] {
        rest
      } else if rest is [{ kind: Bracket('}'), .. }, ..] {
        rest
      } else {
        raise ParseError("Expected ';' after expression statement")
      }
      (stmt, rest)
    }
  }
}
