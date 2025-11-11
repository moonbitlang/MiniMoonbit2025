///|
pub(all) struct AtomExpr {
  kind : AtomExprKind
  toks : ArrayView[Token]
} derive(Show, Eq)

///|
pub(all) enum AtomExprKind {
  Int(Int) // 1, 42, etc
  Int64(Int64) // 1L, 42L, etc
  UInt(UInt) // 1U, 42U, etc
  UInt64(UInt64) // 1UL, 42UL, etc
  Double(Double) // 1.0, 3.14, etc
  Float(Double) // 1.0F, 3.14F (stored as Double)
  Char(Char) // 'a', '\n', etc
  Bool(Bool) // true | false
  String(String) // "hello", etc
  Ident(String) // var
  IdentWithTag(String, String) // Point::x
  Unit // ()
  Paren(Expr) // (expr)
  Tuple(Array[Expr]) // (expr, expr, ...)
  Array(Array[Expr]) // [expr, expr, ...]
  ArrayMake(Expr, Expr) // Array::make(size, init)
  EnumConstruct(String?, String, Array[Expr]) // EnumTag::Variant(expr, ...)
  StructConstruct(StructConstructExpr) // StructName::{ field: expr, ... }
} derive(Show, Eq)

fn AtomExpr::unit() -> AtomExpr {
  let kind = AtomExprKind::Unit
  AtomExpr::{ kind, toks: [] }
}

///|
pub fn AtomExpr::new(
  kind : AtomExprKind,
  init_tokens : ArrayView[Token],
  rest_tokens : ArrayView[Token],
) -> AtomExpr {
  let len = rest_tokens.start_offset() - init_tokens.start_offset()
  let toks = init_tokens[0:len]
  AtomExpr::{ kind, toks }
}

///|
pub fn parse_atom_expr(
  tokens : ArrayView[Token],
) -> (AtomExpr, ArrayView[Token]) raise ParseError {
  let init_tokens = tokens
  match tokens {
    [{ kind: Int(v), .. }, .. tokens] => {
      let expr = AtomExpr::new(Int(v), init_tokens, tokens)
      (expr, tokens)
    }
    [{ kind: Int64(v), .. }, .. tokens] => {
      let expr = AtomExpr::new(Int64(v), init_tokens, tokens)
      (expr, tokens)
    }
    [{ kind: UInt(v), .. }, .. tokens] => {
      let expr = AtomExpr::new(UInt(v), init_tokens, tokens)
      (expr, tokens)
    }
    [{ kind: UInt64(v), .. }, .. tokens] => {
      let expr = AtomExpr::new(UInt64(v), init_tokens, tokens)
      (expr, tokens)
    }
    [{ kind: Double(v), .. }, .. tokens] => {
      let expr = AtomExpr::new(Double(v), init_tokens, tokens)
      (expr, tokens)
    }
    [{ kind: Float(v), .. }, .. tokens] => {
      let expr = AtomExpr::new(Float(v), init_tokens, tokens)
      (expr, tokens)
    }
    [{ kind: Char(c), .. }, .. tokens] => {
      let expr = AtomExpr::new(Char(c), init_tokens, tokens)
      (expr, tokens)
    }
    [{ kind: Bool(v), .. }, .. tokens] => {
      let expr = AtomExpr::new(Bool(v), init_tokens, tokens)
      (expr, tokens)
    }
    [{ kind: String(s), .. }, .. tokens] => {
      let expr = AtomExpr::new(String(s), init_tokens, tokens)
      (expr, tokens)
    }
    [{ kind: Lower(ident), .. }, .. tokens] => {
      let expr = AtomExpr::new(Ident(ident), init_tokens, tokens)
      (expr, tokens)
    }
    [{ kind: Upper("Array"), .. }, ..] as tokens =>
      parse_array_make_expr(tokens)
    [{ kind: Upper(tag), .. }, { kind: Symbol("::"), .. }, { kind: Lower(ident), ..}, .. tokens] => {
      let expr = AtomExpr::new(
        IdentWithTag(tag, ident), init_tokens, tokens )
      (expr, tokens)
    }
    [{ kind: Upper(_), .. }, {kind: Symbol("::"), ..},
     { kind: Bracket('{'), ..}, ..] as tokens => parse_struct_construct(tokens)
    [{ kind: Upper(_), ..}, ..] as tokens => parse_enum_construct(tokens)
    [{ kind: Bracket('('), .. }, ..] as tokens => parse_paren_expr(tokens)
    [{ kind: Bracket('['), .. }, ..] as tokens => parse_array_expr(tokens)
    [] => {
      println("Compiler ICE: Empty Token ArrayView")
      panic()
    }
    [tok, ..] => {
      let msg = "Parse Error: InValid Atom Expression" + 
      " Expect Int, Float, Char, Bool, String, Ident, '(', '[' or Struct Construct"
      @lexer.throw_(tok, msg, Error)
      raise ParseError("InValid Atom Expression")
    }
  }
}

///|
fn parse_paren_expr(
  tokens : ArrayView[Token],
) -> (AtomExpr, ArrayView[Token]) raise ParseError {
  let init_tokens = tokens
  guard tokens is [{ kind: Bracket('('), .. }, .. tokens] else {
    println("Compiler ICE: Misuse parse_paren_or_tuple_expr")
    panic()
  }
  let exprs : Array[Expr] = Array::new()
  let tokens = loop tokens {
    [{ kind: Bracket(')'), .. }, .. rest] => break rest
    [{ kind: Symbol(","), .. }, { kind: Bracket(')'), .. }, .. rest] =>
      break rest
    [{ kind: Symbol(","), .. }, .. tokens] => {
      let (expr, rest) = parse_expr(tokens)
      exprs.push(expr)
      continue rest
    }
    [] => {
      println("Compiler ICE: Empty Token ArrayView")
      panic()
    }
    tokens => {
      let (expr, rest) = parse_expr(tokens)
      exprs.push(expr)
      continue rest
    }
  }
  let kind = match exprs.length() {
    0 => AtomExprKind::Unit
    1 => AtomExprKind::Paren(exprs[0])
    _ => AtomExprKind::Tuple(exprs)
  }
  let atom_expr = AtomExpr::new(kind, init_tokens, tokens)
  (atom_expr, tokens)
}

///|
fn parse_array_make_expr(
  tokens : ArrayView[Token],
) -> (AtomExpr, ArrayView[Token]) raise ParseError {
  let init_tokens = tokens
  guard tokens
    is [
      { kind: Upper("Array"), .. },
      { kind: Symbol("::"), .. },
      { kind: Lower("make"), .. },
      { kind: Bracket('('), .. },
      .. tokens,
    ] else {
    println("Compiler ICE: Misuse parse_array_make_expr, \{tokens}")
    panic()
  }
  let (size_expr, tokens) = parse_expr(tokens)
  guard tokens is [{ kind: Symbol(","), .. }, .. tokens] else {
    @lexer.throw_(
      tokens[0],
      "Parse Error: Expected ',' after size expression in Array::make",
      Error,
    )
    raise ParseError("Expected ',' after size expression in Array::make")
  }
  let (init_expr, tokens) = parse_expr(tokens)
  guard tokens is [{ kind: Bracket(')'), .. }, .. tokens] else {
    @lexer.throw_(
      tokens[0],
      "Parse Error: Expected ')' after init expression in Array::make",
      Error,
    )
    raise ParseError("Expected ')' after init expression in Array::make")
  }
  let atom_expr = AtomExpr::new(
    AtomExprKind::ArrayMake(size_expr, init_expr),
    init_tokens,
    tokens,
  )
  (atom_expr, tokens)
}

///|
fn parse_array_expr(
  tokens : ArrayView[Token],
) -> (AtomExpr, ArrayView[Token]) raise ParseError {
  let init_tokens = tokens
  guard tokens is [{ kind: Bracket('['), .. }, .. tokens] else {
    println("Compiler ICE: Misuse parse_array_expr")
    panic()
  }
  let exprs : Array[Expr] = Array::new()
  let tokens = loop tokens {
    [{ kind: Bracket(']'), .. }, .. rest] => break rest
    [{ kind: Symbol(","), .. }, { kind: Bracket(']'), .. }, .. rest] =>
      break rest
    [{ kind: Symbol(","), .. }, .. tokens] => {
      let (expr, rest) = parse_expr(tokens)
      exprs.push(expr)
      continue rest
    }
    [] => {
      println("Compiler ICE: Empty Token ArrayView")
      panic()
    }
    tokens => {
      let (expr, rest) = parse_expr(tokens)
      exprs.push(expr)
      continue rest
    }
  }
  let atom_expr = AtomExpr::new(AtomExprKind::Array(exprs), init_tokens, tokens)
  (atom_expr, tokens)
}

fn parse_enum_construct(
  tokens : ArrayView[Token],
) -> (AtomExpr, ArrayView[Token]) raise ParseError {
  let init_tokens = tokens
  guard tokens is [{ kind: Upper(name1), .. }, ..tokens] else {
    println("Compiler ICE: Misuse parse_enum_construct, expected enum name")
    panic()
  }
  let (tag, variant_name, tokens) = match tokens {
    [{ kind: Symbol("::"), .. }, { kind: Upper(variant), .. }, .. tokens] =>
      (Some(name1), variant, tokens)
    _ => {
      (None, name1, tokens)
    }
  }
  let exprs : Array[Expr] = Array::new()
  guard tokens is [{ kind: Bracket('('), .. }, .. tokens] else {
    let kind = AtomExprKind::EnumConstruct(tag, variant_name, exprs)
    let atom_expr = AtomExpr::new(kind, tokens, tokens)
    return (atom_expr, tokens)
  }
  let tokens = loop tokens {
    [{ kind: Bracket(')'), .. }, .. rest] => break rest
    [{ kind: Symbol(","), .. }, { kind: Bracket(')'), .. }, .. rest] =>
      break rest
    [{ kind: Symbol(","), .. }, .. tokens] => {
      let (expr, rest) = parse_expr(tokens)
      exprs.push(expr)
      continue rest
    }
    [] => {
      println("Compiler ICE: Empty Token ArrayView")
      panic()
    }
    tokens => {
      let (expr, rest) = parse_expr(tokens)
      exprs.push(expr)
      continue rest
    }
  }
  let kind = AtomExprKind::EnumConstruct(tag, variant_name, exprs)
  let atom_expr = AtomExpr::new(kind, init_tokens, tokens)
  (atom_expr, tokens)
}
