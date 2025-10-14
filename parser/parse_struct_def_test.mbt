
test "Struct Def Parsing Test" {
  let code = 
    #|struct Point {
    #|  x: Int;
    #|  mut y: Int;
    #|  z: Double;
    #|}
  let tokens = @lexer.tokenize(code)
  let (struct_def, _) = parse_struct_def(tokens)
  assert_true(struct_def.name is "Point")
  assert_true(struct_def.fields.length() is 3)
  assert_true(struct_def.fields[0] is { name: "x", is_mut: false, .. })
  assert_true(struct_def.fields[0].ty is { kind: Int })
  assert_true(struct_def.fields[1] is { name: "y", is_mut: true, .. })
  assert_true(struct_def.fields[1].ty is { kind: Int })
  assert_true(struct_def.fields[2] is { name: "z", is_mut: false, .. })
  assert_true(struct_def.fields[2].ty is { kind: Double })
}
