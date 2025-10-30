///|
test "Codegen Call Test" {
  let code =
    #|fn add(x: Int, y: Int) -> Int {
    #|  x + y;
    #|}
    #|
    #|fn main {
    #|  let result = add(2, 3);
    #|  println(result);
    #|}
  let tokens = @lexer.tokenize(code)
  let ast = @parser.parse(tokens)
  let typed_ast = @typecheck.typecheck(ast)
  let knf_prog = @knf.knf_transform(typed_ast)
  let codegen_ctx = Context::new("demo")
  codegen_ctx.collect_func_values(knf_prog.functions)
  let func = knf_prog.functions.get("add").unwrap()
  let _ = codegen_ctx.top_function_codegen(func)
  let main_func = knf_prog.functions.get("main").unwrap()
  let main_ir = codegen_ctx.top_function_codegen(main_func)
  inspect(
    main_ir,
    content=(
      #|define void @moonbit_main() {
      #|entry:
      #|  %0 = call i32 @add(i32 2, i32 3)
      #|  call void @__builtin_println_int(i32 %0)
      #|  ret void 
      #|}
      #|

    ),
  )
}
