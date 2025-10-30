/// ================================================================================
/// # 函数作为一等公民：解析局部函数与闭包
///
/// 在现代编程语言中，函数不仅仅是顶层的代码组织单元，它们还可以被定义在其他函数内部，
/// 甚至可以作为值被传递和返回。这种可以“捕获”其定义时所在环境（即访问外部变量）的内部函数，
/// 就是我们常说的**闭包（Closure）**。
///
/// MiniMoonBit 支持在代码块中定义**局部函数（Local Function）**，这是实现闭包的第一步。
///
/// ## 局部函数的 EBNF 范式
///
/// ```
/// fn_decl ::= "fn" ident "(" (param ("," param)*)? ")" ("->" type)? block_expr
/// param   ::= ident (":" type)?
/// ```
///
/// 这段范式描述了函数声明的各个部分：
/// 1.  `fn` 关键字和函数名 `ident`。
/// 2.  `()` 包裹的参数列表，参数之间用 `,` 分隔。
/// 3.  每个参数 `param` 包含一个名字 `ident` 和一个可选的类型注解。
/// 4.  一个可选的 `->` 和返回类型 `type`。
/// 5.  一个函数体 `block_expr`。
///
/// ## 🎯 你的任务：实现 `parse_local_function`
///
/// 你的任务是在 `parser/local_function.mbt` 中实现 `parse_local_function` 函数。
///
/// **实现思路：**
///
/// 解析函数的结构非常清晰，你可以严格按照 EBNF 的顺序进行：
/// 1.  解析 `fn` 关键字和函数名。
/// 2.  解析 `()` 包裹的参数列表。这部分是一个循环，你需要解析逗号分隔的 `ident` 和可选的类型。
/// 3.  解析可选的返回类型。
/// 4.  调用 `parse_block_expr` 解析函数体。
///
/// 经过了前面一系列的训练，这个任务对你来说应该已经驾轻就熟了。
///
/// 加油，这是我们向着一个功能更完备的语言迈出的重要一步！
///
/// **阶段性测试：**
///
/// ```bash
/// moon test -p parser -f parse_local_function_test.mbt
/// ```
/// ================================================================================

///|
test "Local Function Parsing Test - 1" {
  let code =
    #|fn add(x, y) -> Int {
    #|  x + y;
    #|}
  let tokens = @lexer.tokenize(code)
  let (func, _) = parse_local_function(tokens)
  assert_true(func.fname is "add")
  assert_true(func.param_list.length() is 2)
  assert_true(func.param_list[0] is ("x", None))
  assert_true(func.param_list[1] is ("y", None))
  assert_true(func.ret_ty is Some({ kind: Int, .. }))
  assert_true(func.body.stmts.length() is 1)
  assert_true(func.body.stmts[0].kind is ExprStmt(_))
}

///|
test "Local Function Parsing Test - 2" {
  let code =
    #|fn sin_max(x: Double, y) {
    #|  let sinx = sin(x);
    #|  let siny = sin(y);
    #|  if sinx > siny {
    #|    sinx;
    #|  } else {
    #|    siny;
    #|  };
    #|}
  let tokens = @lexer.tokenize(code)
  let (func, _) = parse_local_function(tokens)
  assert_true(func.fname is "sin_max")
  assert_true(func.param_list.length() is 2)
  assert_true(func.param_list[0] is ("x", Some({ kind: Double, .. })))
  assert_true(func.param_list[1] is ("y", None))
  assert_true(func.ret_ty is None)
  assert_true(func.body.stmts.length() is 3)
  assert_true(func.body.stmts[0].kind is LetStmt(_))
  assert_true(func.body.stmts[1].kind is LetStmt(_))
  assert_true(func.body.stmts[2].kind is ExprStmt(_))
}
