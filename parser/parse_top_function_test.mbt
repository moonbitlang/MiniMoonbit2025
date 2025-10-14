test "Top Function Parsing Test - 1" {
  let code = 
    #|fn add(x: Int, y: Int) -> Int {
    #|  x + y;
    #|}
  let tokens = @lexer.tokenize(code)
  let (func, _) = parse_top_function(tokens)
  assert_true(func.fname is "add")
  assert_true(func.param_list.length() is 2)
  assert_true(func.param_list[0] is { name: "x", ty: { kind: Int } })
  assert_true(func.param_list[1] is { name: "y", ty: { kind: Int } })
  assert_true(func.ret_ty is { kind: Int })
  assert_true(func.body.stmts.length() is 1)
  assert_true(func.body.stmts[0].kind is ExprStmt(_))
}

test "Main Function Parsing Test - 2 (main)" {
  let code = 
    #|fn main {
    #|  let x = 10;
    #|  let y = 20;
    #|  println(x + y);
    #|}
  let tokens = @lexer.tokenize(code)
  let (func, _) = parse_top_function(tokens)
  assert_true(func.fname is "main")
  assert_true(func.param_list.length() is 0)
  assert_true(func.ret_ty is { kind: Unit })
  assert_true(func.body.stmts.length() is 3)
  assert_true(func.body.stmts[0].kind is LetStmt(_))
  assert_true(func.body.stmts[1].kind is LetStmt(_))
  assert_true(func.body.stmts[2].kind is ExprStmt(_))
}


