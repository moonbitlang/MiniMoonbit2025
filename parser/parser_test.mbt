
///|
test "Simple Type Parsing" {
  let code =
    #|Unit Int Bool Double
  let tokens = @lexer.tokenize(code)
  let (ty, tok_view) = parse_type(tokens[:])
  assert_true(ty.kind is Unit)
  let (ty, tok_view) = parse_type(tok_view)
  assert_true(ty.kind is Int)
  let (ty, tok_view) = parse_type(tok_view)
  assert_true(ty.kind is Bool)
  let (ty, _) = parse_type(tok_view)
  assert_true(ty.kind is Double)
}

test "Complex Type Parsing" {
  let code = 
    #|Array[Int]
    #|(Int, Double) 
    #|() -> Double
    #|((Int, Double), Unit)
    #|(Array[Bool], Unit) -> Double
    #|Array[(Int, Double)]
    #|Array[() -> Double]
    #|Array[((Int, Double), Unit)]

  let tokens = @lexer.tokenize(code)
  let (ty, tok_view) = parse_type(tokens[:])
  assert_true(ty.kind is Array(Int))
  let (ty, tok_view) = parse_type(tok_view)
  assert_true(ty.kind is Tuple([Int, Double]))
  let (ty, tok_view) = parse_type(tok_view)
  assert_true(ty.kind is Function([], Double))
  let (ty, tok_view) = parse_type(tok_view)
  assert_true(ty.kind is Tuple([Tuple([Int, Double]), Unit]))
  let (ty, tok_view) = parse_type(tok_view)
  assert_true(ty.kind is Function([Array(Bool), Unit], Double))
  let (ty, tok_view) = parse_type(tok_view)
  assert_true(ty.kind is Array(Tuple([Int, Double])))
  let (ty, tok_view) = parse_type(tok_view)
  assert_true(ty.kind is Array(Function([], Double)))
  let (ty, _) = parse_type(tok_view)
  assert_true(ty.kind is Array(Tuple([Tuple([Int, Double]), Unit])))
}
