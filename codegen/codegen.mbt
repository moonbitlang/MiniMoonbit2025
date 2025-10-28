pub fn codegen_all(code: String) -> @llvm.Module raise {
  let tokens = @lexer.tokenize(code)
  let ast = @parser.parse(tokens)
  let typed_ast = @typecheck.typecheck(ast)
  let knf_prog = @knf.knf_transform(typed_ast)
  let llvm_mod = codegen(knf_prog)
  return llvm_mod
}

///|
pub fn codegen(knf_prog : @knf.KnfProgram) -> @llvm.Module raise {
  let codegen_ctx = Context::new("demo")
  codegen_ctx.collect_struct_types(knf_prog.struct_defs)
  codegen_ctx.generate_global_stmts(knf_prog.global_stmts)
  codegen_ctx.collect_top_lets(knf_prog.top_lets)
  codegen_ctx.collect_func_values(knf_prog.functions)
  codegen_ctx.generate_functions(knf_prog.functions)
  codegen_ctx.llvm_mod
}

///|
pub fn Context::generate_global_stmts(
  self : Context,
  knf_global_stmts : Array[@knf.KnfStmt],
) -> Unit raise {
  for knf_stmt in knf_global_stmts {
    match knf_stmt {
      Let(name, ty, expr) =>
        // Try to evaluate as constant, if it fails, defer to runtime
        match expr {
          Int(_) | Bool(_) | Double(_) | String(_) => {
            let val = self.global_expr_codegen(expr)
            guard val.tryAsConstant() is Some(const_val) else {
              raise CodegenError(
                "Global let expression did not evaluate to a constant",
              )
            }
            self.global_consts.set(name.to_string(), const_val)
            self.global_types.set(name.to_string(), ty)
          }
          _ => {
            // For complex expressions, create a global variable and defer init
            let llvm_ty = self.type_codegen_opaque(ty)
            let null_val = match ty {
              Int => (self.llvm_ctx.getConstInt32(0) : &@llvm.Constant)
              Bool => self.llvm_ctx.getConstFalse()
              Double => self.llvm_ctx.getConstDouble(0.0)
              _ => self.llvm_ctx.getConstPointerNull(llvm_ty)
            }
            let v = self.llvm_mod.addGlobalVariable(
              llvm_ty,
              name.to_string(),
              initializer=null_val,
            )
            self.global_values.set(name.to_string(), v)
            self.global_types.set(name.to_string(), ty)
            // Store the initialization expression for later use in main
            self.global_array_inits.push((name, ty, expr))
          }
        }
      _ =>
        raise CodegenError(
          "Only let statements are allowed in global statements",
        )
    }
  }
}

///|
pub fn Context::collect_top_lets(
  self : Context,
  top_lets : Map[String, @knf.KnfTopLet],
) -> Unit raise {
  for _, top_let in top_lets {
    let _ = self.top_let_codegen(top_let)

  }
}

///|
pub fn Context::generate_functions(
  self : Context,
  functions : Map[String, @knf.KnfFunction],
) -> Unit raise {
  for _, knf_func in functions {
    let _ = self.top_function_codegen(knf_func)

  }
}
