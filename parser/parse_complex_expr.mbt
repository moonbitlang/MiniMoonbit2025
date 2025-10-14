

test "Complex Expr Parsing Test" {
  let code = 
    #|(if a > b { a; } else { b; }) + (if c < d { c; } else { d; }) ;

  let tokens = @lexer.tokenize(code)
  let (e, _) = parse_expr(tokens)
  assert_true(
    e.kind is BinaryExpr(Add, l, r) &&
    l.kind is ApplyExpr(a1) &&
    a1.kind is AtomExpr(a1) &&
    a1.kind is Paren(a1) &&
    a1.kind is IfExpr(_) &&
    r.kind is ApplyExpr(a2) &&
    a2.kind is AtomExpr(a2) &&
    a2.kind is Paren(a2) &&
    a2.kind is IfExpr(_),
  )
}
