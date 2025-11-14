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
    ty =>
      raise KnfTransformError(
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
  let mut last_else_block = KnfBlock::{
    stmts: [],
    ty: self.typekind_to_knf(expr.ty),
  }
  let mut is_last_branch = true
  for match_arm in expr.arms.rev_iter() {
    self.enter_scope()
    let { pattern, match_guard, body, .. } = match_arm
    let branch_stmts : Array[KnfStmt] = Array::new()
    if pattern.kind is Ident(name) {
      let pat_name = self.add_new_name(name, Bool)
      let knf_let = KnfStmt::Let(pat_name, Bool, KnfExpr::Ident(cond_name))
      branch_stmts.push(knf_let)
    }
    let (then_stmts, then_expr) = self.expr_to_knf(body)
    let else_block = last_else_block
    let guard_cond_name : Name? = if match_guard is Some(guard_expr) {
      let (guard_stmts, guard_expr_knf) = self.expr_to_knf(guard_expr)
      branch_stmts.append(guard_stmts)
      let guard_cond_name = self.expr_to_knf_name(
        guard_expr_knf,
        Bool,
        branch_stmts,
      )
      Some(guard_cond_name)
    } else {
      None
    }
    let then_block = match (then_stmts, then_expr) {
      ([], Block(block)) => block
      (_, Block(_)) =>
        raise KnfTransformError("Unexpected block expression in match arm body")
      (stmts, expr) => {
        let last_expr_name = self.expr_to_knf_name(expr, match_expr_ty, stmts)
        stmts.push(ExprStmt(Ident(last_expr_name)))
        KnfBlock::{ stmts, ty: self.typekind_to_knf(body.ty) }
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
        let if_knf_expr = KnfExpr::If(condition, then_block, else_block)
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
        let if_knf_expr = KnfExpr::If(condition, then_block, else_block)
        branch_stmts.push(ExprStmt(if_knf_expr))
        last_else_block = KnfBlock::{
          stmts: branch_stmts,
          ty: self.typekind_to_knf(expr.ty),
        }
      }
      Wildcard | Ident(_) if match_guard is Some(guard_expr) => {
        let (guard_stmts, guard_expr_knf) = self.expr_to_knf(guard_expr)
        branch_stmts.append(guard_stmts)
        let if_knf_expr = KnfExpr::If(guard_expr_knf, then_block, else_block)
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
    [ExprStmt(knf_expr)] if last_else_block.stmts.length() == 1 =>
      (stmts, knf_expr)
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
      Integer(n) =>
        match cases_map.get(n) {
          Some(existing) => existing.push(arm)
          None => {
            let arr = Array::new()
            arr.push(arm)
            cases_map.set(n, arr)
          }
        }
      Wildcard | Ident(_) =>
        // We do not only have one default arm, since we may have guards on default arms
        default_arms.push(arm)
      _ =>
        raise KnfTransformError("Non-integer pattern in match int expression")
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
        arr.push(
          ExprStmt(
            KnfExpr::If(KnfExpr::Ident(guard_name), then_block, else_block),
          ),
        )
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
        branch_stmts.push(
          ExprStmt(
            KnfExpr::If(KnfExpr::Ident(guard_name), then_block, else_block),
          ),
        )
        current_else_block = Some(KnfBlock::{
          stmts: branch_stmts,
          ty: result_ty,
        })
      }
      None => {
        branch_stmts.append(then_block.stmts)
        current_else_block = Some(KnfBlock::{
          stmts: branch_stmts,
          ty: result_ty,
        })
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
  expr : @typecheck.MatchExpr,
) -> (Array[KnfStmt], KnfExpr) raise KnfTransformError {
  let match_expr_ty = self.typekind_to_knf(expr.ty)
  let (stmts, cond_expr) = self.expr_to_knf(expr.cond)

  // Get the enum type info
  guard expr.cond.ty is Enum(enum_name) else {
    raise KnfTransformError(
      "Expected enum type in match enum expression, got \{expr.cond.ty}",
    )
  }

  // Store the enum value in a temp variable
  let enum_value_name = self.expr_to_knf_name(
    cond_expr,
    self.typekind_to_knf(expr.cond.ty),
    stmts,
  )

  // Get the tag of the enum value
  let tag_name = self.add_temp(Int)
  stmts.push(Let(tag_name, Int, GetUnionTag(enum_value_name)))

  // Group arms by variant
  let cases_map : Map[String, Array[@typecheck.MatchArm]] = Map::new()
  let default_arms : Array[@typecheck.MatchArm] = []
  for arm in expr.arms {
    match arm.pattern.kind {
      EnumVariant(_, variant_name, _) =>
        match cases_map.get(variant_name) {
          Some(existing) => existing.push(arm)
          None => {
            let arr = Array::new()
            arr.push(arm)
            cases_map.set(variant_name, arr)
          }
        }
      Wildcard | Ident(_) => default_arms.push(arm)
      _ => raise KnfTransformError("Non-enum pattern in match enum expression")
    }
  }

  // Build switch cases
  let cases : Array[(Int, KnfBlock)] = []
  guard self.unions.get(enum_name) is Some(variant_names) else {
    raise KnfTransformError("Enum \{enum_name} not found in unions")
  }
  for i, variant_full_name in variant_names {
    // Extract variant name from "EnumName$VariantName"
    let parts = variant_full_name.split("$").collect()
    let variant_name = if parts.length() == 2 {
      parts[1].to_string()
    } else {
      raise KnfTransformError(
        "Invalid variant name format: \{variant_full_name}",
      )
    }
    match cases_map.get(variant_name) {
      Some(arms) => {
        let case_block = self.build_enum_case_block(
          arms, enum_name, variant_name, variant_full_name, enum_value_name, match_expr_ty,
        )
        cases.push((i, case_block))
      }
      None => ()
    }
  }

  // Build default block
  let default_block = if default_arms.is_empty() {
    // If all variants are covered in cases, create an empty default block
    // The type checker should have already verified exhaustiveness
    KnfBlock::{ stmts: [], ty: match_expr_ty }
  } else {
    self.build_default_arms_block(default_arms, enum_value_name, match_expr_ty)
  }
  (stmts, Switch(tag_name, cases, default_block))
}

///|
fn Context::build_enum_case_block(
  self : Context,
  arms : Array[@typecheck.MatchArm],
  _enum_name : String,
  _variant_name : String,
  variant_full_name : String,
  enum_value_name : Name,
  result_ty : Type,
) -> KnfBlock raise KnfTransformError {
  let mut current_else_block : KnfBlock? = None
  for arm in arms.rev_iter() {
    self.enter_scope()
    let branch_stmts : Array[KnfStmt] = Array::new()

    // Extract pattern info
    let sub_patterns = match arm.pattern.kind {
      EnumVariant(_tag, _vname, subs) => subs
      _ => raise KnfTransformError("Expected enum variant pattern in enum case")
    }

    // Reinterpret the enum value as the specific variant struct
    let variant_struct_name = self.add_temp(Struct(variant_full_name))
    branch_stmts.push(
      Let(
        variant_struct_name,
        Struct(variant_full_name),
        ReInterpretUnion(variant_full_name, enum_value_name),
      ),
    )

    // Build pattern matching condition and bindings for sub-patterns
    let (pattern_cond_opt, bindings) = self.build_enum_pattern_condition(
      sub_patterns, variant_struct_name, variant_full_name,
    )

    // Apply bindings
    branch_stmts.append(bindings)

    // Process guard if exists
    let guard_cond_opt = match arm.match_guard {
      Some(guard_expr) => {
        let (guard_stmts, guard_knf) = self.expr_to_knf(guard_expr)
        branch_stmts.append(guard_stmts)
        let guard_name = self.expr_to_knf_name(guard_knf, Bool, branch_stmts)
        Some(guard_name)
      }
      None => None
    }

    // Build then block (arm body)
    let (body_stmts, body_expr) = self.expr_to_knf(arm.body)
    let then_block_stmts = Array::new()
    then_block_stmts.append(body_stmts)
    then_block_stmts.push(ExprStmt(body_expr))
    let then_block = KnfBlock::{ stmts: then_block_stmts, ty: result_ty }
    let else_block = match current_else_block {
      Some(blk) => blk
      None => KnfBlock::{ stmts: [], ty: result_ty }
    }

    // Combine pattern condition and guard
    match (pattern_cond_opt, guard_cond_opt) {
      (Some(pat_cond), Some(guard_cond)) => {
        let combined_cond = Binary(And, pat_cond, guard_cond)
        branch_stmts.push(ExprStmt(If(combined_cond, then_block, else_block)))
        current_else_block = Some(KnfBlock::{
          stmts: branch_stmts,
          ty: result_ty,
        })
      }
      (Some(pat_cond), None) => {
        branch_stmts.push(ExprStmt(If(Ident(pat_cond), then_block, else_block)))
        current_else_block = Some(KnfBlock::{
          stmts: branch_stmts,
          ty: result_ty,
        })
      }
      (None, Some(guard_cond)) => {
        branch_stmts.push(
          ExprStmt(If(Ident(guard_cond), then_block, else_block)),
        )
        current_else_block = Some(KnfBlock::{
          stmts: branch_stmts,
          ty: result_ty,
        })
      }
      (None, None) => {
        branch_stmts.append(then_block.stmts)
        current_else_block = Some(KnfBlock::{
          stmts: branch_stmts,
          ty: result_ty,
        })
      }
    }
    self.exit_scope()
  }
  match current_else_block {
    Some(block) => block
    None => KnfBlock::{ stmts: [], ty: result_ty }
  }
}

///|
/// Build condition and bindings for enum variant sub-patterns
/// Returns (condition_name?, bindings)
fn Context::build_enum_pattern_condition(
  self : Context,
  sub_patterns : Array[@typecheck.Pattern],
  variant_struct_name : Name,
  variant_full_name : String,
) -> (Name?, Array[KnfStmt]) raise KnfTransformError {
  let stmts : Array[KnfStmt] = []
  let bindings : Array[KnfStmt] = []
  let conditions : Array[Name] = []

  // Get struct definition to determine field types
  guard self.struct_defs.get(variant_full_name) is Some(struct_def) else {
    raise KnfTransformError(
      "Struct definition not found for variant: \{variant_full_name}",
    )
  }
  for i, sub_pat in sub_patterns {
    let field_name = "$\{i}"

    // Get field type from struct definition (skip tag field at index 0)
    let field_ty = match struct_def.fields.get(i + 1) {
      Some((_, _, ty)) => ty
      None =>
        raise KnfTransformError(
          "Field \{field_name} not found in struct \{variant_full_name}",
        )
    }
    match sub_pat.kind {
      Wildcard => continue // No condition or binding
      Ident(var_name) => {
        // Bind variable to the field
        let new_name = self.add_new_name(var_name, field_ty)
        bindings.push(
          Let(new_name, field_ty, FieldAccess(variant_struct_name, field_name)),
        )
      }
      Boolean(b) => {
        // Extract field and check equality
        let field_val_name = self.add_temp(field_ty)
        stmts.push(
          Let(
            field_val_name,
            field_ty,
            FieldAccess(variant_struct_name, field_name),
          ),
        )
        let bool_val_name = self.add_temp(Type::Bool)
        stmts.push(Let(bool_val_name, Type::Bool, KnfExpr::Bool(b)))
        let cond_name = self.add_temp(Type::Bool)
        stmts.push(
          Let(cond_name, Type::Bool, Binary(Eq, field_val_name, bool_val_name)),
        )
        conditions.push(cond_name)
      }
      Integer(n) => {
        // Extract field and check equality
        let field_val_name = self.add_temp(field_ty)
        stmts.push(
          Let(
            field_val_name,
            field_ty,
            FieldAccess(variant_struct_name, field_name),
          ),
        )
        let int_val_name = self.add_temp(Type::Int)
        stmts.push(Let(int_val_name, Type::Int, KnfExpr::Int(n)))
        let cond_name = self.add_temp(Type::Bool)
        stmts.push(
          Let(cond_name, Type::Bool, Binary(Eq, field_val_name, int_val_name)),
        )
        conditions.push(cond_name)
      }
      _ =>
        raise KnfTransformError(
          "Unsupported sub-pattern in enum match: \{sub_pat.kind}",
        )
    }
  }

  // Combine all conditions with AND
  let final_cond = if conditions.is_empty() {
    None
  } else if conditions.length() == 1 {
    Some(conditions[0])
  } else {
    let mut result = conditions[0]
    for i = 1; i < conditions.length(); i = i + 1 {
      let and_result = self.add_temp(Type::Bool)
      stmts.push(
        Let(and_result, Type::Bool, Binary(And, result, conditions[i])),
      )
      result = and_result
    }
    Some(result)
  }

  // Merge stmts (conditions) and bindings together
  let all_stmts = Array::new()
  all_stmts.append(stmts)
  all_stmts.append(bindings)
  (final_cond, all_stmts)
}

///|
///
/// for `match tuple`
///
/// convert to if-else chain
pub fn Context::match_tuple_expr_to_knf(
  self : Context,
  expr : @typecheck.MatchExpr,
) -> (Array[KnfStmt], KnfExpr) raise KnfTransformError {
  let match_expr_ty = self.typekind_to_knf(expr.ty)
  let (stmts, cond_expr) = self.expr_to_knf(expr.cond)

  // Extract tuple types
  let tuple_types = match expr.cond.ty {
    Tuple(types) => types.map(fn(t) { self.typekind_to_knf(t) })
    _ =>
      raise KnfTransformError("Expected tuple type in match tuple expression")
  }

  // Get tuple element names - avoid constructing tuple if possible
  let tuple_elem_names : Array[Name] = match cond_expr {
    TupleLiteral(names) => names // Direct use, no malloc
    _ => {
      // Need to store tuple and access elements
      let tuple_ty = Tuple(tuple_types)
      let tuple_name = self.add_temp(tuple_ty)
      stmts.push(Let(tuple_name, tuple_ty, cond_expr))

      // Extract each element using TupleAccess
      let elem_names : Array[Name] = []
      for i = 0; i < tuple_types.length(); i = i + 1 {
        let elem_name = self.add_temp(tuple_types[i])
        stmts.push(Let(elem_name, tuple_types[i], TupleAccess(tuple_name, i)))
        elem_names.push(elem_name)
      }
      elem_names
    }
  }

  // Build if-else chain for all arms
  let mut last_else_block = KnfBlock::{ stmts: [], ty: match_expr_ty }
  let mut is_last_branch = true
  for match_arm in expr.arms.rev_iter() {
    self.enter_scope()
    let { pattern, match_guard, body, .. } = match_arm

    // Build condition and bindings for this branch
    let (cond_stmts, cond_expr_opt, bindings) = self.build_tuple_pattern_condition(
      pattern, tuple_elem_names, tuple_types,
    )

    // Apply bindings first (before guard evaluation)
    cond_stmts.append(bindings)

    // Process guard if exists (after bindings are available)
    let guard_cond_opt = match match_guard {
      Some(guard_expr) => {
        let (guard_stmts, guard_knf) = self.expr_to_knf(guard_expr)
        cond_stmts.append(guard_stmts)
        let guard_name = self.expr_to_knf_name(guard_knf, Bool, cond_stmts)
        Some(guard_name)
      }
      None => None
    }

    // Build then block
    let (body_stmts, body_expr) = self.expr_to_knf(body)
    let then_block_stmts = Array::new()
    then_block_stmts.append(body_stmts)
    then_block_stmts.push(ExprStmt(body_expr))
    let then_block = KnfBlock::{ stmts: then_block_stmts, ty: match_expr_ty }
    let else_block = last_else_block
    match (is_last_branch, cond_expr_opt, guard_cond_opt) {
      // Last branch (catch-all)
      (true, _, _) => {
        let final_stmts = Array::new()
        final_stmts.append(cond_stmts)
        final_stmts.append(then_block.stmts)
        last_else_block = KnfBlock::{ stmts: final_stmts, ty: match_expr_ty }
        is_last_branch = false
      }
      // Pattern with guard
      (false, Some(cond_name), Some(guard_name)) => {
        let combined_cond = Binary(And, cond_name, guard_name)
        cond_stmts.push(ExprStmt(If(combined_cond, then_block, else_block)))
        last_else_block = KnfBlock::{ stmts: cond_stmts, ty: match_expr_ty }
      }
      // Only pattern condition
      (false, Some(cond_name), None) => {
        cond_stmts.push(ExprStmt(If(Ident(cond_name), then_block, else_block)))
        last_else_block = KnfBlock::{ stmts: cond_stmts, ty: match_expr_ty }
      }
      // Wildcard/Ident with guard
      (false, None, Some(guard_name)) => {
        cond_stmts.push(ExprStmt(If(Ident(guard_name), then_block, else_block)))
        last_else_block = KnfBlock::{ stmts: cond_stmts, ty: match_expr_ty }
      }
      // Wildcard/Ident without guard (should be caught as last branch)
      (false, None, None) => {
        let final_stmts = Array::new()
        final_stmts.append(cond_stmts)
        final_stmts.append(then_block.stmts)
        last_else_block = KnfBlock::{ stmts: final_stmts, ty: match_expr_ty }
      }
    }
    self.exit_scope()
  }

  // Unwrap unnecessary block wrapper
  match last_else_block.stmts {
    // If the block contains only a single expression statement, return it directly
    [ExprStmt(knf_expr)] if last_else_block.stmts.length() == 1 =>
      (stmts, knf_expr)
    // Otherwise, try to flatten by moving non-expression stmts out
    _ => {
      let block_stmts = last_else_block.stmts
      if block_stmts.is_empty() {
        (stmts, KnfExpr::Unit)
      } else {
        // Check if the last statement is an ExprStmt that can be extracted
        let last_idx = block_stmts.length() - 1
        match block_stmts[last_idx] {
          ExprStmt(expr) => {
            // Move all non-last statements to outer stmts
            for i = 0; i < last_idx; i = i + 1 {
              stmts.push(block_stmts[i])
            }
            (stmts, expr)
          }
          _ => (stmts, Block(last_else_block))
        }
      }
    }
  }
}

///|
/// Build condition and bindings for a tuple pattern
/// Returns (stmts, condition_name?, bindings)
fn Context::build_tuple_pattern_condition(
  self : Context,
  pattern : @typecheck.Pattern,
  elem_names : Array[Name],
  elem_types : Array[Type],
) -> (Array[KnfStmt], Name?, Array[KnfStmt]) raise KnfTransformError {
  let stmts : Array[KnfStmt] = []
  let bindings : Array[KnfStmt] = []
  match pattern.kind {
    Wildcard => (stmts, None, bindings)
    Ident(name) => {
      // Bind the entire tuple (reconstructed from elements)
      let tuple_ty = Tuple(elem_types)
      let pat_name = self.add_new_name(name, tuple_ty)
      bindings.push(Let(pat_name, tuple_ty, TupleLiteral(elem_names)))
      (stmts, None, bindings)
    }
    Tuple(sub_patterns) => {
      guard sub_patterns.length() == elem_names.length() else {
        raise KnfTransformError("Tuple pattern length mismatch")
      }
      let conditions : Array[Name] = []
      for i = 0; i < sub_patterns.length(); i = i + 1 {
        let sub_pat = sub_patterns[i]
        let elem_name = elem_names[i]
        let elem_ty = elem_types[i]
        match sub_pat.kind {
          Wildcard => continue // No condition or binding
          Ident(var_name) => {
            // Bind variable
            let new_name = self.add_new_name(var_name, elem_ty)
            bindings.push(Let(new_name, elem_ty, Ident(elem_name)))
          }
          Boolean(b) => {
            // Check equality: elem_name == b
            let bool_val_name = self.add_temp(Bool)
            stmts.push(Let(bool_val_name, Bool, KnfExpr::Bool(b)))
            let cond_name = self.add_temp(Bool)
            stmts.push(
              Let(cond_name, Bool, Binary(Eq, elem_name, bool_val_name)),
            )
            conditions.push(cond_name)
          }
          Integer(n) => {
            // Check equality: elem_name == n
            let int_val_name = self.add_temp(Int)
            stmts.push(Let(int_val_name, Int, KnfExpr::Int(n)))
            let cond_name = self.add_temp(Bool)
            stmts.push(
              Let(cond_name, Bool, Binary(Eq, elem_name, int_val_name)),
            )
            conditions.push(cond_name)
          }
          Tuple(_) => {
            // Nested tuple pattern - need to unbox first
            let (nested_stmts, nested_cond_opt, nested_bindings) = match
              elem_ty {
              Tuple(nested_types) => {
                // Unbox nested tuple
                let nested_elem_names : Array[Name] = []
                for j = 0; j < nested_types.length(); j = j + 1 {
                  let nested_name = self.add_temp(nested_types[j])
                  stmts.push(
                    Let(nested_name, nested_types[j], TupleAccess(elem_name, j)),
                  )
                  nested_elem_names.push(nested_name)
                }
                self.build_tuple_pattern_condition(
                  sub_pat, nested_elem_names, nested_types,
                )
              }
              _ =>
                raise KnfTransformError("Type mismatch in nested tuple pattern")
            }
            stmts.append(nested_stmts)
            if nested_cond_opt is Some(cond) {
              conditions.push(cond)
            }
            bindings.append(nested_bindings)
          }
          _ =>
            raise KnfTransformError(
              "Unsupported pattern kind in tuple match: \{sub_pat.kind}",
            )
        }
      }

      // Combine all conditions with AND
      let final_cond = if conditions.is_empty() {
        None
      } else if conditions.length() == 1 {
        Some(conditions[0])
      } else {
        let mut result = conditions[0]
        for i = 1; i < conditions.length(); i = i + 1 {
          let and_result = self.add_temp(Bool)
          stmts.push(Let(and_result, Bool, Binary(And, result, conditions[i])))
          result = and_result
        }
        Some(result)
      }
      (stmts, final_cond, bindings)
    }
    _ =>
      raise KnfTransformError(
        "Unsupported pattern in tuple match: \{pattern.kind}",
      )
  }
}
