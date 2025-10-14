
///|
test "Skip Comments" {
  let code =
    #|fnx fn letp mut  // First line
    #|if else struct // Second line
    #|while return    // Third line
  let tokens = tokenize(code)
  assert_true(tokens.length() is 10)
  assert_true(tokens[0].kind is Lower("fnx"))
  assert_true(tokens[1].kind is Keyword(Fn))
  assert_true(tokens[2].kind is Lower("letp"))
  assert_true(tokens[3].kind is Keyword(Mut))
  assert_true(tokens[4].kind is Keyword(If))
  assert_true(tokens[5].kind is Keyword(Else))
  assert_true(tokens[6].kind is Keyword(Struct))
  assert_true(tokens[7].kind is Keyword(While))
  assert_true(tokens[8].kind is Keyword(Return))
  assert_true(tokens[9].kind is EOF)
}
