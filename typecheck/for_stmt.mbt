///|
pub(all) struct ForStmt {
  inits : Array[(String, Expr)]
  cond : Expr // if parser cond is None, this is Bool::true
  steps : Array[(String, AssignOp, Expr)]
  body : BlockExpr
} derive(Show)

///|
pub fn Context::check_for_stmt(
  self : Context,
  for_stmt : @parser.ForStmt,
) -> ForStmt raise TypeCheckError {
  // Enter a new scope for the for loop
  self.enter_scope()

  // Check and bind init variables (they are mutable)
  let checked_inits : Array[(String, Expr)] = Array::new()
  for init in for_stmt.inits {
    let (name, init_expr) = init
    let checked_expr = self.check_expr(init_expr)
    let type_kind = self.ensure_type(checked_expr.ty)
    let ty = Type::{ kind: type_kind, mutable: true }
    self.type_env.set(name, ty)
    checked_inits.push((name, checked_expr))
  }

  // Check condition expression (if exists, must be Bool)
  let checked_cond = if for_stmt.cond is Some(cond_expr) {
    let checked = self.check_expr(cond_expr)
    if !(checked.ty is Bool) {
      raise TypeCheckError("For loop condition must be of boolean type")
    }
    checked
  } else {
    // If no condition, use Bool::true
    Expr::{
      kind: ExprKind::ApplyExpr(ApplyExpr::{
        kind: ApplyExprKind::AtomExpr(AtomExpr::{
          kind: AtomExprKind::Bool(true),
          ty: Bool,
          toks: [],
        }),
        ty: Bool,
        toks: [],
      }),
      ty: Bool,
      toks: [],
    }
  }

  // Check step statements
  let checked_steps : Array[(String, AssignOp, Expr)] = Array::new()
  for step in for_stmt.steps {
    let (name, op, step_expr) = step
    // Verify the variable exists in the current scope
    guard self.type_env.get(name) is Some(var_ty) else {
      raise TypeCheckError("Undefined variable in for loop step: \{name}")
    }
    guard var_ty.mutable is true else {
      raise TypeCheckError(
        "Cannot assign to immutable variable in for loop step: \{name}",
      )
    }
    let checked_expr = self.check_expr(step_expr)
    guard self.is_type_compatible(var_ty.kind, checked_expr.ty) else {
      raise TypeCheckError(
        "Type mismatch in for loop step assignment, variable type: \{var_ty.kind}, expression type: \{checked_expr.ty}",
      )
    }
    let typed_op = AssignOp::from_parser_assign_op(op)
    let ty = self.ensure_type(var_ty.kind)
    if !(typed_op is Assign) && !(ty is (Int | Double)) {
      raise TypeCheckError(
        "Compound assignment operators in for loop can only be used with Int or Double types",
      )
    }
    checked_steps.push((name, typed_op, checked_expr))
  }

  // Check body block
  let checked_body = self.check_block_expr(for_stmt.body)

  // Exit the scope
  self.exit_scope()
  ForStmt::{
    inits: checked_inits,
    cond: checked_cond,
    steps: checked_steps,
    body: checked_body,
  }
}
