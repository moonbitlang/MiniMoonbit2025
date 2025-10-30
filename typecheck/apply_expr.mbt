///|
pub(all) struct ApplyExpr {
  kind : ApplyExprKind
  ty : TypeKind
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
) -> ApplyExpr raise TypeCheckError {
  match apply_expr.kind {
    AtomExpr(atom_expr) => {
      let checked_atom_expr = self.check_atom_expr(atom_expr)
      ApplyExpr::{
        kind: ApplyExprKind::AtomExpr(checked_atom_expr),
        ty: checked_atom_expr.ty,
      }
    }
    ArrayAccess(array_expr, index_expr) => {
      let checked_array_expr = self.check_apply_expr(array_expr)
      let checked_index_expr = self.check_expr(index_expr)

      // Ensure the index expression is of integer type
      if !(checked_index_expr.ty is Int) {
        raise TypeCheckError("Array/String index must be of type Int")
      }

      // Handle String indexing (returns Int representing char)
      if checked_array_expr.ty is String {
        ApplyExpr::{
          kind: ApplyExprKind::ArrayAccess(checked_array_expr, checked_index_expr),
          ty: Int,
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
            }
          }
          _ => raise TypeCheckError("Attempted to index a non-array/non-string type")
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
          }
          return e
        }
        if field_name is "length" {
          let e = ApplyExpr::{
            kind: FieldAccess(struct_expr, field_name),
            ty: Function([], Int),
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
          }
          return e
        }
      }
      guard struct_expr.ty is Struct(struct_type_name) else {
        raise TypeCheckError("Attempted to access field of a non-struct type")
      }
      guard self.struct_defs.get(struct_type_name) is Some(struct_def) else {
        raise TypeCheckError("Undefined struct type: struct_type_name")
      }
      let ty = for field in struct_def.fields {
        if field.name == field_name {
          break field.ty.kind
        }
      } else {
        raise TypeCheckError("Struct type does not have field: \{field_name}")
      }
      ApplyExpr::{ kind: FieldAccess(struct_expr, field_name), ty }
    }
    Call(callee_expr, arg_exprs) => {
      let callee_expr = self.check_apply_expr(callee_expr)
      guard callee_expr.ty is Function(arg_tys, ret_ty) else {
        raise TypeCheckError("Attempted to call a non-function type")
      }
      if arg_exprs.length() != arg_tys.length() {
        raise TypeCheckError("Function call argument count mismatch")
      }
      let arg_len = arg_exprs.length()
      let new_arg_exprs = Array::new()
      for i in 0..<arg_len {
        let arg_expr = self.check_expr(arg_exprs[i])
        let expected_ty = arg_tys[i]
        if !self.is_type_compatible(arg_expr.ty, expected_ty) {
          raise TypeCheckError(
            "Function call argument type mismatch at position \{i}, expected \{expected_ty}, got \{arg_expr.ty}",
          )
        }
        new_arg_exprs.push(arg_expr)
      }
      let ret_ty = self.ensure_type(ret_ty)
      ApplyExpr::{ kind: Call(callee_expr, new_arg_exprs), ty: ret_ty }
    }
  }
}
