
test "Parse Struct Construct Expr" {
  let code = 
    #|Data::{ x: [1, 2, 3], y: (4, 5, 6) }

  let tokens = @lexer.tokenize(code)
  let (e, _) = parse_struct_construct(tokens[:])
  assert_true(
    e.kind is StructConstruct(s) &&
    s.name == "Data" &&
    s.fields is [f1, f2] &&
    f1 is ("x", expr1) &&
    f2 is ("y", expr2) &&
    expr1.kind is ApplyExpr(a1) &&
    a1.kind is AtomExpr(atom1) &&
    atom1.kind is Array([_, _, _]) &&
    expr2.kind is ApplyExpr(a2) &&
    a2.kind is AtomExpr(atom2) &&
    atom2.kind is Tuple([_, _, _]),
  )
}

