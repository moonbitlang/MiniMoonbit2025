///|
pub fn Context::top_let_codegen(
  self : Self,
  top_let : @knf.KnfTopLet,
) -> &@llvm.Value raise {
  let { name, ty, expr, } = top_let
  let name_str = name.to_string()

  // For complex types (Array, Tuple, Struct), always use runtime initialization
  match ty {
    Array(_) | Tuple(_) | Struct(_) => {
      let llvm_mod = self.llvm_mod
      let llvm_ty = self.type_codegen_opaque(ty)
      let null_ptr = self.llvm_ctx.getConstPointerNull(llvm_ty)
      let v = llvm_mod.addGlobalVariable(
        llvm_ty,
        name_str,
        initializer=null_ptr,
      )
      self.global_values.set(name_str, v)
      self.global_types.set(name_str, ty)
      self.global_array_inits.push((name, ty, expr))
      return v
    }
    _ => ()
  }

  // For simple types, try to evaluate as a compile-time constant
  // If evaluation fails, fall back to runtime initialization
  let expr_val = self.global_expr_codegen(expr) catch {
    _ => {
      // Cannot evaluate as constant, need runtime initialization
      let llvm_ty = self.type_codegen_opaque(ty)
      let null_val = match ty {
        Int => (self.llvm_ctx.getConstInt32(0) : &@llvm.Constant)
        Bool => self.llvm_ctx.getConstFalse()
        Double => self.llvm_ctx.getConstDouble(0.0)
        _ => self.llvm_ctx.getConstPointerNull(llvm_ty)
      }
      let v = self.llvm_mod.addGlobalVariable(
        llvm_ty,
        name_str,
        initializer=null_val,
      )
      self.global_values.set(name_str, v)
      self.global_types.set(name_str, ty)
      self.global_array_inits.push((name, ty, expr))
      return v
    }
  }
  guard expr_val.tryAsConstant() is Some(const_val) else {
    raise CodegenError(
      "Top-level let expression did not produce a constant value",
    )
  }
  let llvm_mod = self.llvm_mod
  let llvm_ty = self.type_codegen_opaque(ty)
  let v = llvm_mod.addGlobalConstant(llvm_ty, "\{name_str}", const_val)
  self.global_consts.set(name_str, const_val)
  self.global_values.set(name_str, v)
  self.global_types.set(name_str, ty)
  v
}

///|
pub fn Context::global_expr_codegen(
  self : Self,
  expr : @knf.KnfExpr,
) -> &@llvm.Value raise {
  match expr {
    Int(i) => (self.llvm_ctx.getConstInt32(i) : &@llvm.Value)
    Bool(true) => self.llvm_ctx.getConstTrue()
    Bool(false) => self.llvm_ctx.getConstFalse()
    Double(d) => self.llvm_ctx.getConstDouble(d)
    String(s) => self.llvm_mod.addGlobalString(s)
    Ident(name) => {
      let name = name.to_string()
      match self.global_consts.get(name) {
        Some(v) => (v : &@llvm.Value)
        None =>
          raise CodegenError(
            "Undefined global constant in global expression: \{name}. Perhaps it hasn't been defined yet?",
          )
      }
    }
    ArrayLiteral(Int, element_names) => {
      let llvm_elements : Array[&@llvm.Constant] = []
      for name in element_names {
        let name = name.to_string()
        match self.global_consts.get(name) {
          Some(v) => llvm_elements.push(v)
          None =>
            raise CodegenError(
              "Undefined global identifier in array literal: \{name}",
            )
        }
      }
      let i32_ty = self.llvm_ctx.getInt32Ty()
      self.llvm_ctx.getConstArray(i32_ty, llvm_elements)
    }
    ArrayLiteral(Double, element_names) => {
      let llvm_elements : Array[&@llvm.Constant] = []
      for name in element_names {
        let name = name.to_string()
        match self.global_consts.get(name) {
          Some(v) => llvm_elements.push(v)
          None =>
            raise CodegenError(
              "Undefined global identifier in array literal: \{name}",
            )
        }
      }
      let doublety = self.llvm_ctx.getDoubleTy()
      self.llvm_ctx.getConstArray(doublety, llvm_elements)
    }
    ArrayLiteral(Bool, element_names) => {
      let llvm_elements : Array[&@llvm.Constant] = []
      for name in element_names {
        let name = name.to_string()
        match self.global_consts.get(name) {
          Some(v) => llvm_elements.push(v)
          None =>
            raise CodegenError(
              "Undefined global identifier in array literal: \{name}",
            )
        }
      }
      let boolty = self.llvm_ctx.getInt1Ty()
      self.llvm_ctx.getConstArray(boolty, llvm_elements)
    }
    _ =>
      raise CodegenError("Unsupported global expression for codegen: \{expr}")
  }
}
