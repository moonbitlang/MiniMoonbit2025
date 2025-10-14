test "Local Function Parsing Test - 1" {
  let code = 
    #|fn add(x, y) -> Int {
    #|  x + y;
    #|}
  let tokens = @lexer.tokenize(code)
  let (func, _) = parse_local_function(tokens)
  assert_true(func.fname is "add")
  assert_true(func.param_list.length() is 2)
  assert_true(func.param_list[0] is ("x", None))
  assert_true(func.param_list[1] is ("y", None))
  assert_true(func.ret_ty is Some({ kind: Int }))
  assert_true(func.body.stmts.length() is 1)
  assert_true(func.body.stmts[0].kind is ExprStmt(_))
}

test "Local Function Parsing Test - 2" {
  let code = 
    #|fn sin_max(x: Double, y) {
    #|  let sinx = sin(x);
    #|  let siny = sin(y);
    #|  if sinx > siny {
    #|    sinx;
    #|  } else {
    #|    siny;
    #|  };
    #|}

  let tokens = @lexer.tokenize(code)
  let (func, _) = parse_local_function(tokens)
  assert_true(func.fname is "sin_max")
  assert_true(func.param_list.length() is 2)
  assert_true(func.param_list[0] is ("x", Some({ kind: Double })))
  assert_true(func.param_list[1] is ("y", None))
  assert_true(func.ret_ty is None)
  assert_true(func.body.stmts.length() is 3)
  assert_true(func.body.stmts[0].kind is LetStmt(_))
  assert_true(func.body.stmts[1].kind is LetStmt(_))
  assert_true(func.body.stmts[2].kind is ExprStmt(_))
}

