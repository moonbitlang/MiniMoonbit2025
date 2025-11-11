///|
pub struct MatchExpr {
  cond : Expr
  arms : Array[MatchArm]
  ty : TypeKind
} derive(Show)

///|
pub struct MatchArm {
  pattern : Pattern
  match_guard : Expr?
  body : Expr
} derive(Show)

///|
pub fn Context::check_match_expr(
  self : Context,
  match_expr : @parser.MatchExpr,
) -> MatchExpr {
  let checked_cond = self.check_expr(match_expr.cond)
  let checked_cond_ty = self.ensure_type(checked_cond.ty)
  if checked_cond_ty is TypeVar(_) {
    self.throw_(
      match_expr.cond.toks[0],
      "Cannot match on expression with unresolved type variable",
      Error,
    )
  }
  let checked_arms : Array[MatchArm] = Array::new()
  for arm in match_expr.arms {
    let pattern = try self.from_parser_pattern(arm.pattern) catch {
      err => {
        self.throw_(
          arm.toks[0],
          "Failed to parse pattern in match arm: \{err}",
          Error,
        )
        Pattern::{ kind: Wildcard }
      }
    } noraise {
      pat => pat
    }
    self.bind_pattern_type(pattern, checked_cond.ty) catch {
      err =>
        self.throw_(
          arm.toks[0],
          "Pattern type binding error in match arm: \{err}",
          Error,
        )
    }
    let checked_guard = match arm.match_guard {
      Some(guard_expr) => {
        let guard_ty = self.check_expr(guard_expr)
        let guard_ty_ty = self.ensure_type(guard_ty.ty)
        if !(guard_ty_ty is Bool) {
          self.throw_(
            guard_expr.toks[0],
            "Match arm guard expression must be of type `Bool`",
            Error,
          )
          None
        } else {
          Some(guard_ty)
        }
      }
      None => None
    }
    let checked_body = self.check_expr(arm.body)
    let checked_arm = MatchArm::{
      pattern,
      match_guard: checked_guard,
      body: checked_body,
    }
    checked_arms.push(checked_arm)
  }
  let tykind = if checked_arms.length() == 0 {
    TypeKind::Unit
  } else {
    let arm_types = checked_arms.map(a => a.body.ty)
    for i, arm_ty in arm_types {
      if !self.is_type_compatible(arm_types[0], arm_ty) {
        self.throw_(
          match_expr.arms[i].toks[0],
          "Type mismatch between match arms: expected \{arm_types[0]}, got \{arm_ty}",
          Error,
        )
      }
    }
    self.ensure_type(arm_types[0])
  }
  MatchExpr::{ cond: checked_cond, arms: checked_arms, ty: tykind }
}
