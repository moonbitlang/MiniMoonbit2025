///|
pub(all) enum Type {
  Unit
  Int
  Int64
  UInt
  UInt64
  Bool
  Double
  Float
  Char
  String
  Array(Type)
  Struct(String)
  Union(String)
  Tuple(Array[Type])
  Function(Array[Type], Type)
}

///|
pub impl Show for Type with output(self, logger) {
  let s = match self {
    Unit => "Unit"
    Int => "Int"
    Int64 => "Int64"
    UInt => "UInt"
    UInt64 => "UInt64"
    Bool => "Bool"
    Double => "Double"
    Float => "Float"
    Char => "Char"
    String => "String"
    Array(elem_type) => "Array[\{elem_type}]"
    Struct(name) => "\{name}"
    Union(name) => "\{name}"
    Tuple(elem_types) => {
      let elem_strs = elem_types.map(et => "\{et}").join(", ")
      "(\{elem_strs})"
    }
    Function(param_types, ret_type) => {
      let param_strs = param_types.map(pt => "\{pt}").join(", ")
      "(\{param_strs}) -> \{ret_type}"
    }
  }
  logger.write_string(s)
}

///|
pub fn Context::typekind_to_knf(
  self : Context,
  tk : @typecheck.TypeKind,
) -> Type raise KnfTransformError {
  match tk {
    Unit => Unit
    Int => Int
    Int64 => Int64
    UInt => UInt
    UInt64 => UInt64
    Bool => Bool
    Double => Double
    Float => Float
    Char => Char
    String => String
    Array(elem_tk) => Array(self.typekind_to_knf(elem_tk))
    Struct(name) => Struct(name)
    Enum(name) => Union(name)
    Tuple(elem_tks) => {
      let elem_types = elem_tks.map(etk => self.typekind_to_knf(etk))
      Tuple(elem_types)
    }
    Function(param_tks, ret_tk) => {
      let param_types = param_tks.map(ptk => self.typekind_to_knf(ptk))
      let ret_type = self.typekind_to_knf(ret_tk)
      Function(param_types, ret_type)
    }
    Any => Unit
    TypeVar(_) =>
      raise KnfTransformError(
        "Unexpected TypeVar in KNF transformation: loc: typekind_to_knf",
      )
  }
}

///|
pub fn Context::type_to_knf(
  self : Context,
  t : @typecheck.Type,
) -> Type raise KnfTransformError {
  self.typekind_to_knf(t.kind)
}
