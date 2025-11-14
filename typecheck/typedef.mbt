///|
pub(all) struct Type {
  kind : TypeKind
  mutable : Bool
}

///|
pub impl Show for Type with output(self, logger) {
  logger.write_object(self.kind)
}

///|
pub(all) enum TypeKind {
  Unit
  Bool
  Int
  Int64
  UInt
  UInt64
  Double
  Float
  Char
  String
  Tuple(Array[TypeKind])
  Array(TypeKind)
  Function(Array[TypeKind], TypeKind)
  Struct(String)
  Enum(String)
  Any
  TypeVar(Int)
} derive(Hash, Eq)

///|
pub fn Context::check_parser_typekind(
  self : Context,
  ty : @parser.TypeKind,
) -> TypeKind raise TypeCheckError {
  fn from_parser_typekind(
    ty : @parser.TypeKind,
  ) -> TypeKind raise TypeCheckError {
    self.check_parser_typekind(ty)
  }

  match ty {
    Unit => Unit
    Bool => Bool
    Int => Int
    Int64 => Int64
    UInt => UInt
    UInt64 => UInt64
    Double => Double
    Float => Float
    Char => Char
    String => String
    Tuple(inner) => {
      let inner_tys = inner.map(from_parser_typekind)
      Tuple(inner_tys)
    }
    Array(elem) => {
      let elem_ty = from_parser_typekind(elem)
      Array(elem_ty)
    }
    Function(params, ret) => {
      let param_tys = params.map(from_parser_typekind)
      let ret_ty = from_parser_typekind(ret)
      Function(param_tys, ret_ty)
    }
    Defined(name) if self.struct_defs.contains(name) => Struct(name)
    Defined(name) if self.enum_defs.contains(name) => Enum(name)
    Defined(name) => raise TypeCheckError("Unknown type: \{name}")
  }
}

///|
pub fn Context::check_parser_type(
  self : Context,
  ty : @parser.Type,
  mutable? : Bool = false,
) -> Type raise TypeCheckError {
  let tk = self.check_parser_typekind(ty.kind)
  Type::{ kind: tk, mutable }
}

///|
pub fn Context::is_type_compatible(
  self : Context,
  a : TypeKind,
  b : TypeKind,
) -> Bool {
  match (a, b) {
    (Unit, Unit) => true
    (Bool, Bool) => true
    (Int, Int) => true
    (Int64, Int64) => true
    (UInt, UInt) => true
    (UInt64, UInt64) => true
    (Double, Double) => true
    (Float, Float) => true
    (Char, Char) => true
    (String, String) => true
    (Tuple(types_a), Tuple(types_b)) => {
      if types_a.length() != types_b.length() {
        return false
      }
      for i in 0..<types_a.length() {
        if !self.is_type_compatible(types_a[i], types_b[i]) {
          return false
        }
      }
      true
    }
    (Array(elem_a), Array(elem_b)) => self.is_type_compatible(elem_a, elem_b)
    (Function(params_a, ret_a), Function(params_b, ret_b)) => {
      if params_a.length() != params_b.length() {
        return false
      }
      for i in 0..<params_a.length() {
        if !self.is_type_compatible(params_a[i], params_b[i]) {
          return false
        }
      }
      self.is_type_compatible(ret_a, ret_b)
    }
    (Struct(name_a), Struct(name_b)) => name_a == name_b
    (Enum(name_a), Enum(name_b)) => name_a == name_b
    (Any, _) => true
    (_, Any) => true
    (TypeVar(id_a), TypeVar(id_b)) => {
      guard self.type_vars.get(id_b) is Some(ty_b) else {
        println("Compiler ICE: Unbound type variable: \{id_b}")
        panic()
      }
      guard self.type_vars.get(id_a) is Some(ty_a) else {
        println("Compiler ICE: Unbound type variable: \{id_a}")
        panic()
      }
      match (ty_a is TypeVar(_), ty_b is TypeVar(_)) {
        (true, false) => {
          self.set_var_type_to_typekind(id_a, ty_b)
          true
        }
        (false, true) => {
          self.set_var_type_to_typekind(id_b, ty_a)
          true
        }
        (false, false) => self.is_type_compatible(ty_a, ty_b)
        (true, true) => {
          self.set_var_type_to_typekind(id_a, ty_b)
          true
        }
      }
    }
    (TypeVar(id), ty) => {
      guard self.type_vars.get(id) is Some(bound_ty) else {
        println("Compiler ICE: Unbound type variable: \{id}")
        panic()
      }
      match bound_ty {
        TypeVar(id) => {
          self.set_var_type_to_typekind(id, ty)
          true
        }
        _ => self.is_type_compatible(bound_ty, ty)
      }
    }
    (ty, TypeVar(id)) => {
      guard self.type_vars.get(id) is Some(bound_ty) else {
        println("Compiler ICE: Unbound type variable: \{id}")
        panic()
      }
      match bound_ty {
        TypeVar(id) => {
          self.set_var_type_to_typekind(id, ty)
          true
        }
        _ => self.is_type_compatible(ty, bound_ty)
      }
    }
    _ => false
  }
}

///|
fn Context::set_var_type_to_typekind(
  self : Context,
  var_id : Int,
  ty : TypeKind,
) -> Unit {
  for id, tk in self.type_vars {
    if tk is TypeVar(inner_var_id) && inner_var_id == var_id {
      self.type_vars.set(id, ty)
    }
  }
}

///|
fn Context::ensure_type(self : Context, ty : TypeKind) -> TypeKind {
  match ty {
    TypeVar(id) => {
      guard self.type_vars.get(id) is Some(bound_ty) else {
        println("Compiler ICE: Unbound type variable: \{id}")
        panic()
      }
      bound_ty
    }
    Array(elem_type) => {
      let ensured_elem_type = self.ensure_type(elem_type)
      Array(ensured_elem_type)
    }
    Tuple(types) => {
      let ensured_types = types.map(typekind => self.ensure_type(typekind))
      Tuple(ensured_types)
    }
    Function(param_types, return_type) => {
      let ensured_param_types = param_types.map(typekind => self.ensure_type(
        typekind,
      ))
      let ensured_return_type = self.ensure_type(return_type)
      Function(ensured_param_types, ensured_return_type)
    }
    _ => ty
  }
}

///|
pub impl Show for TypeKind with output(self, logger) {
  let s = match self {
    Unit => "Unit"
    Bool => "Bool"
    Int => "Int"
    Int64 => "Int64"
    UInt => "UInt"
    UInt64 => "UInt64"
    Double => "Double"
    Float => "Float"
    Char => "Char"
    String => "String"
    Tuple(types) => {
      let inner = types.map(typekind => typekind.to_string()).join(", ")
      "(\{inner})"
    }
    Array(elem_type) => "Array[\{elem_type.to_string()}]"
    Function(param_types, return_type) => {
      let params = param_types.map(typekind => typekind.to_string()).join(", ")
      "(\{params}) -> \{return_type.to_string()}"
    }
    Struct(name) => "\{name}"
    Enum(name) => "\{name}"
    Any => "Any"
    TypeVar(name) => "TypeVar(\{name})"
  }
  logger.write_string(s)
}
