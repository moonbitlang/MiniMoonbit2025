///|
test "Tokenize Symbols" {
  let code =
    #|( ) [ ] { } . , : ; -> => ! _
  let tokens = tokenize(code)
  assert_true(tokens.length() is 15)
  assert_true(tokens[0].kind is Bracket('('))
  assert_true(tokens[1].kind is Bracket(')'))
  assert_true(tokens[2].kind is Bracket('['))
  assert_true(tokens[3].kind is Bracket(']'))
  assert_true(tokens[4].kind is Bracket('{'))
  assert_true(tokens[5].kind is Bracket('}'))
  assert_true(tokens[6].kind is Symbol("."))
  assert_true(tokens[7].kind is Symbol(","))
  assert_true(tokens[8].kind is Symbol(":"))
  assert_true(tokens[9].kind is Symbol(";"))
  assert_true(tokens[10].kind is Symbol("->"))
  assert_true(tokens[11].kind is Symbol("=>"))
  assert_true(tokens[12].kind is Not)
  assert_true(tokens[13].kind is Wildcard)
  assert_true(tokens[14].kind is EOF)
}


