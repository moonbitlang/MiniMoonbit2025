
///|
typealias @lexer.Token

///|
pub suberror ParseError String derive(Show)

///|
pub impl Show for TypeKind with output(self, logger) {
  let s = match self {
    Unit => "Unit"
    Bool => "Bool"
    Int => "Int"
    Int64 => "Int64"
    UInt => "UInt"
    UInt64 => "UInt64"
    Float => "Float"
    Double => "Double"
    String => "String"
    Tuple(tys) => {
      let inner = tys.map(ty => ty.to_string()).join(", ")
      "(\{inner})"
    }
    Array(ty) => "Array[\{ty}]"
    Function(params, ret) => {
      let param_str = params.map(ty => ty.to_string()).join(", ")
      "(\{param_str}) -> \{ret}"
    }
    Defined(name) => name
  }
  logger.write_string(s)
}
