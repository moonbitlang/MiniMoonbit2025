///|
pub(all) struct ApplyExpr {
  kind : ApplyExprKind
  ty : TypeKind
  toks: ArrayView[Token]
} derive(Show)

///|
pub(all) enum ApplyExprKind {
  AtomExpr(AtomExpr)
  ArrayAccess(ApplyExpr, Expr)
  FieldAccess(ApplyExpr, String)
  Call(ApplyExpr, Array[Expr])
} derive(Show)

///|
pub fn Context::check_apply_expr(
  self : Self,
  apply_expr : @parser.ApplyExpr,
) -> ApplyExpr {
  match apply_expr.kind {
    AtomExpr(atom_expr) => {
      let checked_atom_expr = self.check_atom_expr(atom_expr)
      ApplyExpr::{
        kind: ApplyExprKind::AtomExpr(checked_atom_expr),
        ty: checked_atom_expr.ty,
        toks: apply_expr.toks,
      }
    }
    ArrayAccess(array_expr, index_expr) => {
      let checked_array_expr = self.check_apply_expr(array_expr)
      let checked_index_expr = self.check_expr(index_expr)

      // Ensure the index expression is of integer type
      if !(checked_index_expr.ty is Int) {
        let msg = "Array/String index must be of type Int"
        self.throw_(checked_index_expr.toks[0], msg, Error)
      }

      // Handle String indexing (returns Char)
      if checked_array_expr.ty is String {
        ApplyExpr::{
          kind: ApplyExprKind::ArrayAccess(checked_array_expr, checked_index_expr),
          ty: Char,
          toks: apply_expr.toks,
        }
      } else {
        // Ensure the array expression is of array type
        match checked_array_expr.ty {
          Array(element_type) => {
            ApplyExpr::{
              kind: ApplyExprKind::ArrayAccess(
                checked_array_expr, checked_index_expr,
              ),
              ty: element_type,
              toks: apply_expr.toks,
            }
          }
          _ => {
            let msg = "Attempted to index a non-array/non-string type"
            self.throw_(checked_array_expr.toks[0], msg, Error)
            ApplyExpr::{
              kind: ApplyExprKind::ArrayAccess(
                checked_array_expr, checked_index_expr,
              ),
              ty: Unit,
              toks: apply_expr.toks,
            }
          }
        }
      }
    }
    FieldAccess(struct_expr, field_name) => {
      let struct_expr = self.check_apply_expr(struct_expr)
      if struct_expr.ty is Array(inner_ty) {
        if field_name is "push" {
          let e = ApplyExpr::{
            kind: FieldAccess(struct_expr, field_name),
            ty: Function([inner_ty], Unit),
            toks: apply_expr.toks,
          }
          return e
        }
        if field_name is "length" {
          let e = ApplyExpr::{
            kind: FieldAccess(struct_expr, field_name),
            ty: Function([], Int),
            toks: apply_expr.toks,
          }
          return e
        }
      }
      // Handle String.length()
      if struct_expr.ty is String {
        if field_name is "length" {
          let e = ApplyExpr::{
            kind: FieldAccess(struct_expr, field_name),
            ty: Function([], Int),
            toks: apply_expr.toks,
          }
          return e
        }
      }
      guard struct_expr.ty is Struct(struct_type_name) else {
        let msg = "Attempted to access field of a non-struct type"
        self.throw_(struct_expr.toks[0], msg, Error)
        return ApplyExpr::{
          kind: FieldAccess(struct_expr, field_name),
          ty: Unit,
          toks: apply_expr.toks,
        }
      }
      guard self.struct_defs.get(struct_type_name) is Some(struct_def) else {
        let msg = "Undefined struct type: \{struct_type_name}"
        self.throw_(struct_expr.toks[0], msg, Error)
        return ApplyExpr::{
          kind: FieldAccess(struct_expr, field_name),
          ty: Unit,
          toks: apply_expr.toks,
        }
      }
      let ty = for field in struct_def.fields {
        if field.name == field_name {
          break field.ty.kind
        }
      } else {
        let msg = "Struct type does not have field: \{field_name}"
        self.throw_(struct_expr.toks[0], msg, Error)
        Unit
      }
      ApplyExpr::{ kind: FieldAccess(struct_expr, field_name), ty, toks: apply_expr.toks}
    }
    Call(callee_expr, arg_exprs) => {
      let callee_expr = self.check_apply_expr(callee_expr)
      guard callee_expr.ty is Function(arg_tys, ret_ty) else {
        let msg = "Attempted to call a non-function type: \{callee_expr.ty}"
        self.throw_(callee_expr.toks[0], msg, Error)
        return ApplyExpr::{
          kind: Call(callee_expr, arg_exprs.map(e => self.check_expr(e))),
          ty: Unit,
          toks: apply_expr.toks,
        }
      }
      if arg_exprs.length() != arg_tys.length() {
        let msg = "Function call argument count mismatch, expected \{arg_tys.length()}, got \{arg_exprs.length()}"
        self.throw_(apply_expr.toks[0], msg, Error)
      }
      let arg_len = min(arg_exprs.length(), arg_tys.length())
      let new_arg_exprs = Array::new()
      for i in 0..<arg_len {
        let arg_expr = self.check_expr(arg_exprs[i])
        let expected_ty = arg_tys[i]
        if !self.is_type_compatible(arg_expr.ty, expected_ty) {
          let msg = "Function call argument type mismatch, expected \{expected_ty}, got \{arg_expr.ty}"
          self.throw_(arg_expr.toks[0], msg, Error)
        }
        new_arg_exprs.push(arg_expr)
      }
      let ret_ty = self.ensure_type(ret_ty)
      ApplyExpr::{ kind: Call(callee_expr, new_arg_exprs), ty: ret_ty, toks: apply_expr.toks}
    }
  }
}

fn min(a: Int, b: Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}
