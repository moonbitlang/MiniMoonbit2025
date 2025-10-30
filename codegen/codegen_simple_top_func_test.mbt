///|
/// ================================================================================
/// # LLVM Codegen: 生成带返回值的函数
/// ================================================================================
///
/// 在上一个挑战中，我们成功生成了空函数体的 LLVM IR。现在，是时候让我们的函数做一些实际的事情了——返回一个值。
///
/// ## 🎯 你的任务
///
/// 本次挑战的目标是让 `top_function_codegen` 能够处理返回简单常量（如整数、浮点数、字符串）的函数。
/// 为了实现这一点，你需要开始填充另外两个关键的辅助函数：
///
/// ### 1. 实现 `expr_codegen` (在 `codegen/top_function.mbt` 中)
///
/// `expr_codegen` 函数负责将一个 KNF 表达式（`KnfExpr`）转换为对应的 LLVM 值（`@llvm.Value`）。
///
/// 你需要开始处理 `KnfExpr` 的几个基本情况：
///   - `Int(i)`: 使用 `llvm_ctx.getConstInt32(i)` 创建一个 LLVM 整数常量。
///   - `Double(d)`: 使用 `llvm_ctx.getConstDouble(d)` 创建一个 LLVM 浮点数常量。
///   - `Bool(b)`: 使用 `llvm_ctx.getConstTrue()` 或 `llvm_ctx.getConstFalse()`。
///   - `String(s)`: 使用 `builder.createGlobalString(s, name=...)` 创建一个全局字符串常量。
///     - **提示**：为全局字符串命名是个好习惯，可以避免冲突。你可以使用一个计数器（例如 `str_cnt`）来生成唯一的名字，如 `"str_lit_1"`, `"str_lit_2"` 等。
///
/// ### 2. 实现 `stmt_codegen` (在 `codegen/top_function.mbt` 中)
///
/// `stmt_codegen` 负责将 KNF 语句（`KnfStmt`）转换为 LLVM 指令。虽然本次挑战的核心在 `expr_codegen`，但 `top_function_codegen` 的逻辑会通过 `stmt_codegen` 来处理函数体的最后一条语句。
///
/// 你需要确保 `stmt_codegen` 能够处理 `Return(expr)` 和 `ExprStmt(expr)` 这两种情况，并最终调用 `expr_codegen` 来获取返回值。
///
/// ## 💡 关键逻辑
///
/// 在 `top_function_codegen` 中，当处理完函数体（`func.body`）后，你需要检查函数体的最后一条语句，以确定如何生成 `ret` 指令：
///
/// - **如果最后是 `Return(expr)` 或 `ExprStmt(expr)`**：
///   1. 调用 `expr_codegen(expr)` 获得 LLVM 值。
///   2. 使用 `builder.createRet(value)` 生成返回该值的指令。
///
/// - **如果函数体为空或最后一条语句不是返回表达式**：
///   1. 检查函数的返回类型。
///   2. 如果返回类型是 `void` (对应我们的 `Unit`)，则使用 `builder.createRetVoid()`。
///
/// 本次测试 `codegen_simple_top_func_test.mbt` 将检查你是否能为返回不同类型常量的函数正确生成 LLVM IR。
///
/// 跟着下面的指引完成任务吧。
test "Codegen for Simple Top Function Test" {
  let code =
    #|fn ret42() -> Int { 42 }
    #|
    #|fn ret_double_63() -> Double { 63.0 }
    #|
    #|fn hello() -> String {
    #|  "Hello, World!"
    #|}
  let tokens = @lexer.tokenize(code)
  let ast = @parser.parse(tokens)
  let typed_ast = @typecheck.typecheck(ast)
  let knf_prog = @knf.knf_transform(typed_ast)
  let codegen_ctx = Context::new("demo")
  codegen_ctx.collect_func_values(knf_prog.functions)
  let foo = knf_prog.functions.get("ret42").unwrap()
  let llvm_func = codegen_ctx.top_function_codegen(foo)
  inspect(
    llvm_func,
    content=(
      #|define i32 @ret42() {
      #|entry:
      #|  ret i32 42
      #|}
      #|

    ),
  )

  // ret_double_63
  let bar = knf_prog.functions.get("ret_double_63").unwrap()
  let llvm_func2 = codegen_ctx.top_function_codegen(bar)
  inspect(
    llvm_func2,
    content=(
      #|define double @ret_double_63() {
      #|entry:
      #|  ret double 0x404F800000000000
      #|}
      #|

    ),
  )

  // hello
  let baz = knf_prog.functions.get("hello").unwrap()
  let llvm_func3 = codegen_ctx.top_function_codegen(baz)
  inspect(
    llvm_func3,
    content=(
      #|define ptr @hello() {
      #|entry:
      #|  ret ptr @str_lit_1
      #|}
      #|

    ),
  )
}
