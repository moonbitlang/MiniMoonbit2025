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
