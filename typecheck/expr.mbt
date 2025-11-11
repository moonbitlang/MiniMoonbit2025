///|
pub(all) struct Expr {
  kind : ExprKind
  ty : TypeKind
  toks: ArrayView[Token]
} derive(Show)

///|
pub(all) enum ExprKind {
  ApplyExpr(ApplyExpr)
  BlockExpr(BlockExpr)
  NotExpr(Expr)
  NegExpr(Expr)
  BinaryExpr(BinaryOp, Expr, Expr)
  IfExpr(IfExpr)
  MatchExpr(MatchExpr)
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
fn binop_is_shift(bin_op : BinaryOp) -> Bool {
  bin_op is (ShiftLeft | ShiftRight)
}

///|
fn binop_is_bitandor(bin_op : BinaryOp) -> Bool {
  bin_op is (BitAnd | BitOr)
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
) -> Expr {
  match expr.kind {
    ApplyExpr(apply_expr) => {
      let apply_expr = self.check_apply_expr(apply_expr)
      Expr::{ kind: ApplyExpr(apply_expr), ty: apply_expr.ty, toks: expr.toks  }
    }
    NotExpr(inner_expr) => {
      let checked_inner = self.check_expr(inner_expr)
      // Type checking logic for NotExpr
      if self.is_type_compatible(checked_inner.ty, Bool) is false {
        let msg = "Operand of 'not' must be of type Bool"+
         " while got \{checked_inner.ty}"
        self.throw_(
          expr.toks[0],
          msg,
          Error,
        )
      }
      Expr::{ kind: NotExpr(checked_inner), ty: Bool, toks: expr.toks  }
    }
    NegExpr(inner_expr) => {
      let checked_inner = self.check_expr(inner_expr)
      // Type checking logic for NegExpr
      if !(checked_inner.ty is (Int | Int64 | Double | Float | TypeVar(_))) {
        let msg = "Operand of 'neg' must be of type Int, Int64, Double, or Float"+
         " while got \{checked_inner.ty}"
        self.throw_(
          expr.toks[0],
          msg,
          Error,
        )
      }
      Expr::{ kind: NegExpr(checked_inner), ty: checked_inner.ty, toks: expr.toks  }
    }
    BinaryExpr(op, left_expr, right_expr) => {
      let checked_left = self.check_expr(left_expr)
      let checked_right = self.check_expr(right_expr)
      let op = parser_binop_to_typecheck_binop(op)
      if binop_is_arithmetic(op) {
        let t = self.is_type_compatible(checked_left.ty, checked_right.ty)
        if t is false {
          let msg = "TypeMismatch: Binary Expression Must have same type for both side" + 
           " while got \{checked_left.ty} and \{checked_right.ty}"
          self.throw_(
            expr.toks[0],
            msg,
            Error,
          )
        }
        let ty = self.ensure_type(checked_left.ty)
        // Allow String + String for concatenation
        if op is Add && ty is String {
          let e = Expr::{
            kind: BinaryExpr(op, checked_left, checked_right),
            ty: String, toks: expr.toks 
          }
          return e
        }
        if !(ty is (Int | Int64 | UInt | UInt64 | Double | Float | TypeVar(_))) {
          let msg = if op is Add {
            "TypeMismatch: both side of + Must Be Int, Int64, UInt, UInt64, Double, Float, or String, while got \{ty}"
          } else {
            "TypeMismatch: both side of \{op} Must Be Int, Int64, UInt, UInt64, Double, or Float, while got \{ty}"
          }
          self.throw_(
            expr.toks[0],
            msg,
            Error,
          )
        }
        let e = Expr::{
          kind: BinaryExpr(op, checked_left, checked_right),
          ty: checked_left.ty, toks: expr.toks
        }
        return e
      }
      if binop_is_cmp(op) {
        let t = self.is_type_compatible(checked_left.ty, checked_right.ty)
        if t is false {
          let msg = "Operands of comparison binary operation must be of the same type"+
           " while got \{checked_left.ty} and \{checked_right.ty}"
          self.throw_(
            expr.toks[0],
            msg,
            Error,
          )
        }
        let e = Expr::{
          kind: BinaryExpr(op, checked_left, checked_right),
          ty: Bool, toks: expr.toks
        }
        return e
      }
      if binop_is_shift(op) {
        // Shift operations: left operand can be Int, Int64, UInt, or UInt64, right operand must be Int
        let left_ty = self.ensure_type(checked_left.ty)
        if !(left_ty is (Int | Int64 | UInt | UInt64 | TypeVar(_))) {
          let msg = "Left operand of shift operation must be of type Int, Int64, UInt, or UInt64"+
           " while got \{left_ty}"
          self.throw_(
            expr.toks[0],
            msg,
            Error,
          )
        }
        let right_ty = self.ensure_type(checked_right.ty)
        if !(right_ty is (Int | TypeVar(_))) {
          let msg = "Right operand of shift operation must be of type Int"+
           " while got \{right_ty}"
          self.throw_(
            expr.toks[0],
            msg,
            Error,
          )
        }
        let e = Expr::{
          kind: BinaryExpr(op, checked_left, checked_right),
          ty: checked_left.ty, toks: expr.toks
        }
        return e
      }
      if binop_is_bitandor(op) {
        // Bitwise AND/OR: both operands must be of the same type
        let t = self.is_type_compatible(checked_left.ty, checked_right.ty)
        if t is false {
          let msg = "Operands of bitwise AND/OR operation must be of the same type"+
           " while got \{checked_left.ty} and \{checked_right.ty}"
          self.throw_(
            expr.toks[0],
            msg,
            Error,
          )
        }
        let ty = self.ensure_type(checked_left.ty)
        if !(ty is (Int | Int64 | TypeVar(_))) {
          let msg = "Operands of bitwise AND/OR operation must be of type Int or Int64"+
           " while got \{ty}"
          self.throw_(
            expr.toks[0],
            msg,
            Error,
          )
        }
        let e = Expr::{
          kind: BinaryExpr(op, checked_left, checked_right),
          ty: checked_left.ty, toks: expr.toks
        }
        return e
      }
      if binop_is_logical(op) {
        if !(self.is_type_compatible(checked_left.ty, Bool) &&
          self.is_type_compatible(checked_right.ty, Bool)) {
          let msg = "Operands of logical binary operation must be of type Bool"+
           " while got \{checked_left.ty} and \{checked_right.ty}"
          self.throw_(
            expr.toks[0],
            msg,
            Error,
          )
        }
        let e = Expr::{
          kind: BinaryExpr(op, checked_left, checked_right),
          ty: Bool, toks: expr.toks
        }
        return e
      }
      println("Compile ICE: Unsupported binary operation, Should not reach here.")
      panic()
    }
    BlockExpr(block_expr) => {
      let checked_block_expr = self.check_block_expr(block_expr)
      Expr::{ kind: BlockExpr(checked_block_expr), ty: checked_block_expr.ty, toks: expr.toks }
    }
    IfExpr(if_expr) => {
      let checked_if_expr = self.check_if_expr(if_expr)
      Expr::{ kind: IfExpr(checked_if_expr), ty: checked_if_expr.ty, toks: expr.toks }
    }
    MatchExpr(match_expr) => {
      let checked_match_expr = self.check_match_expr(match_expr)
      Expr::{ kind: MatchExpr(checked_match_expr), ty: checked_match_expr.ty, toks: expr.toks }
    }
  }
}
