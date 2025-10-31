///|
pub(all) struct Param {
  name : String
  ty : TypeKind
} derive(Show)

///|
pub(all) struct TopFunction {
  fname : String
  param_list : Array[Param]
  ret_ty : TypeKind
  body : BlockExpr
} derive(Show)

///|
pub fn Context::check_top_function(
  self : Context,
  func : @parser.TopFunction,
) -> TopFunction raise TypeCheckError {
  let func_whole_name = func.whole_name()
  guard self.func_types.get(func_whole_name) is Some(Function(param_types, ret_ty)) else {
    raise TypeCheckError("Function not found in environment: \{func.fname}")
  }
  self.enter_scope()
  let param_list = Array::new()
  for i, param in func.param_list {
    let { name, .. } = param
    let param_ty = { kind: param_types[i], mutable: false }
    self.type_env.set(name, param_ty)
    param_list.push(Param::{ name, ty: param_ty.kind })
  }
  if !(func.typeTag is "") {
    guard self.struct_defs.get(func.typeTag) is Some(struct_def) else {
      raise TypeCheckError("Struct type not found for method: \{func.typeTag}::\{func.fname}")
    }
    if param_list.get(0) is Some(p) && p.ty is Struct(s) && s == func.typeTag {
      struct_def.methods.set(
        func.fname,
        Function(param_types, ret_ty),
      )
    }
  }
  self.set_current_func_ret_ty(ret_ty)
  let checked_block = self.check_block_expr(func.body)
  if !self.is_type_compatible(checked_block.ty, ret_ty) {
    raise TypeCheckError(
      "Body and Return Type: Type mismatch in top-level function \{func.fname}",
    )
  }
  self.exit_scope()
  self.current_func_ret_ty = None
  TopFunction::{ fname: func_whole_name, param_list, ret_ty, body: checked_block }
}
