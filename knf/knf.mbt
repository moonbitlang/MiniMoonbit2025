///|
pub(all) struct KnfProgram {
  struct_defs : Map[String, KnfStructDef]
  global_stmts : Array[KnfStmt]
  top_lets : Map[String, KnfTopLet]
  functions : Map[String, KnfFunction]
  externs : Map[String, KnfExtern]
}

///|
pub impl Show for KnfProgram with output(self, logger) {
  for _, struct_def in self.struct_defs {
    logger.write_object(struct_def)
    logger.write_char('\n')
  }
  for s in self.global_stmts {
    logger.write_object(s)
    logger.write_char('\n')
  }
  for _, top_let in self.top_lets {
    logger.write_object(top_let)
    logger.write_char('\n')
  }
  for _, func in self.functions {
    logger.write_object(func)
    logger.write_char('\n')
  }
}

///|
pub fn Context::program_to_knf(
  self : Context,
  prog : @typecheck.Program,
) -> KnfProgram raise KnfTransformError {
  let struct_defs = Map::new()
  let top_lets = Map::new()
  let functions = Map::new()
  let externs = Map::new()

  // First, register all struct definitions
  for sname, struct_def in prog.struct_defs {
    let knf_struct_def = self.struct_def_to_knf(struct_def)
    struct_defs.set(sname, knf_struct_def)
  }

  // Second, regiter all extern functions
  for fname, extern_func in prog.extern_funcions {
    let knf_extern = self.extern_to_knf(extern_func)
    externs.set(knf_extern.name, knf_extern)
    self.globals.set(fname, Function(knf_extern.params, knf_extern.ret_ty))
  }

  // Third, register all function signatures in globals
  // so that top_let expressions can reference them
  for fname, func in prog.top_functions {
    let param_types = func.param_list.map(fn(p) { self.typekind_to_knf(p.ty) })
    let ret_ty = self.typekind_to_knf(func.ret_ty)
    self.globals.set(fname, Function(param_types, ret_ty))
  }

  // Fourth, process top-level let declarations
  for let_name, top_let in prog.top_lets {
    let knf_top_let = self.top_let_to_knf(top_let)
    top_lets.set(let_name, knf_top_let)
  }

  // Finally, process function bodies
  for fname, func in prog.top_functions {
    let knf_func = self.top_function_to_knf(func)
    functions.set(fname, knf_func)
  }
  let global_stmts = self.global_stmts
  KnfProgram::{ struct_defs, externs, top_lets, global_stmts, functions }
}

///|
pub fn knf_transform(
  prog : @typecheck.Program,
) -> KnfProgram raise KnfTransformError {
  let context = Context::new()
  context.globals.set("__builtin_println_int", Function([Int], Unit))
  context.globals.set("__builtin_println_string", Function([String], Unit))
  context.globals.set("__builtin_println_bool", Function([Bool], Unit))
  context.globals.set("__builtin_println_double", Function([Double], Unit))
  context.globals.set("__builtin_print_int", Function([Int], Unit))
  context.globals.set("__builtin_print_string", Function([String], Unit))
  context.globals.set("__builtin_print_bool", Function([Bool], Unit))
  context.globals.set("__builtin_print_double", Function([Double], Unit))
  context.program_to_knf(prog)
}
