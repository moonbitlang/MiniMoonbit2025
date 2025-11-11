///|
pub(all) struct StructConstructExpr {
  name : String
  fields : Array[(String, Expr)]
  toks : ArrayView[Token]
} derive(Show, Eq)

///|
pub fn parse_struct_construct(
  tokens : ArrayView[Token],
) -> (AtomExpr, ArrayView[Token]) raise ParseError {
  let init_tokens = tokens
  guard tokens is [{ kind: Upper(name), .. }, .. tokens] else {
    println(
      "Compiler ICE: Misuse parse_struct_or_enum_construct, expected struct/enum name",
    )
    panic()
  }
  guard tokens is [{ kind: Symbol("::"), .. }, .. tokens] else {
    println(
      "Compiler ICE: Misuse parse_struct_or_enum_construct, expected '::'",
    )
    panic()
  }
  guard tokens is [{ kind: Bracket('{'), .. }, .. tokens] else {
    println("Compiler ICE: Misuse parse_struct_or_enum_construct, expected '{'")
    panic()
  }
  let fields : Array[(String, Expr)] = Array::new()
  let tokens = loop tokens {
    [{ kind: Bracket('}'), .. }, .. rest] => break rest
    [{ kind: Symbol(","), .. }, { kind: Bracket('}'), .. }, .. rest] =>
      break rest
    [{ kind: Symbol(","), .. }, { kind: Lower(field), .. }, .. tokens] => {
      guard tokens is [{ kind: Symbol(":"), .. }, .. tokens] else {
        raise ParseError("Expect ':'")
      }
      let (expr, rest) = parse_expr(tokens)
      fields.push((field, expr))
      continue rest
    }
    [{ kind: Lower(field), .. }, .. tokens] => {
      guard tokens is [{ kind: Symbol(":"), .. }, ..] else {
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
  let len = tokens.start_offset() - init_tokens.start_offset()
  let toks = init_tokens[0:len]
  let struct_construct = StructConstructExpr::{ name, fields, toks }
  let atom_expr = AtomExpr::new(
    StructConstruct(struct_construct),
    init_tokens,
    tokens,
  )
  (atom_expr, tokens)
}
