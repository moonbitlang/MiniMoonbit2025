///|
pub(all) suberror TypeCheckError {
  TypeCheckError(String)
} derive(Show)

///|
pub(all) struct Env {
  local_ : Map[String, Type]
  parent : Env?
}

///|
pub fn Env::new(parent? : Env? = None) -> Env {
  Env::{ local_: Map::new(), parent }
}

///|
pub fn Env::get(self : Env, name : String) -> Type? {
  match self.local_.get(name) {
    Some(t) => Some(t)
    None =>
      match self.parent {
        Some(p) => p.get(name)
        None => None
      }
  }
}

///|
pub fn Env::set(self : Env, name : String, t : Type) -> Unit {
  self.local_.set(name, t)
}

///|
pub(all) struct Context {
  mut type_env : Env
  type_vars : Map[Int, TypeKind]
  struct_defs : Map[String, StructDef]
  enum_defs : Map[String, EnumDef]
  func_types : Map[String, TypeKind]
  mut current_func_ret_ty : TypeKind?
  priv mut error_happened : Bool
}

///|
pub fn Context::new() -> Context {
  let ctx = Context::{
    type_env: Env::new(),
    type_vars: Map::new(),
    struct_defs: Map::new(),
    enum_defs: Map::new(),
    func_types: Map::new(),
    current_func_ret_ty: None,
    error_happened: false,
  }
  ctx
}

///|
pub fn Context::set_error_happened(self : Context) -> Unit {
  self.error_happened = true
}

///|
pub fn Context::throw_(
  self : Self,
  tok : Token,
  msg : String,
  level : @lexer.ThrowLevel,
) -> Unit {
  @lexer.throw_(tok, msg, level)
  if level is Error {
    self.set_error_happened()
  }
}

///|
pub fn Context::has_error_happened(self : Context) -> Bool {
  self.error_happened
}

///|
pub fn Context::lookup_type(self : Context, name : String) -> Type? {
  if name is ("println" | "print") {
    let t = Type::{ kind: Function([Any], Unit), mutable: false }
    return Some(t)
  }
  // Handle builtin array/string methods
  if name == "get_array_length" {
    // Array.length() - takes any array type and returns Int
    return Some(Type::{ kind: Function([Any], Int), mutable: false })
  }
  if name == "__builtin_get_string_length" {
    return Some(Type::{ kind: Function([String], Int), mutable: false })
  }
  // Handle builtin array push methods
  if name.has_prefix("array_") && name.has_suffix("_push") {
    // array_int_push, array_double_push, etc. - takes (Array[T], T) and returns Unit
    return Some(Type::{ kind: Function([Any, Any], Unit), mutable: false })
  }
  // Handle builtin to_string functions
  if name.has_prefix("__builtin_") && name.has_suffix("_to_string") {
    return Some(Type::{ kind: Function([Any], String), mutable: false })
  }
  match self.type_env.get(name) {
    None => None
    Some({ kind, mutable }) => {
      let t = self.ensure_type(kind)
      // catch { _ => return None }
      let t = Type::{ kind: t, mutable }
      self.type_env.set(name, t)
      Some(t)
    }
  }
}

///|
pub fn Context::enter_scope(self : Self) -> Unit {
  let sub_env = Env::new(parent=Some(self.type_env))
  self.type_env = sub_env
}

///|
pub fn Context::exit_scope(self : Context) -> Unit {
  self.type_env = match self.type_env.parent {
    Some(p) => p
    None => self.type_env
  }
}

///|
pub fn Context::set_current_func_ret_ty(self : Context, ty : TypeKind) -> Unit {
  self.current_func_ret_ty = Some(ty)
}

///|
pub fn Context::add_type_var(self : Context) -> TypeKind {
  let new_id = self.type_vars.length()
  self.type_vars.set(new_id, TypeVar(new_id))
  TypeVar(new_id)
}

///|
pub(all) struct Program {
  source_file : String
  top_lets : Map[String, TopLet]
  top_functions : Map[String, TopFunction]
  extern_funcions : Map[String, ExternFunction]
  struct_defs : Map[String, StructDef]
  enum_defs : Map[String, EnumDef]
}

///|
pub fn Program::to_string(self : Self, color? : Bool = true) -> String {
  let sb = StringBuilder::new()
  for _, extern_fn in self.extern_funcions {
    sb.write_string(extern_fn.to_string(color~))
  }
  for _, struct_def in self.struct_defs {
    sb.write_string(struct_def.to_string(color~))
  }
  for _, enum_def in self.enum_defs {
    sb.write_string(enum_def.to_string(color~))
  }
  for _, top_let in self.top_lets {
    sb.write_string(top_let.to_string(color~))
  }
  for _, top_fn in self.top_functions {
    sb.write_string(top_fn.to_string(color~))
  }
  sb.to_string()
}

///|
pub impl Show for Program with output(self, logger) {
  logger.write_string(self.to_string(color=true))
}

///|
pub fn Context::check_program(
  self : Context,
  program : @parser.Program,
) -> Program raise TypeCheckError {
  self.collect_struct_or_enum_names(program)
  self.collect_function_types(program)
  let source_file = program.source_file
  let struct_defs = Map::new()
  let top_lets = Map::new()
  let top_functions = Map::new()
  let extern_funcions = Map::new()
  let enum_defs = Map::new()
  for name, ext_func in program.extern_funcions {
    let checked_ext_func = self.check_extern_function(ext_func)
    extern_funcions.set(name, checked_ext_func)
  }
  for name, struct_def in program.struct_defs {
    let check_struct_def = self.check_struct_def(struct_def)
    struct_defs.set(name, check_struct_def)
  }
  for name, enum_def in program.enum_defs {
    let checked_enum_def = self.check_enum_def(enum_def)
    enum_defs.set(name, checked_enum_def)
  }
  for name, top_let in program.top_lets {
    let checked_top_let = self.check_top_let(top_let)
    top_lets.set(name, checked_top_let)
  }
  for name, top_func in program.top_functions {
    let checked_top_func = self.check_top_function(top_func)
    top_functions.set(name, checked_top_func)
  }
  Program::{
    source_file,
    top_lets,
    top_functions,
    extern_funcions,
    struct_defs,
    enum_defs,
  }
}

///|
pub fn Context::collect_struct_or_enum_names(
  self : Context,
  program : @parser.Program,
) -> Unit raise TypeCheckError {
  for struct_def in program.struct_defs.values() {
    if self.struct_defs.contains(struct_def.name) ||
      self.enum_defs.contains(struct_def.name) {
      raise TypeCheckError("Duplicate struct name: \{struct_def.name}")
    } else {
      let struct_def = StructDef::{
        name: struct_def.name,
        fields: Array::new(),
        methods: Map::new(),
      }
      self.struct_defs.set(struct_def.name, struct_def)
    }
  }
  for enum_def in program.enum_defs.values() {
    if self.enum_defs.contains(enum_def.name) ||
      self.struct_defs.contains(enum_def.name) {
      raise TypeCheckError("Duplicate enum name: \{enum_def.name}")
    } else {
      let enum_def = EnumDef::{ name: enum_def.name, enum_fields: Array::new() }
      self.enum_defs.set(enum_def.name, enum_def)
    }
  }
}

///|
pub fn Context::collect_function_types(
  self : Context,
  program : @parser.Program,
) -> Unit raise TypeCheckError {
  for ext_func in program.extern_funcions.values() {
    if self.func_types.contains(ext_func.fname) {
      raise TypeCheckError("Duplicate function name: \{ext_func.fname}")
    } else {
      let param_types = Array::new()
      for param in ext_func.param_list {
        let { ty, .. } = param
        let ty = self.check_parser_type(ty)
        param_types.push(ty.kind)
      }
      let ret_ty = match ext_func.ret_ty {
        Some(ty) => self.check_parser_type(ty)
        None => Type::{ kind: Unit, mutable: false }
      }
      let fty = Function(param_types, ret_ty.kind)
      self.func_types.set(ext_func.fname, fty)
      self.type_env.set(ext_func.fname, Type::{ kind: fty, mutable: false })
    }
  }
  for func in program.top_functions.values() {
    let func_whole_name = func.whole_name()
    if self.func_types.contains(func_whole_name) {
      raise TypeCheckError(
        "Duplicate function name: \{func.typeTag}::\{func.fname}",
      )
    } else {
      let param_types = Array::new()
      for param in func.param_list {
        let { ty, .. } = param
        let ty = self.check_parser_type(ty)
        param_types.push(ty.kind)
      }
      let ret_ty = self.check_parser_type(func.ret_ty)
      let fty = Function(param_types, ret_ty.kind)
      self.func_types.set(func_whole_name, fty)
      self.type_env.set(func_whole_name, Type::{ kind: fty, mutable: false })
    }
  }
}

///|
pub fn Context::find_enum_def_by_variant_name(
  self : Self,
  variant_name : String,
) -> Array[EnumDef] {
  let enum_defs = Array::new()
  for _, enum_def in self.enum_defs {
    if enum_def.get_field(variant_name) is Some(_) {
      enum_defs.push(enum_def)
    }
  }
  enum_defs
}
