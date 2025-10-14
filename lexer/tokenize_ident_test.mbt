///|
test "Tokenize Identifiers - 1" {
  let code =
    #|MyStruct my_var anotherVar _privateVar
  let tokens = tokenize(code)
  assert_true(tokens.length() is 5)
  assert_true(tokens[0].kind is Upper("MyStruct"))
  assert_true(tokens[1].kind is Lower("my_var"))
  assert_true(tokens[2].kind is Lower("anotherVar"))
  assert_true(tokens[3].kind is Lower("_privateVar"))
  assert_true(tokens[4].kind is EOF)
}

///|
test "Tokenize Identifiers - 2" {
  let code =
    #|fnx let_var mutp iffy else_ match1 structc enum2
  let tokens = tokenize(code)
  assert_true(tokens.length() is 9)
  assert_true(tokens[0].kind is Lower("fnx"))
  assert_true(tokens[1].kind is Lower("let_var"))
  assert_true(tokens[2].kind is Lower("mutp"))
  assert_true(tokens[3].kind is Lower("iffy"))
  assert_true(tokens[4].kind is Lower("else_"))
  assert_true(tokens[5].kind is Lower("match1"))
  assert_true(tokens[6].kind is Lower("structc"))
  assert_true(tokens[7].kind is Lower("enum2"))
  assert_true(tokens[8].kind is EOF)
}

