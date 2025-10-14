pub(all) struct StructConstructExpr {
  name : String
  fields : Array[(String, Expr)]
} derive(Show, Eq)

pub fn parse_struct_construct(
  tokens : ArrayView[Token],
) -> (AtomExpr, ArrayView[Token]) raise ParseError {
  guard tokens is [{ kind: Upper(name) }, .. tokens] else {
    println("Compiler ICE: Misuse parse_struct_or_enum_construct")
    panic()
  }
  guard tokens is [{ kind: Symbol("::") }, .. tokens] else {
    println("Compiler ICE: Misuse parse_struct_or_enum_construct")
    panic()
  }
  guard tokens is [{ kind: Bracket('{') }, .. tokens] else {
    raise ParseError("Expect '{' for struct construct")
  }
  let fields : Array[(String, Expr)] = Array::new()
  let tokens = loop tokens {
    [{ kind: Bracket('}') }, .. rest] =>
      break rest
    [{ kind: Symbol(",") }, { kind: Bracket('}') }, .. rest] =>
      break rest
    [{ kind: Symbol(",") }, { kind: Lower(field) }, .. tokens] => {
      guard tokens is [{ kind: Symbol(":") }, .. tokens] else {
        raise ParseError("Expect ':'")
      }
      let (expr, rest) = parse_expr(tokens)
      fields.push((field, expr))
      continue rest
    }
    [{ kind: Lower(field) }, .. tokens] => {
      guard tokens is [{ kind: Symbol(":") }, ..] else {
        raise ParseError("Expect ':'")
      }
      let (expr, rest) = parse_expr(tokens[1:])
      fields.push((field, expr))
      continue rest
    }
    [] => {
      println("Compiler ICE: Empty Token ArrayView")
      panic()
    }
    tokens => raise ParseError("InValid Struct Construct: \{tokens[0]}")
  }
  let struct_construct = StructConstructExpr::{
    name: name,
    fields: fields,
  }
  let atom_expr = AtomExpr::{
    kind: StructConstruct(struct_construct),
  }
  (atom_expr, tokens)
}
