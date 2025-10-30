/// ================================================================================
/// # 程序的顶层结构：解析顶层函数
///
/// 我们已经能够解析语句和块内的局部函数了。现在，我们终于来到了构成一个完整程序的
/// 基本单元：**顶层函数（Top-level Function）**。
///
/// ## 顶层函数 vs. 局部函数
///
/// 顶层函数与我们之前解析的局部函数非常相似，但有几个关键的、更严格的约束：
///
/// 1.  **类型注解：** 顶层函数的所有参数都**必须**有明确的类型注解。
/// 2.  **返回类型：** 顶层函数**必须**有明确的返回类型注解。
/// 3.  **main 函数特例：** `fn main { ... }` 是一个特殊的顶层函数，它没有参数，返回类型默认为 `Unit`。
///
/// ## 顶层函数的 EBNF 范式
///
/// ```
/// top_fn ::= "fn" ident "(" (param ("," param)*)? ")" "->" type block_expr
/// param  ::= ident ":" type
/// ```
///
/// **注意：** 这个 EBNF 描述的是一般情况。你需要特殊处理 `fn main`。
///
/// ## 🎯 你的任务：实现 `parse_top_function`
///
/// 你的任务是在 `parser/top_function.mbt` 中实现 `parse_top_function` 函数。
///
/// **实现思路：**
///
/// 这个函数的解析逻辑与 `parse_local_function` 高度重合，你甚至可以复用一些辅助函数（例如解析参数列表）。
/// 主要的区别在于你需要更严格地检查类型注解是否存在。
///
/// 1.  解析 `fn` 关键字和函数名。
/// 2.  **检查是否为 `main` 函数**，如果是，则参数列表为空，返回类型为 `Unit`，然后直接解析函数体。
/// 3.  如果不是 `main`，则严格按照 EBNF 解析带类型注解的参数列表和返回类型。
/// 4.  调用 `parse_block_expr` 解析函数体。
///
/// 相信这对你来说只是小试牛刀。加油！
///
/// **阶段性测试：**
///
/// ```bash
/// moon test -p parser -f parse_top_function_test.mbt
/// ```
/// ================================================================================

///|
test "Top Function Parsing Test - 1" {
  let code =
    #|fn add(x: Int, y: Int) -> Int {
    #|  x + y;
    #|}
  let tokens = @lexer.tokenize(code)
  let (func, _) = parse_top_function(tokens)
  assert_true(func.fname is "add")
  assert_true(func.param_list.length() is 2)
  assert_true(func.param_list[0] is { name: "x", ty: { kind: Int, .. } })
  assert_true(func.param_list[1] is { name: "y", ty: { kind: Int, .. } })
  assert_true(func.ret_ty is { kind: Int, .. })
  assert_true(func.body.stmts.length() is 1)
  assert_true(func.body.stmts[0].kind is ExprStmt(_))
}

///|
test "Main Function Parsing Test - 2 (main)" {
  let code =
    #|fn main {
    #|  let x = 10;
    #|  let y = 20;
    #|  println(x + y);
    #|}
  let tokens = @lexer.tokenize(code)
  let (func, _) = parse_top_function(tokens)
  assert_true(func.fname is "main")
  assert_true(func.param_list.length() is 0)
  assert_true(func.ret_ty is { kind: Unit, .. })
  assert_true(func.body.stmts.length() is 3)
  assert_true(func.body.stmts[0].kind is LetStmt(_))
  assert_true(func.body.stmts[1].kind is LetStmt(_))
  assert_true(func.body.stmts[2].kind is ExprStmt(_))
}
