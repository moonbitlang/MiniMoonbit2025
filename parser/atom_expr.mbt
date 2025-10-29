///|
pub(all) struct AtomExpr {
  kind : AtomExprKind
} derive(Show, Eq)

///|
pub(all) enum AtomExprKind {
  Int(Int) // 1, 42, etc
  Double(Double) // 1.0, 3.14, etc
  Bool(Bool) // true | false
  String(String) // "hello", etc
  Ident(String) // var
  Unit // ()
  Paren(Expr) // (expr)
  Tuple(Array[Expr]) // (expr, expr, ...)
  Array(Array[Expr]) // [expr, expr, ...]
  ArrayMake(Expr, Expr) // Array::make(size, init)
  StructConstruct(StructConstructExpr) // StructName::{ field: expr, ... }
} derive(Show, Eq)

///|
pub fn parse_atom_expr(
  tokens : ArrayView[Token],
) -> (AtomExpr, ArrayView[Token]) raise ParseError {
  match tokens {
    [{ kind: Int(v), .. }, .. tokens] => {
      let expr = AtomExpr::{ kind: AtomExprKind::Int(v) }
      (expr, tokens)
    }
    [{ kind: Double(v), .. }, .. tokens] => {
      let expr = AtomExpr::{ kind: AtomExprKind::Double(v) }
      (expr, tokens)
    }
    [{ kind: Bool(v), .. }, .. tokens] => {
      let expr = AtomExpr::{ kind: AtomExprKind::Bool(v) }
      (expr, tokens)
    }
    [{ kind: String(s), .. }, .. tokens] => {
      let expr = AtomExpr::{ kind: AtomExprKind::String(s) }
      (expr, tokens)
    }
    [{ kind: Lower(ident), .. }, .. tokens] => {
      let expr = AtomExpr::{ kind: AtomExprKind::Ident(ident) }
      (expr, tokens)
    }
    [{ kind: Upper("Array"), .. }, ..] as tokens =>
      parse_array_make_expr(tokens)
    [{ kind: Upper(_), .. }, ..] as tokens => parse_struct_construct(tokens)
    [{ kind: Bracket('('), .. }, ..] as tokens => parse_paren_expr(tokens)
    [{ kind: Bracket('['), .. }, ..] as tokens => parse_array_expr(tokens)
    [] => {
      println("Compiler ICE: Empty Token ArrayView")
      panic()
    }
    tokens => raise ParseError("InValid Atom Expression, \{tokens[0:5]}")
  }
}

///|
fn parse_paren_expr(
  tokens : ArrayView[Token],
) -> (AtomExpr, ArrayView[Token]) raise ParseError {
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
  let atom_expr = AtomExpr::{ kind, }
  (atom_expr, tokens)
}

///|
fn parse_array_make_expr(
  tokens : ArrayView[Token],
) -> (AtomExpr, ArrayView[Token]) raise ParseError {
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
    raise ParseError("Expected ',' after size expression in Array::make")
  }
  let (init_expr, tokens) = parse_expr(tokens)
  guard tokens is [{ kind: Bracket(')'), .. }, .. tokens] else {
    raise ParseError("Expected ')' after init expression in Array::make")
  }
  let atom_expr = AtomExpr::{
    kind: AtomExprKind::ArrayMake(size_expr, init_expr),
  }
  (atom_expr, tokens)
}

///|
fn parse_array_expr(
  tokens : ArrayView[Token],
) -> (AtomExpr, ArrayView[Token]) raise ParseError {
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
  let atom_expr = AtomExpr::{ kind: AtomExprKind::Array(exprs) }
  (atom_expr, tokens)
}
