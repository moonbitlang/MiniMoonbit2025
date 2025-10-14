
pub(all) struct Param {
  name : String
  ty : Type
} derive(Show, Eq)

///|
pub(all) struct TopFunction {
  fname : String
  param_list : Array[Param]
  ret_ty : Type
  body : BlockExpr
} derive(Show, Eq)

///|
pub fn parse_param(
  tokens : ArrayView[Token],
) -> (Param, ArrayView[Token]) raise ParseError {
  guard tokens is [{ kind: Lower(name) }, .. tokens] else {
    raise ParseError("Expect a lower case")
  }
  guard tokens is [{ kind: Symbol(":") }, .. tokens] else {
    raise ParseError("Expect a `:`")
  }
  guard tokens is [{ kind: Upper(_) }, ..] else {
    raise ParseError("Expect type name")
  }
  let (ty, tokens) = parse_type(tokens)
  let param = Param::{ name, ty }
  (param, tokens)
}

pub fn parse_param_list(
  tokens : ArrayView[Token],
) -> (Array[Param], ArrayView[Token]) raise ParseError {
  let params : Array[Param] = Array::new()
  let tokens = loop tokens {
    [{ kind: Lower(_) }, ..] as tokens => {
      let (param, rest) = parse_param(tokens)
      params.push(param)
      continue rest
    }
    [{ kind: Symbol(",") }, { kind: Lower(_) }, ..] as tokens => {
      let (param, rest) = parse_param(tokens[1:])
      params.push(param)
      continue rest
    }
    [{ kind: Symbol(",") }, { kind: Bracket(')') }, ..] as tokens =>
      break tokens[1:]
    [{ kind: Bracket(')') }, ..] as tokens => break tokens
    [] => {
      println("Compiler ICE: Empty Token ArrayView")
      panic()
    }
    tok => raise ParseError("InValid Param List Parsing: \{tok[0]}")
  }
  (params, tokens)
}

pub fn parse_top_function(
  tokens : ArrayView[Token],
) -> (TopFunction, ArrayView[Token]) raise ParseError {
  guard tokens is [{ kind: Keyword(Fn) }, .. tokens] else {
    println("Compiler ICE: Misuse parse_top_function")
    panic()
  }
  guard tokens is [{ kind: Lower(fname) }, .. tokens] else {
    raise ParseError("Expect a lower ident")
  }
  let (param_list, ret_ty, tokens) = if !(fname is "main") {
    guard tokens is [{ kind: Bracket('(') }, .. tokens] else {
      raise ParseError("Expect '('")
    }
    let (param_list, tokens) = parse_param_list(tokens)
    guard tokens is [{ kind: Bracket(')') }, .. tokens] else {
      raise ParseError("Expect ')'")
    }
    guard tokens is [{ kind: Symbol("->") }, .. tokens] else {
      raise ParseError("Expect '->'")
    }
    let (ret_ty, tokens) = parse_type(tokens)
    (param_list, ret_ty, tokens)
  } else {
    let ret_type = Type::{
      kind: Unit,
    }
    (Array::new(), ret_type, tokens)
  }
  let (body, tokens) = parse_block_expr(tokens)
  let top_function = TopFunction::{
    fname,
    param_list,
    ret_ty,
    body,
  }
  (top_function, tokens)
}

