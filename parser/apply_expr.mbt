///|
pub(all) struct ApplyExpr {
  kind : ApplyExprKind
  toks : ArrayView[Token]
} derive(Show, Eq)

///|
pub(all) enum ApplyExprKind {
  AtomExpr(AtomExpr)
  ArrayAccess(ApplyExpr, Expr)
  FieldAccess(ApplyExpr, String)
  Call(ApplyExpr, Array[Expr])
} derive(Show, Eq)

fn ApplyExpr::unit() -> ApplyExpr {
  let atom_unit = AtomExpr::unit()
  ApplyExpr::{ kind: AtomExpr(atom_unit), toks: atom_unit.toks }
}

///|
pub fn ApplyExpr::new(
  kind : ApplyExprKind,
  init_tokens : ArrayView[Token],
  rest_tokens : ArrayView[Token],
) -> ApplyExpr {
  let len = rest_tokens.start_offset() - init_tokens.start_offset()
  let toks = init_tokens[0:len]
  ApplyExpr::{ kind, toks }
}

///|
pub fn parse_apply_expr(
  tokens : ArrayView[Token],
) -> (ApplyExpr, ArrayView[Token]) raise ParseError {
  let init_tokens = tokens
  let (atom_expr, tokens) = parse_atom_expr(tokens)
  let apply_expr = ApplyExpr::new(AtomExpr(atom_expr), init_tokens, tokens)
  if !(tokens is [{ kind: Bracket('[') | Symbol(".") | Bracket('('), .. }, ..]) {
    return (apply_expr, tokens)
  }
  let mut last_apply_line = atom_expr.toks[atom_expr.toks.length() - 1].line
  let mut apply_expr = apply_expr
  loop tokens {
    [{ kind: Bracket('['), line, .. }, .. tokens] if line == last_apply_line => {
      let (index_expr, tokens) = parse_expr(tokens)
      guard tokens is [{ kind: Bracket(']'), .. }, .. tokens] else {
        @lexer.throw_(tokens[0], "ParseError: Expect ']'", Error)
        raise ParseError("Expect ']'")
      }
      apply_expr = ApplyExpr::new(
        ArrayAccess(apply_expr, index_expr),
        init_tokens,
        tokens,
      )
      last_apply_line = tokens[0].line
      continue tokens
    }
    [{ kind: Symbol("."), line, .. }, { kind: Lower(field), .. }, .. tokens] if line == last_apply_line => {
      apply_expr = ApplyExpr::new(
        FieldAccess(apply_expr, field),
        init_tokens,
        tokens,
      )
      last_apply_line = tokens[0].line
      continue tokens
    }
    [{ kind: Bracket('('), line, .. }, .. tokens] if line == last_apply_line => {
      let (args, tokens) = parse_expr_list(tokens)
      guard tokens is [{ kind: Bracket(')'), .. }, .. tokens] else {
        @lexer.throw_(tokens[0], "ParseError: Expect ')'", Error)
        raise ParseError("Expect ')'")
      }
      apply_expr = ApplyExpr::new(
        Call(apply_expr, args),
        init_tokens,
        tokens,
      )
      continue tokens
    }
    tokens => break (apply_expr, tokens)
  }
}
