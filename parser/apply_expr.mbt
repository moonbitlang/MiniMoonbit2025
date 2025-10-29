///|
pub(all) struct ApplyExpr {
  kind : ApplyExprKind
} derive(Show, Eq)

///|
pub(all) enum ApplyExprKind {
  AtomExpr(AtomExpr)
  ArrayAccess(ApplyExpr, Expr)
  FieldAccess(ApplyExpr, String)
  Call(ApplyExpr, Array[Expr])
} derive(Show, Eq)

///|
pub fn parse_apply_expr(
  tokens : ArrayView[Token],
) -> (ApplyExpr, ArrayView[Token]) raise ParseError {
  let (atom_expr, tokens) = parse_atom_expr(tokens)
  let apply_expr = ApplyExpr::{ kind: ApplyExprKind::AtomExpr(atom_expr) }
  if !(tokens is [{ kind: Bracket('[') | Symbol(".") | Bracket('('), .. }, ..]) {
    return (apply_expr, tokens)
  }
  let mut apply_expr = apply_expr
  loop tokens {
    [{ kind: Bracket('['), ..  }, .. tokens] => {
      let (index_expr, tokens) = parse_expr(tokens)
      guard tokens is [{ kind: Bracket(']'), .. }, .. tokens] else {
        raise ParseError("Expect ']'")
      }
      apply_expr = ApplyExpr::{
        kind: ApplyExprKind::ArrayAccess(apply_expr, index_expr),
      }
      continue tokens
    }
    [{ kind: Symbol("."), .. }, { kind: Lower(field), .. }, .. tokens] => {
      apply_expr = ApplyExpr::{
        kind: ApplyExprKind::FieldAccess(apply_expr, field),
      }
      continue tokens
    }
    [{ kind: Bracket('('), .. }, .. tokens] => {
      let (args, tokens) = parse_expr_list(tokens)
      guard tokens is [{ kind: Bracket(')'), .. }, .. tokens] else {
        raise ParseError("Expect ')'")
      }
      apply_expr = ApplyExpr::{ kind: ApplyExprKind::Call(apply_expr, args) }
      continue tokens
    }
    tokens => break (apply_expr, tokens)
  }
}
