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
    // 专门处理 method call 模式: obj.method(args)
    Call(callee, arg_exprs) if callee.kind is FieldAccess(base_expr, method_name) => {
      let checked_base_expr = self.check_apply_expr(base_expr)
      
      // Handle Array.length()
      if checked_base_expr.ty is Array(_) && method_name == "length" {
        if arg_exprs.length() != 0 {
          let msg = "Array.length() expects 0 arguments, got \{arg_exprs.length()}"
          self.throw_(apply_expr.toks[0], msg, Error)
        }
        // 直接转换为对 get_array_length 的调用
        let length_func = ApplyExpr::{
          kind: AtomExpr(AtomExpr::{ 
            kind: AtomExprKind::Ident("get_array_length"), 
            ty: Function([checked_base_expr.ty], TypeKind::Int),
            toks: apply_expr.toks,
          }),
          ty: Function([checked_base_expr.ty], TypeKind::Int),
          toks: apply_expr.toks,
        }
        let base_as_expr = Expr::{ 
          kind: ExprKind::ApplyExpr(checked_base_expr), 
          ty: checked_base_expr.ty,
          toks: checked_base_expr.toks,
        }
        return ApplyExpr::{
          kind: Call(length_func, [base_as_expr]),
          ty: TypeKind::Int,
          toks: apply_expr.toks,
        }
      }
      
      // Handle Array.push(value)
      if checked_base_expr.ty is Array(element_type) && method_name == "push" {
        if arg_exprs.length() != 1 {
          let msg = "Array.push() expects 1 argument, got \{arg_exprs.length()}"
          self.throw_(apply_expr.toks[0], msg, Error)
        }
        let checked_arg = self.check_expr(arg_exprs[0])
        if !self.is_type_compatible(checked_arg.ty, element_type) {
          let msg = "Array.push() argument type mismatch, expected \{element_type}, got \{checked_arg.ty}"
          self.throw_(checked_arg.toks[0], msg, Error)
        }
        // 根据元素类型确定对应的 push 函数名
        let push_func_name = match element_type {
          TypeKind::Int => "array_int_push"
          TypeKind::Int64 => "array_int64_push"
          TypeKind::Double => "array_double_push"
          TypeKind::Float => "array_float_push"
          TypeKind::Bool => "array_bool_push"
          TypeKind::Char => "array_char_push"
          _ => "array_ptr_push"
        }
        let push_func = ApplyExpr::{
          kind: AtomExpr(AtomExpr::{ 
            kind: AtomExprKind::Ident(push_func_name), 
            ty: Function([checked_base_expr.ty, element_type], TypeKind::Unit),
            toks: apply_expr.toks,
          }),
          ty: Function([checked_base_expr.ty, element_type], TypeKind::Unit),
          toks: apply_expr.toks,
        }
        let base_as_expr = Expr::{ 
          kind: ExprKind::ApplyExpr(checked_base_expr), 
          ty: checked_base_expr.ty,
          toks: checked_base_expr.toks,
        }
        return ApplyExpr::{
          kind: Call(push_func, [base_as_expr, checked_arg]),
          ty: TypeKind::Unit,
          toks: apply_expr.toks,
        }
      }
      
      // Handle String.length()
      if checked_base_expr.ty is String && method_name == "length" {
        if arg_exprs.length() != 0 {
          let msg = "String.length() expects 0 arguments, got \{arg_exprs.length()}"
          self.throw_(apply_expr.toks[0], msg, Error)
        }
        let length_func = ApplyExpr::{
          kind: AtomExpr(AtomExpr::{ 
            kind: AtomExprKind::Ident("__builtin_get_string_length"), 
            ty: Function([TypeKind::String], TypeKind::Int),
            toks: apply_expr.toks,
          }),
          ty: Function([TypeKind::String], TypeKind::Int),
          toks: apply_expr.toks,
        }
        let base_as_expr = Expr::{ 
          kind: ExprKind::ApplyExpr(checked_base_expr), 
          ty: checked_base_expr.ty,
          toks: checked_base_expr.toks,
        }
        return ApplyExpr::{
          kind: Call(length_func, [base_as_expr]),
          ty: TypeKind::Int,
          toks: apply_expr.toks,
        }
      }
      
      // Handle primitive type conversion methods
      match handle_primitive_method_call(
        self,
        checked_base_expr,
        method_name,
        arg_exprs,
        apply_expr.toks,
      ) {
        Some(result) => return result
        None => ()
      }
      
      // 如果不是已知的 method call，报错
      let msg = "Unknown method: \{method_name} for type: \{checked_base_expr.ty}"
      self.throw_(apply_expr.toks[0], msg, Error)
      return ApplyExpr::{
        kind: Call(
          ApplyExpr::{ 
            kind: FieldAccess(checked_base_expr, method_name), 
            ty: TypeKind::Unit,
            toks: apply_expr.toks,
          },
          arg_exprs.map(e => self.check_expr(e))
        ),
        ty: TypeKind::Unit,
        toks: apply_expr.toks,
      }
    }
    FieldAccess(struct_expr, field_name) => {
      let struct_expr = self.check_apply_expr(struct_expr)
      // FieldAccess 现在只处理普通的结构体字段访问
      // 不再处理 method，因为 method 会被 Call(FieldAccess(...)) 匹配
      guard struct_expr.ty is Struct(struct_type_name) else {
        let msg = "Attempted to access field of a non-struct type: \{struct_expr.ty}"
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

///|
/// Handle primitive type method calls (e.g., n.to_string(), n.to_double(), etc.)
/// 直接转换为对内置函数或cast操作的调用
fn handle_primitive_method_call(
  ctx : Context,
  base_expr : ApplyExpr,
  method_name : String,
  arg_exprs : Array[@parser.Expr],
  toks : ArrayView[Token],
) -> ApplyExpr? {
  // 所有的转换方法都不需要参数
  if arg_exprs.length() != 0 {
    let msg = "Conversion method \{method_name}() expects 0 arguments, got \{arg_exprs.length()}"
    ctx.throw_(toks[0], msg, Error)
  }
  
  let base_as_expr = Expr::{ 
    kind: ExprKind::ApplyExpr(base_expr), 
    ty: base_expr.ty,
    toks: base_expr.toks,
  }
  
  match base_expr.ty {
    // Int methods
    TypeKind::Int => match method_name {
      "to_int64" | "to_float" | "to_double" => {
        let target_ty = match method_name {
          "to_int64" => TypeKind::Int64
          "to_float" => TypeKind::Float
          "to_double" => TypeKind::Double
          _ => TypeKind::Int // unreachable
        }
        Some(ApplyExpr::{
          kind: AtomExpr(AtomExpr::{ 
            kind: AtomExprKind::Cast(target_ty, base_as_expr), 
            ty: target_ty,
            toks,
          }),
          ty: target_ty,
          toks,
        })
      }
      "reinterpret_as_float" => {
        Some(ApplyExpr::{
          kind: AtomExpr(AtomExpr::{ 
            kind: AtomExprKind::BitCast(TypeKind::Float, base_as_expr), 
            ty: TypeKind::Float,
            toks,
          }),
          ty: TypeKind::Float,
          toks,
        })
      }
      "to_string" => {
        let to_string_func = ApplyExpr::{
          kind: AtomExpr(AtomExpr::{ 
            kind: AtomExprKind::Ident("__builtin_int_to_string"), 
            ty: Function([TypeKind::Int], TypeKind::String),
            toks,
          }),
          ty: Function([TypeKind::Int], TypeKind::String),
          toks,
        }
        Some(ApplyExpr::{
          kind: Call(to_string_func, [base_as_expr]),
          ty: TypeKind::String,
          toks,
        })
      }
      _ => None
    }
    // Int64 methods
    TypeKind::Int64 => match method_name {
      "to_int" | "to_float" | "to_double" => {
        let target_ty = match method_name {
          "to_int" => TypeKind::Int
          "to_float" => TypeKind::Float
          "to_double" => TypeKind::Double
          _ => TypeKind::Int64 // unreachable
        }
        Some(ApplyExpr::{
          kind: AtomExpr(AtomExpr::{ 
            kind: AtomExprKind::Cast(target_ty, base_as_expr), 
            ty: target_ty,
            toks,
          }),
          ty: target_ty,
          toks,
        })
      }
      "reinterpret_as_double" => {
        Some(ApplyExpr::{
          kind: AtomExpr(AtomExpr::{ 
            kind: AtomExprKind::BitCast(TypeKind::Double, base_as_expr), 
            ty: TypeKind::Double,
            toks,
          }),
          ty: TypeKind::Double,
          toks,
        })
      }
      "to_string" => {
        let to_string_func = ApplyExpr::{
          kind: AtomExpr(AtomExpr::{ 
            kind: AtomExprKind::Ident("__builtin_int64_to_string"), 
            ty: Function([TypeKind::Int64], TypeKind::String),
            toks,
          }),
          ty: Function([TypeKind::Int64], TypeKind::String),
          toks,
        }
        Some(ApplyExpr::{
          kind: Call(to_string_func, [base_as_expr]),
          ty: TypeKind::String,
          toks,
        })
      }
      _ => None
    }
    // Float methods
    TypeKind::Float => match method_name {
      "to_int" | "to_int64" | "to_double" => {
        let target_ty = match method_name {
          "to_int" => TypeKind::Int
          "to_int64" => TypeKind::Int64
          "to_double" => TypeKind::Double
          _ => TypeKind::Float // unreachable
        }
        Some(ApplyExpr::{
          kind: AtomExpr(AtomExpr::{ 
            kind: AtomExprKind::Cast(target_ty, base_as_expr), 
            ty: target_ty,
            toks,
          }),
          ty: target_ty,
          toks,
        })
      }
      "reinterpret_as_int" => {
        Some(ApplyExpr::{
          kind: AtomExpr(AtomExpr::{ 
            kind: AtomExprKind::BitCast(TypeKind::Int, base_as_expr), 
            ty: TypeKind::Int,
            toks,
          }),
          ty: TypeKind::Int,
          toks,
        })
      }
      "to_string" => {
        let to_string_func = ApplyExpr::{
          kind: AtomExpr(AtomExpr::{ 
            kind: AtomExprKind::Ident("__builtin_float_to_string"), 
            ty: Function([TypeKind::Float], TypeKind::String),
            toks,
          }),
          ty: Function([TypeKind::Float], TypeKind::String),
          toks,
        }
        Some(ApplyExpr::{
          kind: Call(to_string_func, [base_as_expr]),
          ty: TypeKind::String,
          toks,
        })
      }
      _ => None
    }
    // Double methods
    TypeKind::Double => match method_name {
      "to_int" | "to_int64" | "to_float" => {
        let target_ty = match method_name {
          "to_int" => TypeKind::Int
          "to_int64" => TypeKind::Int64
          "to_float" => TypeKind::Float
          _ => TypeKind::Double // unreachable
        }
        Some(ApplyExpr::{
          kind: AtomExpr(AtomExpr::{ 
            kind: AtomExprKind::Cast(target_ty, base_as_expr), 
            ty: target_ty,
            toks,
          }),
          ty: target_ty,
          toks,
        })
      }
      "reinterpret_as_int64" => {
        Some(ApplyExpr::{
          kind: AtomExpr(AtomExpr::{ 
            kind: AtomExprKind::BitCast(TypeKind::Int64, base_as_expr), 
            ty: TypeKind::Int64,
            toks,
          }),
          ty: TypeKind::Int64,
          toks,
        })
      }
      "to_string" => {
        let to_string_func = ApplyExpr::{
          kind: AtomExpr(AtomExpr::{ 
            kind: AtomExprKind::Ident("__builtin_double_to_string"), 
            ty: Function([TypeKind::Double], TypeKind::String),
            toks,
          }),
          ty: Function([TypeKind::Double], TypeKind::String),
          toks,
        }
        Some(ApplyExpr::{
          kind: Call(to_string_func, [base_as_expr]),
          ty: TypeKind::String,
          toks,
        })
      }
      _ => None
    }
    // Char methods
    TypeKind::Char => match method_name {
      "to_string" => {
        let to_string_func = ApplyExpr::{
          kind: AtomExpr(AtomExpr::{ 
            kind: AtomExprKind::Ident("__builtin_char_to_string"), 
            ty: Function([TypeKind::Char], TypeKind::String),
            toks,
          }),
          ty: Function([TypeKind::Char], TypeKind::String),
          toks,
        }
        Some(ApplyExpr::{
          kind: Call(to_string_func, [base_as_expr]),
          ty: TypeKind::String,
          toks,
        })
      }
      _ => None
    }
    _ => None
  }
}
