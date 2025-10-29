///|
pub(all) struct ExternFunction {
  fname : String
  param_list : Array[Param]
  ret_ty : TypeKind
  ffi_name : String
} derive(Show)

///|
pub fn Context::check_extern_function(
  self : Context,
  func : @parser.ExternFunction,
) -> ExternFunction raise TypeCheckError {
  guard self.func_types.get(func.fname) is Some(Function(param_types, ret_ty)) else {
    raise TypeCheckError("Function not found in environment: \{func.fname}")
  }
  let param_list = Array::new()
  for i, param in func.param_list {
    let { name, .. } = param
    let param_ty = { kind: param_types[i], mutable: false }
    self.type_env.set(name, param_ty)
    param_list.push(Param::{ name, ty: param_ty.kind })
  }
  ExternFunction::{
    fname: func.fname,
    param_list,
    ret_ty,
    ffi_name: func.ffi_name,
  }
}
