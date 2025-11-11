///|
pub(all) suberror CodegenError String derive(Show)

///|
pub struct Context {
  llvm_ctx : @llvm.Context
  llvm_mod : @llvm.Module
  builder : @llvm.IRBuilder
  mut str_cnt : Int
  struct_types : Map[String, @llvm.StructType]
  knf_struct_types : Map[String, @knf.KnfStructDef]
  functions : Map[String, @llvm.Function]
  function_types : Map[String, @knf.Type]
  mut name_values : Map[@knf.Name, &@llvm.Value]
  mut name_types : Map[@knf.Name, @knf.Type]
  global_values : Map[String, &@llvm.GlobalValue]
  global_consts : Map[String, &@llvm.Constant]
  global_types : Map[String, @knf.Type]
  global_array_inits : Array[(@knf.Name, @knf.Type, @knf.KnfExpr)]
  builtin_funcs : Map[String, @llvm.Function]
  builtin_func_tys : Map[String, @llvm.FunctionType]
  extern_funcs : Map[String, @llvm.Function]
}

///|
pub fn Context::new(mod_name : String) -> Context {
  let llvm_ctx = @llvm.Context::new()
  let llvm_mod = llvm_ctx.addModule(mod_name)
  let builder = llvm_ctx.createBuilder()
  let i32ty = llvm_ctx.getInt32Ty()
  let i64ty = llvm_ctx.getInt64Ty()
  let i8ty = llvm_ctx.getInt8Ty()
  let doublety = llvm_ctx.getDoubleTy()
  let floatty = llvm_ctx.getFloatTy()
  let boolty = llvm_ctx.getInt1Ty()
  let ptrty = llvm_ctx.getPtrTy()
  let voidty = llvm_ctx.getVoidTy()
  let moonbit_malloc_ty = try! llvm_ctx.getFunctionType(ptrty, [i32ty])
  // Add `make_int_array_ty, make_int_array`: (Int, Int) -> Ptr
  // Add `make_double_array_ty, make_double_array`: (Int, Double) -> Ptr
  // Add `make_bool_array_ty, make_bool_array`: (Int, Bool) -> Ptr
  // Add `make_ptr_array_ty, make_ptr_array`: (Int, Ptr) -> Ptr
  let make_int_array_ty = try! llvm_ctx.getFunctionType(ptrty, [i32ty, i32ty])
  let make_int64_array_ty = try! llvm_ctx.getFunctionType(ptrty, [i32ty, i64ty])
  let make_uint_array_ty = try! llvm_ctx.getFunctionType(ptrty, [i32ty, i32ty])
  let make_uint64_array_ty = try! llvm_ctx.getFunctionType(ptrty, [i32ty, i64ty])
  let make_double_array_ty = try! llvm_ctx.getFunctionType(ptrty, [
      i32ty, doublety,
    ])
  let make_float_array_ty = try! llvm_ctx.getFunctionType(ptrty, [i32ty, floatty])
  let make_bool_array_ty = try! llvm_ctx.getFunctionType(ptrty, [i32ty, boolty])
  let make_char_array_ty = try! llvm_ctx.getFunctionType(ptrty, [i32ty, i8ty])
  let make_ptr_array_ty = try! llvm_ctx.getFunctionType(ptrty, [i32ty, ptrty])
  let get_array_length_ty = try! llvm_ctx.getFunctionType(i32ty, [ptrty])
  let array_int_push_ty = try! llvm_ctx.getFunctionType(llvm_ctx.getVoidTy(), [
      ptrty, i32ty,
    ])
  let array_int64_push_ty = try! llvm_ctx.getFunctionType(llvm_ctx.getVoidTy(), [
      ptrty, i64ty,
    ])
  let array_uint_push_ty = try! llvm_ctx.getFunctionType(llvm_ctx.getVoidTy(), [
      ptrty, i32ty,
    ])
  let array_uint64_push_ty = try! llvm_ctx.getFunctionType(llvm_ctx.getVoidTy(), [
      ptrty, i64ty,
    ])
  let array_double_push_ty = try! llvm_ctx.getFunctionType(
      llvm_ctx.getVoidTy(),
      [ptrty, doublety],
    )
  let array_float_push_ty = try! llvm_ctx.getFunctionType(llvm_ctx.getVoidTy(), [
      ptrty, floatty,
    ])
  let array_bool_push_ty = try! llvm_ctx.getFunctionType(llvm_ctx.getVoidTy(), [
      ptrty, boolty,
    ])
  let array_char_push_ty = try! llvm_ctx.getFunctionType(llvm_ctx.getVoidTy(), [
      ptrty, i8ty,
    ])
  let array_ptr_push_ty = try! llvm_ctx.getFunctionType(llvm_ctx.getVoidTy(), [
      ptrty, ptrty,
    ])
  let array_int_get_ty = try! llvm_ctx.getFunctionType(i32ty, [ptrty, i32ty])
  let array_int64_get_ty = try! llvm_ctx.getFunctionType(i64ty, [ptrty, i32ty])
  let array_uint_get_ty = try! llvm_ctx.getFunctionType(i32ty, [ptrty, i32ty])
  let array_uint64_get_ty = try! llvm_ctx.getFunctionType(i64ty, [ptrty, i32ty])
  let array_double_get_ty = try! llvm_ctx.getFunctionType(doublety, [
      ptrty, i32ty,
    ])
  let array_float_get_ty = try! llvm_ctx.getFunctionType(floatty, [ptrty, i32ty])
  let array_bool_get_ty = try! llvm_ctx.getFunctionType(boolty, [ptrty, i32ty])
  let array_char_get_ty = try! llvm_ctx.getFunctionType(i8ty, [ptrty, i32ty])
  let array_ptr_get_ty = try! llvm_ctx.getFunctionType(ptrty, [ptrty, i32ty])
  let array_int_put_ty = try! llvm_ctx.getFunctionType(voidty, [
      ptrty, i32ty, i32ty,
    ])
  let array_int64_put_ty = try! llvm_ctx.getFunctionType(voidty, [
      ptrty, i32ty, i64ty,
    ])
  let array_uint_put_ty = try! llvm_ctx.getFunctionType(voidty, [
      ptrty, i32ty, i32ty,
    ])
  let array_uint64_put_ty = try! llvm_ctx.getFunctionType(voidty, [
      ptrty, i32ty, i64ty,
    ])
  let array_double_put_ty = try! llvm_ctx.getFunctionType(voidty, [
      ptrty, i32ty, doublety,
    ])
  let array_float_put_ty = try! llvm_ctx.getFunctionType(voidty, [
      ptrty, i32ty, floatty,
    ])
  let array_bool_put_ty = try! llvm_ctx.getFunctionType(voidty, [
      ptrty, i32ty, boolty,
    ])
  let array_char_put_ty = try! llvm_ctx.getFunctionType(voidty, [
      ptrty, i32ty, i8ty,
    ])
  let array_ptr_put_ty = try! llvm_ctx.getFunctionType(voidty, [
      ptrty, i32ty, ptrty,
    ])
  let int_of_float_ty = try! llvm_ctx.getFunctionType(i32ty, [doublety])
  let float_of_int_ty = try! llvm_ctx.getFunctionType(doublety, [i32ty])
  let builtin_print_int_ty = try! llvm_ctx.getFunctionType(voidty, [i32ty])
  let builtin_print_int64_ty = try! llvm_ctx.getFunctionType(voidty, [i64ty])
  let builtin_print_uint_ty = try! llvm_ctx.getFunctionType(voidty, [i32ty])
  let builtin_print_uint64_ty = try! llvm_ctx.getFunctionType(voidty, [i64ty])
  let builtin_print_double_ty = try! llvm_ctx.getFunctionType(voidty, [doublety])
  let builtin_print_float_ty = try! llvm_ctx.getFunctionType(voidty, [floatty])
  let builtin_print_char_ty = try! llvm_ctx.getFunctionType(voidty, [i8ty])
  let builtin_print_bool_ty = try! llvm_ctx.getFunctionType(voidty, [boolty])
  let builtin_print_string_ty = try! llvm_ctx.getFunctionType(voidty, [ptrty])
  let builtin_println_int_ty = try! llvm_ctx.getFunctionType(voidty, [i32ty])
  let builtin_println_int64_ty = try! llvm_ctx.getFunctionType(voidty, [i64ty])
  let builtin_println_uint_ty = try! llvm_ctx.getFunctionType(voidty, [i32ty])
  let builtin_println_uint64_ty = try! llvm_ctx.getFunctionType(voidty, [i64ty])
  let builtin_println_double_ty = try! llvm_ctx.getFunctionType(voidty, [
      doublety,
    ])
  let builtin_println_float_ty = try! llvm_ctx.getFunctionType(voidty, [floatty])
  let builtin_println_char_ty = try! llvm_ctx.getFunctionType(voidty, [i8ty])
  let builtin_println_bool_ty = try! llvm_ctx.getFunctionType(voidty, [boolty])
  let builtin_println_string_ty = try! llvm_ctx.getFunctionType(voidty, [ptrty])
  // String related functions
  let builtin_create_string_ty = try! llvm_ctx.getFunctionType(ptrty, [ptrty])
  let builtin_get_string_length_ty = try! llvm_ctx.getFunctionType(i32ty, [ptrty])
  let builtin_string_concat_ty = try! llvm_ctx.getFunctionType(ptrty, [ptrty, ptrty])
  let builtin_get_char_in_string_ty = try! llvm_ctx.getFunctionType(i8ty, [ptrty, i32ty])
  let moonbit_string_eq_ty = try! llvm_ctx.getFunctionType(boolty, [ptrty, ptrty])
  // Type conversion to string functions
  let builtin_int_to_string_ty = try! llvm_ctx.getFunctionType(ptrty, [i32ty])
  let builtin_int64_to_string_ty = try! llvm_ctx.getFunctionType(ptrty, [i64ty])
  let builtin_uint_to_string_ty = try! llvm_ctx.getFunctionType(ptrty, [i32ty])
  let builtin_uint64_to_string_ty = try! llvm_ctx.getFunctionType(ptrty, [i64ty])
  let builtin_float_to_string_ty = try! llvm_ctx.getFunctionType(ptrty, [floatty])
  let builtin_double_to_string_ty = try! llvm_ctx.getFunctionType(ptrty, [doublety])
  let builtin_char_to_string_ty = try! llvm_ctx.getFunctionType(ptrty, [i8ty])
  let builtin_func_tys = {
    "moonbit_malloc": moonbit_malloc_ty,
    "make_int_array": make_int_array_ty,
    "make_int64_array": make_int64_array_ty,
    "make_uint_array": make_uint_array_ty,
    "make_uint64_array": make_uint64_array_ty,
    "make_double_array": make_double_array_ty,
    "make_float_array": make_float_array_ty,
    "make_bool_array": make_bool_array_ty,
    "make_char_array": make_char_array_ty,
    "make_ptr_array": make_ptr_array_ty,
    "get_array_length": get_array_length_ty,
    "array_int_push": array_int_push_ty,
    "array_int64_push": array_int64_push_ty,
    "array_uint_push": array_uint_push_ty,
    "array_uint64_push": array_uint64_push_ty,
    "array_double_push": array_double_push_ty,
    "array_float_push": array_float_push_ty,
    "array_bool_push": array_bool_push_ty,
    "array_char_push": array_char_push_ty,
    "array_ptr_push": array_ptr_push_ty,
    "array_int_get": array_int_get_ty,
    "array_int64_get": array_int64_get_ty,
    "array_uint_get": array_uint_get_ty,
    "array_uint64_get": array_uint64_get_ty,
    "array_double_get": array_double_get_ty,
    "array_float_get": array_float_get_ty,
    "array_bool_get": array_bool_get_ty,
    "array_char_get": array_char_get_ty,
    "array_ptr_get": array_ptr_get_ty,
    "array_int_put": array_int_put_ty,
    "array_int64_put": array_int64_put_ty,
    "array_uint_put": array_uint_put_ty,
    "array_uint64_put": array_uint64_put_ty,
    "array_double_put": array_double_put_ty,
    "array_float_put": array_float_put_ty,
    "array_bool_put": array_bool_put_ty,
    "array_char_put": array_char_put_ty,
    "array_ptr_put": array_ptr_put_ty,
    "int_of_float": int_of_float_ty,
    "float_of_int": float_of_int_ty,
    "__builtin_print_int": builtin_print_int_ty,
    "__builtin_print_int64": builtin_print_int64_ty,
    "__builtin_print_uint": builtin_print_uint_ty,
    "__builtin_print_uint64": builtin_print_uint64_ty,
    "__builtin_print_double": builtin_print_double_ty,
    "__builtin_print_float": builtin_print_float_ty,
    "__builtin_print_char": builtin_print_char_ty,
    "__builtin_print_bool": builtin_print_bool_ty,
    "__builtin_print_string": builtin_print_string_ty,
    "__builtin_println_int": builtin_println_int_ty,
    "__builtin_println_int64": builtin_println_int64_ty,
    "__builtin_println_uint": builtin_println_uint_ty,
    "__builtin_println_uint64": builtin_println_uint64_ty,
    "__builtin_println_double": builtin_println_double_ty,
    "__builtin_println_float": builtin_println_float_ty,
    "__builtin_println_char": builtin_println_char_ty,
    "__builtin_println_bool": builtin_println_bool_ty,
    "__builtin_println_string": builtin_println_string_ty,
    "__builtin_create_string": builtin_create_string_ty,
    "__builtin_get_string_length": builtin_get_string_length_ty,
    "__builtin_string_concat": builtin_string_concat_ty,
    "__builtin_get_char_in_string": builtin_get_char_in_string_ty,
    "moonbit_string_eq": moonbit_string_eq_ty,
    "__builtin_int_to_string": builtin_int_to_string_ty,
    "__builtin_int64_to_string": builtin_int64_to_string_ty,
    "__builtin_uint_to_string": builtin_uint_to_string_ty,
    "__builtin_uint64_to_string": builtin_uint64_to_string_ty,
    "__builtin_float_to_string": builtin_float_to_string_ty,
    "__builtin_double_to_string": builtin_double_to_string_ty,
    "__builtin_char_to_string": builtin_char_to_string_ty,
  }
  let ctx = Context::{
    llvm_ctx,
    llvm_mod,
    builder,
    str_cnt: 0,
    struct_types: Map::new(),
    knf_struct_types: Map::new(),
    functions: Map::new(),
    function_types: Map::new(),
    name_values: Map::new(),
    name_types: Map::new(),
    builtin_funcs: Map::new(),
    builtin_func_tys,
    global_values: Map::new(),
    global_consts: Map::new(),
    global_types: Map::new(),
    global_array_inits: Array::new(),
    extern_funcs: Map::new(),
  }
  ctx.str_cnt += 1
  ctx
}

///|
pub fn Context::get_builtin_function(
  self : Context,
  name : String,
) -> @llvm.Function raise CodegenError {
  match self.builtin_func_tys.get(name) {
    Some(fty) =>
      match self.builtin_funcs.get(name) {
        Some(func) => func
        None => {
          let func = try! self.llvm_mod.addFunction(fty, name)
          self.builtin_funcs.set(name, func)
          func
        }
      }
    None => raise CodegenError("Builtin function \{name} not found")
  }
}

///|
pub fn Context::get_extern_function(
  self : Context,
  name : String,
) -> @llvm.Function raise CodegenError {
  match self.extern_funcs.get(name) {
    Some(func) => func
    None => raise CodegenError("Extern function \{name} not found")
  }
}

///|
fn Context::is_builtin_name(self : Context, name : @knf.Name) -> Bool {
  self.builtin_func_tys.get(name.to_string()) is Some(_)
}

///|
fn Context::is_extern_name(self : Context, name : @knf.Name) -> Bool {
  self.extern_funcs.get(name.to_string()) is Some(_)
}

///|
/// Generate a closure wrapper for top level functions
/// For example, for function `foo: (Int) -> Int`, 
/// we generate a wrapper function that accepts an environment pointer
/// and forwards the call to the actual top level function.
pub fn Context::generate_top_level_function_closure(
  self : Context,
  name : @knf.Name,
) -> &@llvm.Value raise CodegenError {
  let func_name = name.to_string()
  guard self.functions.get(func_name) is Some(func_value) else {
    raise CodegenError("Top level function not found for \{func_name}")
  }
  let func_ty = func_value.getFunctionType()

  // Create wrapper function name
  let wrapper_name = "\{func_name}$closure"

  // Check if wrapper already exists
  match self.functions.get(wrapper_name) {
    Some(existing_wrapper) => {
      // Wrapper already exists, just create and return the closure struct
      let ptrty = self.llvm_ctx.getPtrTy()
      let zero = self.llvm_ctx.getConstInt32(0)
      let closure_struct_ty = try! self.llvm_ctx.getStructType([ptrty])
      let mbt_malloc = self.get_builtin_function("moonbit_malloc")
      let closure_size = self.llvm_mod
        .getDataLayout()
        .getTypeAllocSize(closure_struct_ty)
      let closure_size = self.llvm_ctx.getConstInt32(closure_size)
      let closure_ptr = try! self.builder.createCall(mbt_malloc, [closure_size])
      let func_ptr_ptr = try! self.builder.createGEP(
          closure_ptr,
          closure_struct_ty,
          [zero, zero],
        )
      let _ = try! self.builder.createStore(existing_wrapper, func_ptr_ptr)
      return closure_ptr
    }
    None => {
      // Need to create the wrapper function
      let ptrty = self.llvm_ctx.getPtrTy()

      // Build wrapper function type: add env pointer as first parameter
      let orig_param_types = func_ty.getParamTypes()
      let wrapper_param_types : Array[&@llvm.Type] = Array::new()
      wrapper_param_types.push(ptrty) // env pointer
      wrapper_param_types.append(orig_param_types)
      let ret_ty = func_ty.getReturnType()
      let wrapper_func_ty = try! self.llvm_ctx.getFunctionType(
          ret_ty, wrapper_param_types,
        )

      // Create wrapper function
      let wrapper_func = try! self.llvm_mod.addFunction(
          wrapper_func_ty, wrapper_name,
        )
      self.functions.set(wrapper_name, wrapper_func)

      // Save current insert block
      let current_insert_block = self.builder.getInsertBlock()

      // Generate wrapper function body
      let entry_bb = wrapper_func.addBasicBlock(name="entry")
      self.builder.setInsertPoint(entry_bb)

      // Forward all arguments except the first (env pointer) to the top level function
      let args : Array[&@llvm.Value] = Array::new()
      for i = 1; i < wrapper_param_types.length(); i = i + 1 {
        guard wrapper_func.getArg(i) is Some(arg) else {
          raise CodegenError("Failed to get argument \{i} for wrapper function")
        }
        args.push(arg)
      }

      // Call the top level function
      let result = try! self.builder.createCall(func_value, args)

      // Return
      let ret_ty_enum = ret_ty.asTypeEnum()
      if ret_ty_enum is VoidType(_) {
        let _ = try! self.builder.createRetVoid()

      } else {
        let _ = try! self.builder.createRet(result)

      }

      // Restore insert block
      self.builder.setInsertPoint(current_insert_block)

      // Now create the closure struct
      let zero = self.llvm_ctx.getConstInt32(0)
      let closure_struct_ty = try! self.llvm_ctx.getStructType([ptrty])
      let mbt_malloc = self.get_builtin_function("moonbit_malloc")
      let closure_size = self.llvm_mod
        .getDataLayout()
        .getTypeAllocSize(closure_struct_ty)
      let closure_size = self.llvm_ctx.getConstInt32(closure_size)
      let closure_ptr = try! self.builder.createCall(mbt_malloc, [closure_size])
      let func_ptr_ptr = try! self.builder.createGEP(
          closure_ptr,
          closure_struct_ty,
          [zero, zero],
        )
      let _ = try! self.builder.createStore(wrapper_func, func_ptr_ptr)
      return closure_ptr
    }
  }
}

///|
/// Generate a closure wrapper for extern functions
/// For example, for extern function `print_int: (Int) -> Unit`, 
/// we generate a wrapper function that accepts an environment pointer
/// and forwards the call to the actual builtin function.
pub fn Context::generate_extern_or_builtin_closure(
  self : Context,
  name : @knf.Name,
) -> &@llvm.Value raise CodegenError {
  let func_name = name.to_string()
  let func_value = if self.is_builtin_name(name) {
    self.get_builtin_function(func_name)
  } else {
    guard self.extern_funcs.get(func_name) is Some(extern_func) else {
      raise CodegenError("Extern function not found for \{func_name}")
    }
    extern_func
  }
  let func_ty = func_value.getFunctionType()

  // Create wrapper function name
  let wrapper_name = "\{func_name}$closure"

  // Check if wrapper already exists
  match self.functions.get(wrapper_name) {
    Some(existing_wrapper) => {
      // Wrapper already exists, just create and return the closure struct
      let ptrty = self.llvm_ctx.getPtrTy()
      let zero = self.llvm_ctx.getConstInt32(0)
      let closure_struct_ty = try! self.llvm_ctx.getStructType([ptrty])
      let mbt_malloc = self.get_builtin_function("moonbit_malloc")
      let closure_size = self.llvm_mod
        .getDataLayout()
        .getTypeAllocSize(closure_struct_ty)
      let closure_size = self.llvm_ctx.getConstInt32(closure_size)
      let closure_ptr = try! self.builder.createCall(mbt_malloc, [closure_size])
      let func_ptr_ptr = try! self.builder.createGEP(
          closure_ptr,
          closure_struct_ty,
          [zero, zero],
        )
      let _ = try! self.builder.createStore(existing_wrapper, func_ptr_ptr)
      return closure_ptr
    }
    None => {
      // Need to create the wrapper function
      let ptrty = self.llvm_ctx.getPtrTy()

      // Build wrapper function type: add env pointer as first parameter
      let orig_param_types = func_ty.getParamTypes()
      let wrapper_param_types : Array[&@llvm.Type] = Array::new()
      wrapper_param_types.push(ptrty) // env pointer
      wrapper_param_types.append(orig_param_types)
      let ret_ty = func_ty.getReturnType()
      let wrapper_func_ty = try! self.llvm_ctx.getFunctionType(
          ret_ty, wrapper_param_types,
        )

      // Create wrapper function
      let wrapper_func = try! self.llvm_mod.addFunction(
          wrapper_func_ty, wrapper_name,
        )
      self.functions.set(wrapper_name, wrapper_func)

      // Save current insert block
      let current_insert_block = self.builder.getInsertBlock()

      // Generate wrapper function body
      let entry_bb = wrapper_func.addBasicBlock(name="entry")
      self.builder.setInsertPoint(entry_bb)

      // Forward all arguments except the first (env pointer) to the extern function
      let args : Array[&@llvm.Value] = Array::new()
      for i = 1; i < wrapper_param_types.length(); i = i + 1 {
        guard wrapper_func.getArg(i) is Some(arg) else {
          raise CodegenError("Failed to get argument \{i} for wrapper function")
        }
        args.push(arg)
      }

      // Call the extern function
      let result = try! self.builder.createCall(func_value, args)

      // Return
      let ret_ty_enum = ret_ty.asTypeEnum()
      if ret_ty_enum is VoidType(_) {
        let _ = try! self.builder.createRetVoid()

      } else {
        let _ = try! self.builder.createRet(result)

      }

      // Restore insert block
      self.builder.setInsertPoint(current_insert_block)

      // Now create the closure struct
      let zero = self.llvm_ctx.getConstInt32(0)
      let closure_struct_ty = try! self.llvm_ctx.getStructType([ptrty])
      let mbt_malloc = self.get_builtin_function("moonbit_malloc")
      let closure_size = self.llvm_mod
        .getDataLayout()
        .getTypeAllocSize(closure_struct_ty)
      let closure_size = self.llvm_ctx.getConstInt32(closure_size)
      let closure_ptr = try! self.builder.createCall(mbt_malloc, [closure_size])
      let func_ptr_ptr = try! self.builder.createGEP(
          closure_ptr,
          closure_struct_ty,
          [zero, zero],
        )
      let _ = try! self.builder.createStore(wrapper_func, func_ptr_ptr)
      return closure_ptr
    }
  }
}

///|
pub fn Context::get_value_by_name(
  self : Context,
  name : @knf.Name,
) -> &@llvm.Value? {
  match self.name_values.get(name) {
    Some(value) => Some(value)
    None =>
      match self.functions.get(name.to_string()) {
        Some(func) => Some(func)
        None =>
          match self.builtin_funcs.get(name.to_string()) {
            Some(builtin) => Some(builtin)
            None => None
          }
      }
  }
}

///|
pub fn Context::get_knf_type_by_name(
  self : Context,
  name : @knf.Name,
) -> @knf.Type? {
  match self.name_types.get(name) {
    Some(ty) => Some(ty)
    None =>
      match self.function_types.get(name.to_string()) {
        Some(fty) => Some(fty)
        None =>
          match self.global_types.get(name.to_string()) {
            Some(gty) => Some(gty)
            None => None
          }
      }
  }
}

///|
pub fn Context::set_new_name_value(self : Context) -> Unit {
  let name_value = Map::new()
  self.name_values = name_value
}

///|
pub fn Context::set_new_name_knf_type(self : Context) -> Unit {
  let name_types = Map::new()
  self.name_types = name_types
}

///|
fn Context::is_top_level_function(self : Context, name : @knf.Name) -> Bool {
  self.functions.get(name.to_string()) is Some(_)
}

///|
fn Context::is_local_name(self : Context, name : @knf.Name) -> Bool {
  self.name_values.get(name) is Some(_)
}

///|
fn Context::get_value_by_name_or_load(
  self : Context,
  name : @knf.Name,
) -> &@llvm.Value raise {
  // Check if this is a builtin/extern function - if so, generate closure wrapper
  if self.is_extern_name(name) {
    return self.generate_extern_or_builtin_closure(name)
  }

  // Check if this is a top-level function - generate closure wrapper
  if self.is_top_level_function(name) {
    return self.generate_top_level_function_closure(name)
  }
  match self.get_value_by_name(name) {
    Some(v) =>
      if v.asValueEnum() is AllocaInst(alloca) {
        let knfty = match self.get_knf_type_by_name(name) {
          Some(t) => t
          None => raise CodegenError("Type not found for identifier in codegen")
        }
        let llvmty = self.type_codegen_opaque(knfty)
        self.builder.createLoad(llvmty, alloca)
      } else {
        v
      }
    None =>
      // Check global constants first
      match self.global_consts.get(name.to_string()) {
        Some(const_val) => (const_val : &@llvm.Value)
        None =>
          // Then check global variables
          match self.global_values.get(name.to_string()) {
            Some(gv) => {
              let knfty = match self.global_types.get(name.to_string()) {
                Some(t) => t
                None =>
                  raise CodegenError(
                    "Type not found for top let identifier \{name} in codegen",
                  )
              }
              let llvmty = self.type_codegen_opaque(knfty)
              self.builder.createLoad(llvmty, gv)
            }
            None =>
              raise CodegenError("Undefined identifier in codegen: \{name}")
          }
      }
  }
}
