
pub(all) struct StructDef {
  name : String
  fields : Array[StructField]
} derive(Show, Eq)

///|
pub(all) struct StructField {
  name : String
  is_mut : Bool
  ty : Type
} derive(Show, Eq)

pub fn parse_struct_field(
  tokens : ArrayView[Token],
) -> (StructField, ArrayView[Token]) raise ParseError {
  let (is_mut, tokens) = if tokens is [{ kind: Keyword(Mut) }, ..] {
    (true, tokens[1:])
  } else {
    (false, tokens)
  }
  guard tokens is [{ kind: Lower(name) }, .. tokens] else {
    raise ParseError("Expect struct field name")
  }
  guard tokens is [{ kind: Symbol(":") }, .. tokens] else {
    raise ParseError("Expect ':' after struct field name")
  }
  let (ty, tokens) = parse_type(tokens)
  let struct_field = StructField::{
    is_mut,
    name,
    ty,
  }
  guard tokens is [{ kind: Symbol(";") }, ..tokens] else {
    raise ParseError("Expect ';' after struct field")
  }
  (struct_field, tokens)
}

pub fn parse_struct_def(
  tokens : ArrayView[Token],
) -> (StructDef, ArrayView[Token]) raise ParseError {
  guard tokens is [{ kind: Keyword(Struct) }, .. tokens] else {
    println("Compiler ICE: Misuse parse_struct_def")
    panic()
  }
  guard tokens is [{ kind: Upper(name) }, .. tokens] else {
    raise ParseError( "Expect struct name")
  }
  guard tokens is [{ kind: Bracket('{') }, .. tokens] else {
    raise ParseError("Failed Parsing StructDef: Expect '{'")
  }
  let fields : Array[StructField] = Array::new()
  let tokens = loop tokens {
    [{ kind: Bracket('}') }, .. rest] =>
      break rest
    [] => {
      println("Compiler ICE: Empty Token ArrayView")
      panic()
    }
    tokens => {
      let (field, rest) = parse_struct_field(tokens)
      fields.push(field)
      continue rest
    }
  }
  let struct_def = StructDef::{
    name,
    fields,
  }
  (struct_def, tokens)
}

