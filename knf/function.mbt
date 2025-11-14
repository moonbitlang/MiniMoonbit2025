///|
pub(all) struct KnfFunction {
  name : String
  ret_ty : Type
  params : Array[(Name, Type)]
  body : KnfBlock
}

///|
pub fn Context::top_function_to_knf(
  self : Context,
  top_func : @typecheck.TopFunction,
) -> KnfFunction raise KnfTransformError {
  self.enter_scope()
  let knf_params = Array::new()
  let param_types : Array[Type] = Array::new()
  for param in top_func.param_list {
    let { name: param_name, ty: param_ty } = param
    let param_type = self.typekind_to_knf(param_ty)
    let param = self.add_new_name(param_name, param_type)
    self.name_env.set(param_name, param, param_type, false)
    knf_params.push((param, param_type))
    param_types.push(param_type)
  }
  let ret_ty = self.typekind_to_knf(top_func.ret_ty)
  let func_type = Function(param_types, ret_ty)
  let func_name = self.add_new_name(top_func.fname, func_type)
  let new_body = self.block_expr_to_knf(top_func.body)
  self.exit_scope()
  KnfFunction::{
    name: func_name.to_string(),
    ret_ty,
    params: knf_params,
    body: new_body,
  }
}

///|
pub impl Show for KnfFunction with output(self, logger) {
  let { name, ret_ty, params, body } = self
  logger.write_string("fn \{name}")
  if name != "main" {
    logger.write_string("(")
    let param_str = params
      .map(param => {
        let (param_name, param_ty) = param
        "\{param_name}: \{param_ty}"
      })
      .join(", ")
    logger.write_string(param_str)
    logger.write_string(") -> \{ret_ty}")
  }
  logger.write_char(' ')
  logger.write_object(body)
}
