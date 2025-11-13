///|
pub fn Context::match_expr_to_knf(
  self : Context,
  expr : @typecheck.MatchExpr,
) -> (Array[KnfStmt], KnfExpr) raise KnfTransformError {
  match expr.cond.ty {
    Bool => self.match_bool_expr_to_knf(expr)
    Int => self.match_int_expr_to_knf(expr)
    Enum(_) => self.match_enum_expr_to_knf(expr)
    Tuple(_) => self.match_tuple_expr_to_knf(expr)
    ty => raise KnfTransformError(
      "Unsupported match expression type '\{ty}' in KNF transformation",
    )
  }
}

///|
///
/// for `match bool`
///
/// convert to if-else chain
pub fn Context::match_bool_expr_to_knf(
  self : Context,
  expr : @typecheck.MatchExpr,
) -> (Array[KnfStmt], KnfExpr) raise KnfTransformError {
  let match_expr_ty = self.typekind_to_knf(expr.ty)
  let (stmts, cond_expr) = self.expr_to_knf(expr.cond)
  let cond_name = self.expr_to_knf_name(cond_expr, Bool, stmts)

  let mut last_else_block = KnfBlock::{ stmts: [], ty: self.typekind_to_knf(expr.ty) }
  let mut is_last_branch = true

  for match_arm in expr.arms.rev_iter() {
    self.enter_scope()
    let { pattern, match_guard, body, ..} = match_arm
    let branch_stmts : Array[KnfStmt] = Array::new()
    if pattern.kind is Ident(name) {
      let pat_name = self.add_new_name(name, Bool)
      let knf_let = KnfStmt::Let(pat_name, Bool, KnfExpr::Ident(cond_name))
      branch_stmts.push(knf_let)
    }

    let (then_stmts, then_expr) = self.expr_to_knf(body)
    let else_block = last_else_block

    let guard_cond_name: Name? = if match_guard is Some(guard_expr) {
      let (guard_stmts, guard_expr_knf) = self.expr_to_knf(guard_expr)
      branch_stmts.append(guard_stmts)
      let guard_cond_name = self.expr_to_knf_name(guard_expr_knf, Bool, branch_stmts)
      Some(guard_cond_name)
    } else {
      None
    }

    let then_block = match (then_stmts, then_expr) {
      ([], Block(block)) => block
      (_, Block(_)) => raise KnfTransformError(
        "Unexpected block expression in match arm body",
      )
      (stmts, expr) => {
        let last_expr_name = self.expr_to_knf_name(expr, match_expr_ty, stmts)
        stmts.push(ExprStmt(Ident(last_expr_name)))
        KnfBlock::{
          stmts, ty: self.typekind_to_knf(body.ty)
        }
      }
    }
    match pattern.kind {
      _ if is_last_branch => {
        // since we already ensured that all patterns are covered in typecheck phase,
        // we know the last branch must be `else` branch in if-else chain
        // no matter what pattern it is
        let final_stmts = Array::new()
        final_stmts.append(branch_stmts)
        final_stmts.append(then_block.stmts)
        last_else_block = KnfBlock::{
          stmts: final_stmts,
          ty: self.typekind_to_knf(expr.ty),
        }
        is_last_branch = false
      }
      Boolean(b) if guard_cond_name is Some(guard_cond_name) => {
        let condition = match b {
          true => KnfExpr::Binary(And, cond_name, guard_cond_name)
          false => {
            let not_cond_name = self.add_temp(Bool)
            let knf_let = Let(not_cond_name, Bool, Not(cond_name))
            branch_stmts.push(knf_let)
            KnfExpr::Binary(And, not_cond_name, guard_cond_name)
          }
        }
        let if_knf_expr = KnfExpr::If(
          condition,
          then_block,
          else_block,
        )
        branch_stmts.push(ExprStmt(if_knf_expr))
        last_else_block = KnfBlock::{
          stmts: branch_stmts,
          ty: self.typekind_to_knf(expr.ty),
        }
      }
      Boolean(b) => {
        let condition = match b {
          true => KnfExpr::Ident(cond_name)
          false => KnfExpr::Not(cond_name)
        }
        let if_knf_expr = KnfExpr::If(
          condition,
          then_block,
          else_block,
        )
        branch_stmts.push(ExprStmt(if_knf_expr))
        last_else_block = KnfBlock::{
          stmts: branch_stmts,
          ty: self.typekind_to_knf(expr.ty),
        }
      } 
      Wildcard | Ident(_) if match_guard is Some(guard_expr) => {
        let (guard_stmts, guard_expr_knf) = self.expr_to_knf(guard_expr)
        branch_stmts.append(guard_stmts)
        let if_knf_expr = KnfExpr::If(
          guard_expr_knf,
          then_block,
          else_block,
        )
        branch_stmts.push(ExprStmt(if_knf_expr))
        last_else_block = KnfBlock::{
          stmts: branch_stmts,
          ty: self.typekind_to_knf(expr.ty),
        }
      }
      // it will discard the other pattern case, but it's okay
      //
      // for code like:
      //
      // ```mbt skip
      // match expr {
      //    a => { ... }
      //    _ => { ... }  // code of `c` branch will be discarded
      //    c => { ... } 
      // }
      // ```
      Wildcard | Ident(_) => {
        let final_stmts = Array::new()
        final_stmts.append(branch_stmts)
        final_stmts.append(then_block.stmts)
        last_else_block = KnfBlock::{
          stmts: final_stmts,
          ty: self.typekind_to_knf(expr.ty),
        }
      }
      _ =>
        raise KnfTransformError("Non-boolean pattern in match bool expression")
    }
    self.exit_scope()
  }

  match last_else_block.stmts {
    [ExprStmt(knf_expr)] if last_else_block.stmts.length() == 1 => (stmts, knf_expr)
    _ => (stmts, Block(last_else_block))
  }
}

///|
///
/// for `match int`
///
/// convert to switch-case
pub fn Context::match_int_expr_to_knf(
  self : Context,
  _expr : @typecheck.MatchExpr,
) -> (Array[KnfStmt], KnfExpr) raise KnfTransformError {
  ignore(self)
  raise KnfTransformError("Not implemented yet")
}

///|
///
/// for `match enum`
///
/// convert to swicth-case
pub fn Context::match_enum_expr_to_knf(
  self : Context,
  _expr : @typecheck.MatchExpr,
) -> (Array[KnfStmt], KnfExpr) raise KnfTransformError {
  ignore(self)
  raise KnfTransformError("Not implemented yet")
}

///|
///
/// for `match tuple`
///
/// convert to if-else chain
pub fn Context::match_tuple_expr_to_knf(
  self : Context,
  _expr : @typecheck.MatchExpr,
) -> (Array[KnfStmt], KnfExpr) raise KnfTransformError {
  ignore(self)
  raise KnfTransformError("Not implemented yet")
}
