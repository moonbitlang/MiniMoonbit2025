///|
test "Tokenize Binary Operators" {
  let code =
    #|+ - * / % == != < > <= >= && || & | << >>
  let tokens = tokenize(code)
  assert_true(tokens.length() is 18)
  assert_true(tokens[0].kind is BinaryOp(Add))
  assert_true(tokens[1].kind is BinaryOp(Sub))
  assert_true(tokens[2].kind is BinaryOp(Mul))
  assert_true(tokens[3].kind is BinaryOp(Div))
  assert_true(tokens[4].kind is BinaryOp(Mod))
  assert_true(tokens[5].kind is BinaryOp(Eq))
  assert_true(tokens[6].kind is BinaryOp(NE))
  assert_true(tokens[7].kind is BinaryOp(LT))
  assert_true(tokens[8].kind is BinaryOp(GT))
  assert_true(tokens[9].kind is BinaryOp(LE))
  assert_true(tokens[10].kind is BinaryOp(GE))
  assert_true(tokens[11].kind is BinaryOp(And))
  assert_true(tokens[12].kind is BinaryOp(Or))
  assert_true(tokens[13].kind is BinaryOp(BitAnd))
  assert_true(tokens[14].kind is BinaryOp(BitOr))
  assert_true(tokens[15].kind is BinaryOp(ShiftLeft))
  assert_true(tokens[16].kind is BinaryOp(ShiftRight))
  assert_true(tokens[17].kind is EOF)
}

///|
test "Tokenize Assignment Operators" {
  let code =
    #|= += -= *= /= %=
  let tokens = tokenize(code)
  assert_true(tokens.length() is 7)
  assert_true(tokens[0].kind is AssignOp(Assign))
  assert_true(tokens[1].kind is AssignOp(PlusAssign))
  assert_true(tokens[2].kind is AssignOp(MinusAssign))
  assert_true(tokens[3].kind is AssignOp(MultAssign))
  assert_true(tokens[4].kind is AssignOp(DivAssign))
  assert_true(tokens[5].kind is AssignOp(ModAssign))
  assert_true(tokens[6].kind is EOF)
}


