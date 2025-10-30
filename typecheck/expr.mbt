///|
pub(all) struct Expr {
  kind : ExprKind
  ty : TypeKind
} derive(Show)

///|
pub(all) enum ExprKind {
  ApplyExpr(ApplyExpr)
  BlockExpr(BlockExpr)
  NotExpr(Expr)
  NegExpr(Expr)
  BinaryExpr(BinaryOp, Expr, Expr)
  IfExpr(IfExpr)
} derive(Show)

///|
pub(all) enum BinaryOp {
  Add // +
  Sub // -
  Mul // *
  Div // /
  Mod // %
  ShiftLeft // <<
  ShiftRight // >>
  Eq // ==
  NE // !=
  LT // <
  GT // >
  LE // <=
  GE // >=
  And // &&
  Or // ||
  BitAnd // &
  BitOr // |
} derive(Show, Eq)

///|
fn binop_is_cmp(bin_op : BinaryOp) -> Bool {
  match bin_op {
    Eq => true
    NE => true
    LT => true
    GT => true
    LE => true
    GE => true
    _ => false
  }
}

///|
fn binop_is_bitwise(bin_op : BinaryOp) -> Bool {
  bin_op is (BitAnd | BitOr | ShiftLeft | ShiftRight)
}

///|
fn binop_is_logical(bin_op : BinaryOp) -> Bool {
  bin_op is (And | Or)
}

///|
fn binop_is_arithmetic(bin_op : BinaryOp) -> Bool {
  match bin_op {
    Add => true
    Sub => true
    Mul => true
    Div => true
    Mod => true
    _ => false
  }
}

///|
fn parser_binop_to_typecheck_binop(tok_bin_op : @parser.BinaryOp) -> BinaryOp {
  match tok_bin_op {
    Add => Add
    Sub => Sub
    Mul => Mul
    Div => Div
    Mod => Mod
    ShiftLeft => ShiftLeft
    ShiftRight => ShiftRight
    Eq => Eq
    NE => NE
    LT => LT
    GT => GT
    LE => LE
    GE => GE
    And => And
    Or => Or
    BitAnd => BitAnd
    BitOr => BitOr
  }
}

///|
pub fn Context::check_expr(
  self : Self,
  expr : @parser.Expr,
) -> Expr raise TypeCheckError {
  match expr.kind {
    ApplyExpr(apply_expr) => {
      let apply_expr = self.check_apply_expr(apply_expr)
      Expr::{ kind: ApplyExpr(apply_expr), ty: apply_expr.ty }
    }
    NotExpr(inner_expr) => {
      let checked_inner = self.check_expr(inner_expr)
      // Type checking logic for NotExpr
      if self.is_type_compatible(checked_inner.ty, Bool) is false {
        raise TypeCheckError("Operand of 'not' must be of type Bool")
      }
      Expr::{ kind: NotExpr(checked_inner), ty: Bool }
    }
    NegExpr(inner_expr) => {
      let checked_inner = self.check_expr(inner_expr)
      // Type checking logic for NegExpr
      if !(checked_inner.ty is (Int | Double | TypeVar(_))) {
        raise TypeCheckError("Operand of 'neg' must be of type Int or Double")
      }
      Expr::{ kind: NegExpr(checked_inner), ty: checked_inner.ty }
    }
    BinaryExpr(op, left_expr, right_expr) => {
      let checked_left = self.check_expr(left_expr)
      let checked_right = self.check_expr(right_expr)
      let op = parser_binop_to_typecheck_binop(op)
      if binop_is_arithmetic(op) {
        let t = self.is_type_compatible(checked_left.ty, checked_right.ty)
        if t is false {
          raise TypeCheckError(
            "Operands of arithmetic binary operation must be of the same type",
          )
        }
        let ty = self.ensure_type(checked_left.ty)
        // Allow String + String for concatenation
        if op is Add && ty is String {
          let e = Expr::{
            kind: BinaryExpr(op, checked_left, checked_right),
            ty: String,
          }
          return e
        }
        if !(ty is (Int | Double | TypeVar(_))) {
          raise TypeCheckError(
            "Operands of arithmetic binary operation must be of type Int or Double",
          )
        }
        let e = Expr::{
          kind: BinaryExpr(op, checked_left, checked_right),
          ty: checked_left.ty,
        }
        return e
      }
      if binop_is_cmp(op) {
        let t = self.is_type_compatible(checked_left.ty, checked_right.ty)
        if t is false {
          raise TypeCheckError(
            "Operands of comparison binary operation must be of the same type",
          )
        }
        let e = Expr::{
          kind: BinaryExpr(op, checked_left, checked_right),
          ty: Bool,
        }
        return e
      }
      if binop_is_bitwise(op) {
        let t = self.is_type_compatible(checked_left.ty, checked_right.ty)
        if t is false {
          raise TypeCheckError(
            "Operands of bitwise binary operation must be of the same type",
          )
        }
        let ty = self.ensure_type(checked_left.ty)
        if !(ty is (Int | TypeVar(_))) {
          raise TypeCheckError(
            "Operands of bitwise binary operation must be of type Int",
          )
        }
        let e = Expr::{
          kind: BinaryExpr(op, checked_left, checked_right),
          ty: checked_left.ty,
        }
        return e
      }
      if binop_is_logical(op) {
        if !(self.is_type_compatible(checked_left.ty, Bool) &&
          self.is_type_compatible(checked_right.ty, Bool)) {
          raise TypeCheckError(
            "Operands of logical binary operation must be of type Bool",
          )
        }
        let e = Expr::{
          kind: BinaryExpr(op, checked_left, checked_right),
          ty: Bool,
        }
        return e
      }
      raise TypeCheckError("Unsupported binary operation: \{op}")
    }
    BlockExpr(block_expr) => {
      let checked_block_expr = self.check_block_expr(block_expr)
      Expr::{ kind: BlockExpr(checked_block_expr), ty: checked_block_expr.ty }
    }
    IfExpr(if_expr) => {
      let checked_if_expr = self.check_if_expr(if_expr)
      Expr::{ kind: IfExpr(checked_if_expr), ty: checked_if_expr.ty }
    }
  }
}
