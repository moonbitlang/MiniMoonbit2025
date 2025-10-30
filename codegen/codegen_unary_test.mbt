///|
/// ================================================================================
/// # LLVM Codegen: 一元运算
/// ================================================================================
///
/// 在处理完二元运算后，我们来处理更简单的一元运算（Unary Operations）。
/// 在 MiniMoonBit 中，我们主要关心两种一元运算：取负 (`-`) 和逻辑非 (`!`)。
///
/// ## 🎯 你的任务
///
/// 本次挑战的目标是继续扩展 `expr_codegen` 函数，使其能够处理 `KnfExpr::Neg` 和 `KnfExpr::Not` 表达式。
///
/// ## 💡 实现指南
///
/// ### 逻辑非 `!`
///
/// 对于布尔类型的 `!b` 操作，一个标准且高效的实现方式是使用“异或”（XOR）运算：
///
/// `!b` 等价于 `b XOR true`
///
/// - **LLVM Builder 接口**: `builder.createXor(value, llvm_ctx.getConstTrue())`
///
/// ### 取负 `-`
///
/// 取负操作根据操作数的类型有不同的实现方式，这一点需要特别注意。
///
/// #### 整数取负
///
/// 对于整数 `-x`，LLVM 没有提供一个专门的 `neg` 指令。标准的实现方式是将其转换为减法：
///
/// `-x` 等价于 `0 - x`
///
/// - **LLVM Builder 接口**: `builder.createSub(zero, value)`
///
/// #### 浮点数取负
///
/// **⚠️ 请注意**: 对于浮点数 `-x`，你应该使用专门的 `fneg` 指令。
///
/// - **LLVM Builder 接口**: `builder.createFNeg(value)`
///
/// **为什么不能用 `0.0 - x`？**
///
/// 这是因为 IEEE 754 浮点数标准中存在两种零：`+0.0` 和 `-0.0`。
/// `fneg` 指令保证了它仅仅是翻转操作数的符号位，这是最精确和高效的方式。
/// 而 `0.0 - x` 作为一个减法运算，在某些涉及 `NaN` 或无穷大的边界情况下，其行为可能与 `fneg` 不同。
///
/// ---
///
/// 本次测试 `codegen_unary_test.mbt` 将检查你是否能为这几种一元运算正确生成 LLVM IR。
///
/// 跟着下面的指引完成任务吧。
test "Codegen for Simple Unary Test" {
  let code =
    #|fn neg_int(x: Int) -> Int {
    #|  let z = -x;
    #|  z
    #|}
    #|
    #|fn neg_double(x: Double) -> Double {
    #|  let z = -x;
    #|  z
    #|}
    #|
    #|fn not_bool(b: Bool) -> Bool {
    #|  let z = !b;
    #|  z
    #|}
  let tokens = @lexer.tokenize(code)
  let ast = @parser.parse(tokens)
  let typed_ast = @typecheck.typecheck(ast)
  let knf_prog = @knf.knf_transform(typed_ast)
  let codegen_ctx = Context::new("demo")
  codegen_ctx.collect_func_values(knf_prog.functions)

  // neg_int
  let neg_int = knf_prog.functions.get("neg_int").unwrap()
  let llvm_func = codegen_ctx.top_function_codegen(neg_int)
  inspect(
    llvm_func,
    content=(
      #|define i32 @neg_int(i32 %0) {
      #|entry:
      #|  %1 = sub i32 0, %0
      #|  ret i32 %1
      #|}
      #|

    ),
  )

  // neg_double
  let neg_double = knf_prog.functions.get("neg_double").unwrap()
  let llvm_func = codegen_ctx.top_function_codegen(neg_double)
  inspect(
    llvm_func,
    content=(
      #|define double @neg_double(double %0) {
      #|entry:
      #|  %1 = fneg double %0
      #|  ret double %1
      #|}
      #|

    ),
  )

  // not_bool
  let not_bool = knf_prog.functions.get("not_bool").unwrap()
  let llvm_func = codegen_ctx.top_function_codegen(not_bool)
  inspect(
    llvm_func,
    content=(
      #|define i1 @not_bool(i1 %0) {
      #|entry:
      #|  %1 = xor i1 true, %0
      #|  ret i1 %1
      #|}
      #|

    ),
  )
}
