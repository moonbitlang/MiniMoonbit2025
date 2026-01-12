///|
pub(all) suberror CodegenError { 
  CodegenError(String)
} derive(Show)

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
  mutable_captured_vars : Map[@knf.Name, Bool] // Track mutable captured variables
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
  let builtin_func_tys = get_builtin_functions(llvm_ctx)
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
    mutable_captured_vars: Map::new(),
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
      } else if self.mutable_captured_vars.contains(name) {
        // This is a mutable captured variable, v is a pointer, need to load
        let knfty = match self.get_knf_type_by_name(name) {
          Some(t) => t
          None => raise CodegenError("Type not found for identifier in codegen")
        }
        let llvmty = self.type_codegen_opaque(knfty)
        self.builder.createLoad(llvmty, v)
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
