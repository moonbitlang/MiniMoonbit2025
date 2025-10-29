///|
///
/// 注意这里的expr_codegen的返回值是Option[&@llvm.Value]
/// 对于Unit类型的表达式，应当返回None做特殊处理。
///
/// 对于像let a: Unit = (); 这种表达式，可以考虑把a的值设为null指针，
/// 使用llvm_ctx.getConstPointerNull(llvm_ctx.getPtrTy())
pub fn Context::expr_codegen(
  self : Self,
  expr : @knf.KnfExpr,
) -> &@llvm.Value? raise {
  match expr {
    Unit => None
    Int(i) => (self.llvm_ctx.getConstInt32(i) : &@llvm.Value) |> Some
    Bool(true) => self.llvm_ctx.getConstTrue() |> Some
    Bool(false) => self.llvm_ctx.getConstFalse() |> Some
    Double(d) => self.llvm_ctx.getConstDouble(d) |> Some
    // if name is a top function, we need to make a closure struct
    // then store the function to this struct's first field
    // and return the struct pointer
    Ident(name) if self.is_top_level_function(name) => {
      guard self.functions.get(name.to_string()) is Some(func_value) else {
        raise CodegenError(
          "Failed to get function value for top-level function \{name}",
        )
      }
      let ptrty = self.llvm_ctx.getPtrTy()
      let zero = self.llvm_ctx.getConstInt32(0)
      // Create closure struct with only function pointer (no captured vars)
      let closure_struct_ty = self.llvm_ctx.getStructType([ptrty])
      let mbt_malloc = self.get_builtin_function("moonbit_malloc")
      let closure_size = self.llvm_mod
        .getDataLayout()
        .getTypeAllocSize(closure_struct_ty)
      let closure_size = self.llvm_ctx.getConstInt32(closure_size)
      let closure_ptr = self.builder.createCall(mbt_malloc, [closure_size])
      // Set function pointer in the first field
      let func_ptr_ptr = self.builder.createGEP(
        closure_ptr,
        closure_struct_ty,
        [zero, zero],
      )
      let _ = self.builder.createStore(func_value, func_ptr_ptr)
      Some(closure_ptr)
    }
    Ident(name) => self.get_value_by_name_or_load(name) |> Some
    String(s) => {
      let s = self.builder.createGlobalString(s, name="str_lit_\{self.str_cnt}")
      self.str_cnt += 1
      Some(s)
    }
    Binary(bin_op, left_name, right_name) => {
      let lhs_value = self.get_value_by_name_or_load(left_name)
      let rhs_value = self.get_value_by_name_or_load(right_name)
      let is_fp_ty = lhs_value.getType().isIEEELikeFPTy()
      let v = match (bin_op, is_fp_ty) {
        (Add, false) => self.builder.createAdd(lhs_value, rhs_value)
        (Add, true) => self.builder.createFAdd(lhs_value, rhs_value)
        (Sub, false) => self.builder.createSub(lhs_value, rhs_value)
        (Sub, true) => self.builder.createFSub(lhs_value, rhs_value)
        (Mul, false) => self.builder.createMul(lhs_value, rhs_value)
        (Mul, true) => self.builder.createFMul(lhs_value, rhs_value)
        (Div, false) => self.builder.createSDiv(lhs_value, rhs_value)
        (Div, true) => self.builder.createFDiv(lhs_value, rhs_value)
        (Mod, false) => self.builder.createSRem(lhs_value, rhs_value)
        (Mod, true) => self.builder.createFRem(lhs_value, rhs_value)
        (Eq, false) => self.builder.createICmpEQ(lhs_value, rhs_value)
        (Eq, true) => self.builder.createFCmpOEQ(lhs_value, rhs_value)
        (NE, false) => self.builder.createICmpNE(lhs_value, rhs_value)
        (NE, true) => self.builder.createFCmpONE(lhs_value, rhs_value)
        (LT, false) => self.builder.createICmpSLT(lhs_value, rhs_value)
        (LT, true) => self.builder.createFCmpOLT(lhs_value, rhs_value)
        (LE, false) => self.builder.createICmpSLE(lhs_value, rhs_value)
        (LE, true) => self.builder.createFCmpOLE(lhs_value, rhs_value)
        (GT, false) => self.builder.createICmpSGT(lhs_value, rhs_value)
        (GT, true) => self.builder.createFCmpOGT(lhs_value, rhs_value)
        (GE, false) => self.builder.createICmpSGE(lhs_value, rhs_value)
        (GE, true) => self.builder.createFCmpOGE(lhs_value, rhs_value)
        (And, false) => self.builder.createAnd(lhs_value, rhs_value)
        (Or, false) => self.builder.createOr(lhs_value, rhs_value)
        (BitAnd, false) => self.builder.createAnd(lhs_value, rhs_value)
        (BitOr, false) => self.builder.createOr(lhs_value, rhs_value)
        (ShiftLeft, false) => self.builder.createShl(lhs_value, rhs_value)
        (ShiftRight, false) => self.builder.createAShr(lhs_value, rhs_value)
        (op, _) =>
          raise CodegenError(
            "Unsupported binary operation \{op} in codegen, type is \{lhs_value.getType()}",
          )
      }
      Some(v)
    }
    Neg(name) => {
      let value = self.get_value_by_name_or_load(name)
      let v = if value.getType().isIEEELikeFPTy() {
        self.builder.createFNeg(value)
      } else {
        let zero = self.llvm_ctx.getConstInt32(0)
        self.builder.createSub(zero, value)
      }
      Some(v)
    }
    Not(name) => {
      let value = self.get_value_by_name_or_load(name)
      let one = self.llvm_ctx.getConstTrue()
      let v = self.builder.createXor(one, value)
      Some(v)
    }
    // Use `make_int_array`, 
    //     `make_double_array`, 
    //     `make_bool_array`, or
    //     `make_ptr_array`
    ArrayMake(size_name, init_name) => {
      // For top-level functions, we need to create a closure first
      let init_value : &@llvm.Value = if self.is_top_level_function(init_name) {
        guard self.functions.get(init_name.to_string()) is Some(func_value) else {
          raise CodegenError(
            "Failed to get function value for top-level function \{init_name}",
          )
        }
        let ptrty = self.llvm_ctx.getPtrTy()
        let zero = self.llvm_ctx.getConstInt32(0)
        // Create closure struct with only function pointer (no captured vars)
        let closure_struct_ty = self.llvm_ctx.getStructType([ptrty])
        let mbt_malloc = self.get_builtin_function("moonbit_malloc")
        let closure_size = self.llvm_mod
          .getDataLayout()
          .getTypeAllocSize(closure_struct_ty)
        let closure_size = self.llvm_ctx.getConstInt32(closure_size)
        let closure_ptr = self.builder.createCall(mbt_malloc, [closure_size])
        // Set function pointer in the first field
        let func_ptr_ptr = self.builder.createGEP(
          closure_ptr,
          closure_struct_ty,
          [zero, zero],
        )
        let _ = self.builder.createStore(func_value, func_ptr_ptr)
        (closure_ptr : &@llvm.Value)
      } else {
        self.get_value_by_name_or_load(init_name)
      }
      let size_value = self.get_value_by_name_or_load(size_name)
      guard self.get_knf_type_by_name(init_name) is Some(init_knf_ty) else {
        raise CodegenError(
          "Failed to get KNF type by name \{init_name} for array init value",
        )
      }
      let v = match init_knf_ty {
        Int => {
          let make_int_array_func = self.get_builtin_function("make_int_array")
          self.builder.createCall(make_int_array_func, [size_value, init_value])
        }
        Bool => {
          let make_bool_array_func = self.get_builtin_function(
            "make_bool_array",
          )
          self.builder.createCall(make_bool_array_func, [size_value, init_value])
        }
        Double => {
          let make_double_array_func = self.get_builtin_function(
            "make_double_array",
          )
          self.builder.createCall(make_double_array_func, [
            size_value, init_value,
          ])
        }
        _ => {
          // For all other types (functions, structs, tuples, etc.), use make_ptr_array
          let make_ptr_array_func = self.get_builtin_function("make_ptr_array")
          self.builder.createCall(make_ptr_array_func, [size_value, init_value])
        }
      }
      Some(v)
    }
    ArrayAccess(arr_name, idx_name) => {
      let array_value = self.get_value_by_name_or_load(arr_name)
      let index_value = self.get_value_by_name_or_load(idx_name)
      guard self.get_knf_type_by_name(arr_name) is Some(array_knf_type) else {
        raise CodegenError(
          "Failed to get KNF type by name \{arr_name} for array access",
        )
      }
      match array_knf_type {
        Array(Int) => {
          let array_int_get = self.get_builtin_function("array_int_get")
          let v = self.builder.createCall(array_int_get, [
            array_value, index_value,
          ])
          Some(v)
        }
        Array(Bool) => {
          let array_bool_get = self.get_builtin_function("array_bool_get")
          let v = self.builder.createCall(array_bool_get, [
            array_value, index_value,
          ])
          Some(v)
        }
        Array(Double) => {
          let array_double_get = self.get_builtin_function("array_double_get")
          let v = self.builder.createCall(array_double_get, [
            array_value, index_value,
          ])
          Some(v)
        }
        Array(_) => {
          let array_ptr_get = self.get_builtin_function("array_ptr_get")
          let v = self.builder.createCall(array_ptr_get, [
            array_value, index_value,
          ])
          Some(v)
        }
        _ => raise CodegenError("Unsupported array element type in codegen")
      }
    }
    Block(block) => self.block_codegen(block)
    If(cond, then_block, else_block) =>
      self.if_codegen(cond, then_block, else_block)
    FieldAccess(struct_name, field_str) => {
      let struct_value = self.get_value_by_name_or_load(struct_name)
      guard self.get_knf_type_by_name(struct_name) is Some(struct_knf_type) else {
        raise CodegenError(
          "Failed to get KNF type by name \{struct_name} for field access",
        )
      }
      guard struct_knf_type is Struct(struct_name_str)
      guard self.knf_struct_types.get(struct_name_str) is Some(knf_struct_def) else {
        raise CodegenError(
          "Failed to get KNF struct definition for \{struct_name_str}",
        )
      }
      guard self.struct_types.get(struct_name_str) is Some(struct_ty) else {
        raise CodegenError(
          "Failed to get LLVM struct type for \{struct_name_str}",
        )
      }
      guard knf_struct_def.get_field_index(field_str) is Some(field_index) else {
        raise CodegenError(
          "Failed to get field index for field \{field_str} in struct \{struct_name_str}",
        )
      }
      let zero = self.llvm_ctx.getConstInt32(0)
      let field_index_val = self.llvm_ctx.getConstInt32(field_index)
      let field_ptr = self.builder.createGEP(struct_value, struct_ty, [
        zero, field_index_val,
      ])
      guard knf_struct_def.get_field_index(field_str) is Some(field_index) else {
        raise CodegenError(
          "Failed to get field index for field \{field_str} in struct \{struct_name_str}",
        )
      }
      let (_, _, field_ty) = knf_struct_def.fields[field_index]
      let field_llvm_ty = self.type_codegen_opaque(field_ty)
      let v = self.builder.createLoad(field_llvm_ty, field_ptr)
      Some(v)
    }
    // use `make_int_array`
    ArrayLiteral(Int, elements) => {
      let elem_values = elements.map(e => self.get_value_by_name_or_load(e))
      let array_size = self.llvm_ctx.getConstInt32(elem_values.length())
      let make_int_array_func = self.get_builtin_function("make_int_array")
      let init_value = self.llvm_ctx.getConstInt32(0)
      let v = self.builder.createCall(make_int_array_func, [
        array_size, init_value,
      ])
      let array_put = self.get_builtin_function("array_int_put")
      for i, elem_value in elem_values {
        let index_value = self.llvm_ctx.getConstInt32(i)
        let _ = self.builder.createCall(array_put, [v, index_value, elem_value])

      }
      Some(v)
    }
    // use `make_bool_array`
    ArrayLiteral(Bool, elements) => {
      let elem_values = elements.map(e => self.get_value_by_name_or_load(e))
      let array_size = self.llvm_ctx.getConstInt32(elem_values.length())
      let make_bool_array_func = self.get_builtin_function("make_bool_array")
      let init_value = self.llvm_ctx.getConstFalse()
      let v = self.builder.createCall(make_bool_array_func, [
        array_size, init_value,
      ])
      let array_put = self.get_builtin_function("array_bool_put")
      for i, elem_value in elem_values {
        let index_value = self.llvm_ctx.getConstInt32(i)
        let _ = self.builder.createCall(array_put, [v, index_value, elem_value])

      }
      Some(v)
    }
    // use `make_double_array`
    ArrayLiteral(Double, elements) => {
      let elem_values = elements.map(e => self.get_value_by_name_or_load(e))
      let array_size = self.llvm_ctx.getConstInt32(elem_values.length())
      let make_double_array_func = self.get_builtin_function(
        "make_double_array",
      )
      let init_value = self.llvm_ctx.getConstDouble(0.0)
      let v = self.builder.createCall(make_double_array_func, [
        array_size, init_value,
      ])
      let array_put = self.get_builtin_function("array_double_put")
      for i, elem_value in elem_values {
        let index_value = self.llvm_ctx.getConstInt32(i)
        let _ = self.builder.createCall(array_put, [v, index_value, elem_value])

      }
      Some(v)
    }
    // use `make_ptr_array`
    ArrayLiteral(_, elements) => {
      let elem_values = elements.map(e => self.get_value_by_name_or_load(e))
      let array_size = self.llvm_ctx.getConstInt32(elem_values.length())
      let make_ptr_array_func = self.get_builtin_function("make_ptr_array")
      let init_value = self.llvm_ctx.getConstPointerNull(
        self.llvm_ctx.getInt32Ty(),
      )
      let v = self.builder.createCall(make_ptr_array_func, [
        array_size, init_value,
      ])
      let array_put = self.get_builtin_function("array_ptr_put")
      for i, elem_value in elem_values {
        let index_value = self.llvm_ctx.getConstInt32(i)
        let _ = self.builder.createCall(array_put, [v, index_value, elem_value])

      }
      Some(v)
    }
    CreateStruct(struct_name, field_inits) => {
      guard self.knf_struct_types.get(struct_name) is Some(knf_struct_def) else {
        raise CodegenError(
          "Failed to get KNF struct definition for \{struct_name}",
        )
      }
      guard self.struct_types.get(struct_name) is Some(struct_ty) else {
        raise CodegenError("Failed to get LLVM struct type for \{struct_name}")
      }
      let data_layout = self.llvm_mod.getDataLayout()
      let struct_size = data_layout.getTypeAllocSize(struct_ty)
      let struct_size = self.llvm_ctx.getConstInt32(struct_size)
      let malloc_func = self.get_builtin_function("moonbit_malloc")
      let struct_ptr = self.builder.createCall(malloc_func, [struct_size])
      for field_init in field_inits {
        let (field_name, field_value_name) = field_init
        guard knf_struct_def.get_field_index(field_name) is Some(field_index) else {
          raise CodegenError(
            "Failed to get field index for field \{field_name} in struct \{struct_name}",
          )
        }
        let field_value = self.get_value_by_name_or_load(field_value_name)
        let zero = self.llvm_ctx.getConstInt32(0)
        let field_index_val = self.llvm_ctx.getConstInt32(field_index)
        let field_ptr = self.builder.createGEP(struct_ptr, struct_ty, [
          zero, field_index_val,
        ])
        let _ = self.builder.createStore(field_value, field_ptr)

      }
      Some(struct_ptr)
    }
    TupleLiteral(elem_names) => {
      let elem_values = elem_names.map(e => self.get_value_by_name_or_load(e))
      let tuple_ty = self.llvm_ctx.getStructType(
        elem_values.map(v => v.getType()),
      )
      let data_layout = self.llvm_mod.getDataLayout()
      let struct_size = data_layout.getTypeAllocSize(tuple_ty)
      let struct_size = self.llvm_ctx.getConstInt32(struct_size)
      let malloc_func = self.get_builtin_function("moonbit_malloc")
      let tuple_ptr = self.builder.createCall(malloc_func, [struct_size])
      for i, elem_value in elem_values {
        let zero = self.llvm_ctx.getConstInt32(0)
        let field_index_val = self.llvm_ctx.getConstInt32(i)
        let field_ptr = self.builder.createGEP(tuple_ptr, tuple_ty, [
          zero, field_index_val,
        ])
        let _ = self.builder.createStore(elem_value, field_ptr)

      }
      Some(tuple_ptr)
    }
    TupleAccess(tuple_name, index) => {
      let tuple_value = self.get_value_by_name_or_load(tuple_name)
      guard self.get_knf_type_by_name(tuple_name) is Some(tuple_knf_type) else {
        raise CodegenError(
          "Failed to get KNF type by name \{tuple_name} for tuple access",
        )
      }
      let tuple_ty = self.type_codegen_concrete(tuple_knf_type)
      guard tuple_knf_type is Tuple(elem_types)
      guard elem_types.get(index) is Some(elem_type) else {
        raise CodegenError(
          "Tuple index \{index} out of bounds for tuple type \{tuple_knf_type}",
        )
      }
      let elem_llvm_type = self.type_codegen_opaque(elem_type)
      let zero = self.llvm_ctx.getConstInt32(0)
      let index_val = self.llvm_ctx.getConstInt32(index)
      let elem_ptr = self.builder.createGEP(tuple_value, tuple_ty, [
        zero, index_val,
      ])
      let v = self.builder.createLoad(elem_llvm_type, elem_ptr)
      Some(v)
    }
    // Note: all funcs defined in our program are handled in closure conversion
    // which means the function is actually a struct with the first field being
    // a function pointer and the rest being the closure environment.
    // when we call, we get the function pointer from the struct,
    // push the struct pointer as the first argument, then the rest arguments.
    Call(fname, arg_names) if self.is_top_level_function(fname) => {
      guard self.functions.get(fname.to_string()) is Some(func_value) else {
        raise CodegenError(
          "Failed to get function value for top-level function \{fname}",
        )
      }
      let ptr_null = self.llvm_ctx.getConstPointerNull(self.llvm_ctx.getPtrTy())
      let arg_values = arg_names.map(n => self.get_value_by_name_or_load(n))
      let all_args : Array[&@llvm.Value] = Array::new()
      all_args..push(ptr_null)..append(arg_values)
      let v = self.builder.createCall(func_value, all_args)
      Some(v)
    }
    // In this case, fname is a closure struct, the first field is the function pointer
    Call(fname, arg_names) if self.is_local_name(fname) => {
      let ptrty = self.llvm_ctx.getPtrTy()
      guard self.get_knf_type_by_name(fname) is Some(fname_knf_type) else {
        raise CodegenError(
          "Failed to get KNF type by name \{fname} for closure call",
        )
      }
      guard fname_knf_type is Function(arg_types, ret_ty) else {
        raise CodegenError("Expected function type for closure call")
      }
      let arg_typs : Array[&@llvm.Type] = [ptrty] // first arg is closure struct ptr
      for t in arg_types {
        let llvm_ty = match t {
          Unit => (self.llvm_ctx.getPtrTy() : &@llvm.Type)
          _ => self.type_codegen_opaque(t)
        }
        arg_typs.push(llvm_ty)
      }
      let ret_ty = self.type_codegen_opaque(ret_ty)
      let func_ty = self.llvm_ctx.getFunctionType(ret_ty, arg_typs)
      let closure_struct_value = self.get_value_by_name_or_load(fname)
      let zero = self.llvm_ctx.getConstInt32(0)
      let closure_struct_ty = self.llvm_ctx.getStructType([ptrty])
      let func_ptr_ptr = self.builder.createGEP(
        closure_struct_value,
        closure_struct_ty,
        [zero, zero],
      )
      let func_ptr = self.builder.createLoad(ptrty, func_ptr_ptr)
      let arg_values = arg_names.map(n => self.get_value_by_name_or_load(n))
      let all_args : Array[&@llvm.Value] = Array::new()
      all_args..push(closure_struct_value)..append(arg_values)
      let v = self.builder.createCallPtr(func_ptr, func_ty, all_args)
      Some(v)
    }
    // For extern function calls, just call directly
    Call(fname, arg_names) if self.is_extern_name(fname) => {
      let func_value = self.get_extern_function(fname.to_string())
      let arg_values = arg_names.map(n => self.get_value_by_name_or_load(n))
      let v = self.builder.createCall(func_value, arg_values)
      Some(v)
    }
    Call(fname, arg_names) if self.is_builtin_name(fname) => {
      let func_value = self.get_builtin_function(fname.to_string())
      let arg_values = arg_names.map(n => self.get_value_by_name_or_load(n))
      let v = self.builder.createCall(func_value, arg_values)
      Some(v)
    }
    e => raise CodegenError("Unsupported expression in codegen: \{e}")
  }
}
