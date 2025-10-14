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

///|
test "Tokenize Keyword" {
  let code =
    #|fn let mut if else struct return
  let tokens = tokenize(code)
  assert_true(tokens.length() is 8)
  assert_true(tokens[0].kind is Keyword(Fn))
  assert_true(tokens[1].kind is Keyword(Let))
  assert_true(tokens[2].kind is Keyword(Mut))
  assert_true(tokens[3].kind is Keyword(If))
  assert_true(tokens[4].kind is Keyword(Else))
  assert_true(tokens[5].kind is Keyword(Struct))
  assert_true(tokens[6].kind is Keyword(Return))
  assert_true(tokens[7].kind is EOF)
}

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

///|
test "Tokenize Punctuation" {
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

///|
test "Tokenize Code - 1" {
  let code =
    #|fn add(x: Int, y: Int) -> Int {
    #|  return x + y  // simple addition
    #|}
    #|
  let tokens = tokenize(code)
  assert_true(tokens[0].kind is Keyword(Fn))
  assert_true(tokens[1].kind is Lower("add"))
  assert_true(tokens[2].kind is Bracket('('))
  assert_true(tokens[3].kind is Lower("x"))
  assert_true(tokens[4].kind is Symbol(":"))
  assert_true(tokens[5].kind is Upper("Int"))
  assert_true(tokens[6].kind is Symbol(","))
  assert_true(tokens[7].kind is Lower("y"))
  assert_true(tokens[8].kind is Symbol(":"))
  assert_true(tokens[9].kind is Upper("Int"))
  assert_true(tokens[10].kind is Bracket(')'))
  assert_true(tokens[11].kind is Symbol("->"))
  assert_true(tokens[12].kind is Upper("Int"))
  assert_true(tokens[13].kind is Bracket('{'))
  assert_true(tokens[14].kind is Keyword(Return))
  assert_true(tokens[15].kind is Lower("x"))
  assert_true(tokens[16].kind is BinaryOp(Add))
  assert_true(tokens[17].kind is Lower("y"))
  assert_true(tokens[18].kind is Bracket('}'))
  assert_true(tokens[19].kind is EOF)
}

///|
test "Tokenize Code - 2" {
  let code =
    #|struct Point {
    #|  x: Double;
    #|  y: Double;
    #|}
    #|
    #|fn distance(p1: Point, p2: Point) -> Double {
    #|  let dx = p2.x - p1.x;
    #|  let dy = p2.y - p1.y;
    #|  return sqrt(dx * dx + dy * dy);
    #|}
  let tokens = tokenize(code)
  assert_true(tokens[0].kind is Keyword(Struct))
  assert_true(tokens[1].kind is Upper("Point"))
  assert_true(tokens[2].kind is Bracket('{'))
  assert_true(tokens[3].kind is Lower("x"))
  assert_true(tokens[4].kind is Symbol(":"))
  assert_true(tokens[5].kind is Upper("Double"))
  assert_true(tokens[6].kind is Symbol(";"))
  assert_true(tokens[7].kind is Lower("y"))
  assert_true(tokens[8].kind is Symbol(":"))
  assert_true(tokens[9].kind is Upper("Double"))
  assert_true(tokens[10].kind is Symbol(";"))
  assert_true(tokens[11].kind is Bracket('}'))
  assert_true(tokens[12].kind is Keyword(Fn))
  assert_true(tokens[13].kind is Lower("distance"))
  assert_true(tokens[14].kind is Bracket('('))
  assert_true(tokens[15].kind is Lower("p1"))
  assert_true(tokens[16].kind is Symbol(":"))
  assert_true(tokens[17].kind is Upper("Point"))
  assert_true(tokens[18].kind is Symbol(","))
  assert_true(tokens[19].kind is Lower("p2"))
  assert_true(tokens[20].kind is Symbol(":"))
  assert_true(tokens[21].kind is Upper("Point"))
  assert_true(tokens[22].kind is Bracket(')'))
  assert_true(tokens[23].kind is Symbol("->"))
  assert_true(tokens[24].kind is Upper("Double"))
  assert_true(tokens[25].kind is Bracket('{'))
  assert_true(tokens[26].kind is Keyword(Let))
  assert_true(tokens[27].kind is Lower("dx"))
  assert_true(tokens[28].kind is AssignOp(Assign))
  assert_true(tokens[29].kind is Lower("p2"))
  assert_true(tokens[30].kind is Symbol("."))
  assert_true(tokens[31].kind is Lower("x"))
  assert_true(tokens[32].kind is BinaryOp(Sub))
  assert_true(tokens[33].kind is Lower("p1"))
  assert_true(tokens[34].kind is Symbol("."))
  assert_true(tokens[35].kind is Lower("x"))
  assert_true(tokens[36].kind is Symbol(";"))
  assert_true(tokens[37].kind is Keyword(Let))
  assert_true(tokens[38].kind is Lower("dy"))
  assert_true(tokens[39].kind is AssignOp(Assign))
  assert_true(tokens[40].kind is Lower("p2"))
  assert_true(tokens[41].kind is Symbol("."))
  assert_true(tokens[42].kind is Lower("y"))
  assert_true(tokens[43].kind is BinaryOp(Sub))
  assert_true(tokens[44].kind is Lower("p1"))
  assert_true(tokens[45].kind is Symbol("."))
  assert_true(tokens[46].kind is Lower("y"))
  assert_true(tokens[47].kind is Symbol(";"))
  assert_true(tokens[48].kind is Keyword(Return))
  assert_true(tokens[49].kind is Lower("sqrt"))
  assert_true(tokens[50].kind is Bracket('('))
  assert_true(tokens[51].kind is Lower("dx"))
  assert_true(tokens[52].kind is BinaryOp(Mul))
  assert_true(tokens[53].kind is Lower("dx"))
  assert_true(tokens[54].kind is BinaryOp(Add))
  assert_true(tokens[55].kind is Lower("dy"))
  assert_true(tokens[56].kind is BinaryOp(Mul))
  assert_true(tokens[57].kind is Lower("dy"))
  assert_true(tokens[58].kind is Bracket(')'))
  assert_true(tokens[59].kind is Symbol(";"))
  assert_true(tokens[60].kind is Bracket('}'))
  assert_true(tokens[61].kind is EOF)
}
