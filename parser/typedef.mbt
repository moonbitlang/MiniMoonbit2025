///|
pub struct Type {
  kind : TypeKind
} derive(Show, Eq)

///|
pub(all) enum TypeKind {
  Unit
  Bool
  Int
  Int64
  UInt
  UInt64
  Float
  Double
  String
  Tuple(Array[TypeKind])
  Array(TypeKind)
  Function(Array[TypeKind], TypeKind)
  Defined(String)
} derive(Hash, Eq) // Show defined manually in `parser_aux.mbt`

///|
pub fn parse_type(
  tokens : ArrayView[Token],
) -> (Type, ArrayView[Token]) raise ParseError {
  match tokens {
    [{ kind: Upper("Unit") }, .. rest] => (Type::{ kind: Unit }, rest)
    [{ kind: Upper("Bool") }, .. rest] => (Type::{ kind: Bool }, rest)
    [{ kind: Upper("Int") }, .. rest] => (Type::{ kind: Int }, rest)
    [{ kind: Upper("UInt") }, .. rest] => (Type::{ kind: UInt }, rest)
    [{ kind: Upper("Int64") }, .. rest] => (Type::{ kind: Int64 }, rest)
    [{ kind: Upper("UInt64") }, .. rest] => (Type::{ kind: UInt64 }, rest)
    [{ kind: Upper("Float") }, .. rest] => (Type::{ kind: Float }, rest)
    [{ kind: Upper("Double") }, .. rest] => (Type::{ kind: Double }, rest)
    [{ kind: Upper("String") }, .. rest] => (Type::{ kind: String }, rest)
    [{ kind: Bracket('(') }, ..] as tokens =>
      parse_tuple_or_function_type(tokens)
    [{ kind: Upper("Array") }, ..] as tokens => parse_array_type(tokens)
    [{ kind: Upper(def) }, .. rest] => (Type::{ kind: Defined(def) }, rest)
    [] => {
      println("Compiler ICE: Empty Token ArrayView")
      panic()
    }
    tok => raise ParseError("InValid Type Parsing: \{tok[0]}")
  }
}

///|
fn parse_tuple_or_function_type(
  tokens : ArrayView[Token],
) -> (Type, ArrayView[Token]) raise ParseError {
  guard tokens is [{ kind: Bracket('(') }, .. tokens] else {
    println("Compiler ICE: Misuse parse_tuple_or_function_type")
    panic()
  }
  let tys : Array[TypeKind] = Array::new()
  let tokens = loop tokens {
    [{ kind: Upper(_) | Bracket('(') }, ..] as tokens => {
      let (ty, rest) = parse_type(tokens)
      tys.push(ty.kind)
      continue rest
    }
    [{ kind: Symbol(",") }, { kind: Upper(_) | Bracket('(') }, ..] as tokens => {
      let (ty, rest) = parse_type(tokens[1:])
      tys.push(ty.kind)
      continue rest
    }
    [{ kind: Bracket(')') }, .. rest] => break rest
    [] => {
      println("Compiler ICE: Empty Token ArrayView")
      panic()
    }
    tok => raise ParseError("InValid Type Parsing, \{tok}")
  }
  if tokens is [{ kind: Symbol("->") }, .. tokens] {
    let (ret_ty, rest) = parse_type(tokens)
    (Type::{ kind: Function(tys, ret_ty.kind) }, rest)
  } else {
    (Type::{ kind: Tuple(tys) }, tokens)
  }
}

///|
fn parse_array_type(
  tokens : ArrayView[Token],
) -> (Type, ArrayView[Token]) raise ParseError {
  guard tokens is [{ kind: Upper("Array") }, .. tokens] else {
    println("Compiler ICE: Misuse parse_array_type")
    panic()
  }
  guard tokens is [{ kind: Bracket('[') }, .. tokens] else {
    raise ParseError("InValid Array Type Parsing, missing '['")
  }
  let (elem_ty, rest) = parse_type(tokens)
  guard rest is [{ kind: Bracket(']') }, .. rest] else {
    raise ParseError("InValid Array Type Parsing, missing ']'")
  }
  (Type::{ kind: Array(elem_ty.kind) }, rest)
}

