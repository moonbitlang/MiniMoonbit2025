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
  expr : @typecheck.MatchExpr,
) -> (Array[KnfStmt], KnfExpr) raise KnfTransformError {
  let match_expr_ty = self.typekind_to_knf(expr.ty)
  let (stmts, cond_expr) = self.expr_to_knf(expr.cond)
  let cond_name = self.expr_to_knf_name(cond_expr, Int, stmts)
  
  let cases : Array[(Int, KnfBlock)] = []
  let default_arms : Array[@typecheck.MatchArm] = []
  let cases_map : Map[Int, Array[@typecheck.MatchArm]] = Map::new()
  
  for arm in expr.arms {
    match arm.pattern.kind {
      Integer(n) => {
        match cases_map.get(n) {
          Some(existing) => existing.push(arm)
          None => {
            let arr = Array::new()
            arr.push(arm)
            cases_map.set(n, arr)
          }
        }
      }
      Wildcard | Ident(_) => {
        // We do not only have one default arm, since we may have guards on default arms
        default_arms.push(arm)
      }
      _ => raise KnfTransformError("Non-integer pattern in match int expression")
    }
  }
  
  for entry in cases_map {
    let (int_value, arms) = entry
    let case_block = self.build_int_case_block(arms, match_expr_ty)
    cases.push((int_value, case_block))
  }
  
  let default_block = if default_arms.is_empty() {
    raise KnfTransformError(
      "Non-exhaustive patterns in match int expression: missing default case",
    )
  } else {
    self.build_default_arms_block(default_arms, cond_name, match_expr_ty)
  }
  
  (stmts, Switch(cond_name, cases, default_block))
}

///| 
fn Context::build_int_case_block(
  self : Context,
  arms : Array[@typecheck.MatchArm],
  result_ty : Type,
) -> KnfBlock raise KnfTransformError {
  let mut current_else_block : KnfBlock? = None
  
  for arm in arms.rev_iter() {
    self.enter_scope()
    
    let (body_stmts, body_expr) = self.expr_to_knf(arm.body)
    
    let then_block_stmts = Array::new()
    then_block_stmts.append(body_stmts)
    then_block_stmts.push(ExprStmt(body_expr))
    let then_block = KnfBlock::{ stmts: then_block_stmts, ty: result_ty }
    
    if arm.match_guard is Some(guard_expr) {
      let (guard_stmts, guard_knf) = self.expr_to_knf(guard_expr)
      let guard_name = self.expr_to_knf_name(guard_knf, Bool, guard_stmts)
      
      let else_block = match current_else_block {
        Some(blk) => blk
        None => KnfBlock::{ stmts: [], ty: result_ty }
      }
      
      let case_stmts = {
        let arr = guard_stmts
        arr.push(ExprStmt(KnfExpr::If(
          KnfExpr::Ident(guard_name),
          then_block,
          else_block,
        )))
        arr
      }
      
      current_else_block = Some(KnfBlock::{ stmts: case_stmts, ty: result_ty })
    } else {
      current_else_block = Some(then_block)
    }
    
    self.exit_scope()
  }
  
  match current_else_block {
    Some(block) => block
    None => KnfBlock::{ stmts: [], ty: result_ty }
  }
}

///|
fn Context::build_default_arms_block(
  self : Context,
  arms : Array[@typecheck.MatchArm],
  cond_name : Name,
  result_ty : Type,
) -> KnfBlock raise KnfTransformError {
  let mut current_else_block : KnfBlock? = None
  
  for arm in arms.rev_iter() {
    self.enter_scope()
    
    let branch_stmts : Array[KnfStmt] = Array::new()
    
    if arm.pattern.kind is Ident(name) {
      let pat_name = self.add_new_name(name, Int)
      branch_stmts.push(Let(pat_name, Int, KnfExpr::Ident(cond_name)))
    }
    
    let guard_name_opt = match arm.match_guard {
      Some(guard_expr) => {
        let (guard_stmts, guard_knf) = self.expr_to_knf(guard_expr)
        branch_stmts.append(guard_stmts)
        let guard_name = self.expr_to_knf_name(guard_knf, Bool, branch_stmts)
        Some(guard_name)
      }
      None => None
    }
    
    let (body_stmts, body_expr) = self.expr_to_knf(arm.body)
    
    self.exit_scope()
    let then_block_stmts = Array::new()
    then_block_stmts.append(body_stmts)
    then_block_stmts.push(ExprStmt(body_expr))
    let then_block = KnfBlock::{ stmts: then_block_stmts, ty: result_ty }
    
    let else_block = match current_else_block {
      Some(blk) => blk
      None => KnfBlock::{ stmts: [], ty: result_ty }
    }
    
    match guard_name_opt {
      Some(guard_name) => {
        branch_stmts.push(ExprStmt(KnfExpr::If(
          KnfExpr::Ident(guard_name),
          then_block,
          else_block,
        )))
        current_else_block = Some(KnfBlock::{ stmts: branch_stmts, ty: result_ty })
      }
      None => {
        branch_stmts.append(then_block.stmts)
        current_else_block = Some(KnfBlock::{ stmts: branch_stmts, ty: result_ty })
      }
    }
  }
  
  match current_else_block {
    Some(block) => block
    None => KnfBlock::{ stmts: [], ty: result_ty }
  }
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
