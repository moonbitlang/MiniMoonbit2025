
pub(all) struct LocalFunction {
  fname: String
  param_list: Array[(String, Type?)]
  ret_ty: Type?
  body: BlockExpr
} derive(Show, Eq)

pub fn parse_local_function(
  tokens: ArrayView[Token],
) -> (LocalFunction, ArrayView[Token]) raise ParseError {
  guard tokens is [{ kind: Keyword(Fn) }, .. tokens] else {
    println("Compiler ICE: Misuse parse_local_function")
    panic()
  }
  guard tokens is [{ kind: Lower(fname) }, .. tokens] else {
    raise ParseError("Expect a lower ident")
  }
  guard tokens is [{ kind: Bracket('(') }, .. tokens] else {
    raise ParseError("Expect '('")
  }
  let params : Array[(String, Type?)] = Array::new()
  let tokens = loop tokens {
    [{ kind: Bracket(')') }, ..tokens] => break tokens
    [{ kind: Lower(name) }, { kind: Symbol(":") }, ..tokens] => {
      let (ty, tokens) = parse_type(tokens)
      params.push((name, Some(ty)))
      continue tokens
    }
    [{ kind: Symbol(",") }, { kind: Lower(name) }, { kind: Symbol(":") }, ..tokens] => {
      let (ty, tokens) = parse_type(tokens)
      params.push((name, Some(ty)))
      continue tokens
    }
    [{ kind: Lower(name) }, ..tokens] => {
      params.push((name, None))
      continue tokens
    }
    [{ kind: Symbol(",") }, { kind: Lower(name) }, ..tokens] => {
      params.push((name, None))
      continue tokens
    }
    [] => {
      println("Compiler ICE: Empty Token ArrayView")
      panic()
    }
    tok => raise ParseError("InValid Param List Parsing: \{tok[0]}")
  }
  let (ret_ty, tokens) = if tokens is [{ kind: Symbol("->") }, ..tokens] {
    let (ty, tokens) = parse_type(tokens)
    (Some(ty), tokens)
  } else {
    (None, tokens)
  }
  let (body, tokens) = parse_block_expr(tokens)
  let local_function = LocalFunction::{
    fname,
    param_list: params,
    ret_ty,
    body,
  }
  (local_function, tokens)
}

