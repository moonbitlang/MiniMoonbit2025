
///|
test "Tokenize Float Number" {
  let code =
    #|3.14 0.0 2.718 1.6180339887 0.57721 42.0
  let tokens = tokenize(code)
  assert_true(tokens.length() is 7)
  assert_true(tokens[0].kind is Double(3.14))
  assert_true(tokens[1].kind is Double(0.0))
  assert_true(tokens[2].kind is Double(2.718))
  assert_true(tokens[3].kind is Double(1.6180339887))
  assert_true(tokens[4].kind is Double(0.57721))
  assert_true(tokens[5].kind is Double(42.0))
  assert_true(tokens[6].kind is EOF)
}


