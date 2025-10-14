///|
test "Tokenize Int Number" {
  let code =
    #|42 0 65 15899 65355 78451 00012
  let tokens = tokenize(code)
  assert_true(tokens.length() is 8)
  assert_true(tokens[0].kind is Int(42))
  assert_true(tokens[1].kind is Int(0))
  assert_true(tokens[2].kind is Int(65))
  assert_true(tokens[3].kind is Int(15899))
  assert_true(tokens[4].kind is Int(65355))
  assert_true(tokens[5].kind is Int(78451))
  assert_true(tokens[6].kind is Int(12))
  assert_true(tokens[7].kind is EOF)
}

