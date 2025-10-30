///|
/// ================================================================================
/// # LLVM Codegen: 二元运算
/// ================================================================================
///
/// 我们已经可以处理简单的变量和常量了。现在，我们来为代码生成添加“计算”能力，
/// 从处理二元运算（Binary Operations）开始。
///
/// ## 🎯 你的任务
///
/// 本次挑战的目标是扩展 `expr_codegen` 函数，使其能够处理 `KnfExpr::Binary` 表达式。
/// 你需要根据操作符的类型以及操作数的类型（整数或浮点数），调用正确的 LLVM IR Builder 接口。
///
/// ## 💡 LLVM Builder API 接口指南
///
/// LLVM 对整数和浮点数有不同的指令集。你需要通过检查操作数的类型（例如，`value.getType().isIEEELikeFPTy()`）
/// 来决定使用哪个系列的接口。
///
/// ### 整数算术运算
///
/// | 运算符 | LLVM Builder 接口 |
/// | :---: | :--- |
/// | `+`   | `createAdd`         |
/// | `-`   | `createSub`         |
/// | `*`   | `createMul`         |
/// | `/`   | `createSDiv`        | (有符号除法)
/// | `%`   | `createSRem`        | (有符号取余)
///
/// ### 浮点数算术运算
///
/// | 运算符 | LLVM Builder 接口 |
/// | :---: | :--- |
/// | `+`   | `createFAdd`        |
/// | `-`   | `createFSub`        |
/// | `*`   | `createFMul`        |
/// | `/`   | `createFDiv`        |
///
/// ### 比较运算
///
/// 比较运算会生成一个 `i1`（即布尔）类型的结果。
///
/// #### 整数比较 (`icmp`)
///
/// MoonBit 的 LLVM API 提供了对 LLVM `icmp` 指令的直接封装。
///
/// | 运算符 | MoonBit LLVM 接口 |
/// | :---: | :--- |
/// | `==`  | `createICmpEQ` |
/// | `!=`  | `createICmpNE` |
/// | `>`   | `createICmpSGT`| (Signed Greater Than)
/// | `>=`  | `createICmpSGE`|
/// | `<`   | `createICmpSLT`|
/// | `<=`  | `createICmpSLE`|
///
/// #### 浮点数比较 (`fcmp`)
///
/// 类似地，浮点数比较使用 `fcmp` 系列接口。
///
/// | 运算符 | MoonBit LLVM 接口 |
/// | :---: | :--- |
/// | `==`  | `createFCmpOEQ` | (Ordered Equal)
/// | `!=`  | `createFCmpONE` |
/// | `>`   | `createFCmpOGT` |
/// | `>=`  | `createFCmpOGE` |
/// | `<`   | `createFCmpOLT` |
/// | `<=`  | `createFCmpOLE` |
///
/// ---
///
/// 本次测试 `codegen_binary_test.mbt` 将检查你是否能为这些二元运算正确生成 LLVM IR。
///
/// 跟着下面的指引完成任务吧。
test "Codegen for Simple Binary Test" {
  let code =
    #|fn arith_int(x: Int, y: Int) -> Int {
    #|  let z = x + y;
    #|  let z = x - y;
    #|  let z = x * y;
    #|  let z = x / y;
    #|  let z = x % y;
    #|  z
    #|}
    #|
    #|fn arith_double(x: Double, y: Double) -> Double {
    #|  let z = x + y;
    #|  let z = x - y;
    #|  let z = x * y;
    #|  let z = x / y;
    #|  z
    #|}
    #|
    #|fn int_cmp(x: Int, y: Int) -> Bool {
    #|  let a = x == y;
    #|  let b = x != y;
    #|  let c = x < y;
    #|  let d = x <= y;
    #|  let e = x > y;
    #|  let f = x >= y;
    #|  f
    #|}
    #|
    #|fn double_cmp(x: Double, y: Double) -> Bool {
    #|  let a = x == y;
    #|  let b = x != y;
    #|  let c = x < y;
    #|  let d = x <= y;
    #|  let e = x > y;
    #|  let f = x >= y;
    #|  f
    #|}
  let tokens = @lexer.tokenize(code)
  let ast = @parser.parse(tokens)
  let typed_ast = @typecheck.typecheck(ast)
  let knf_prog = @knf.knf_transform(typed_ast)
  let codegen_ctx = Context::new("demo")
  codegen_ctx.collect_func_values(knf_prog.functions)

  // arith_int
  let arith_int = knf_prog.functions.get("arith_int").unwrap()
  let llvm_func = codegen_ctx.top_function_codegen(arith_int)
  inspect(
    llvm_func,
    content=(
      #|define i32 @arith_int(i32 %0, i32 %1) {
      #|entry:
      #|  %2 = add i32 %0, %1
      #|  %3 = sub i32 %0, %1
      #|  %4 = mul i32 %0, %1
      #|  %5 = sdiv i32 %0, %1
      #|  %6 = srem i32 %0, %1
      #|  ret i32 %6
      #|}
      #|

    ),
  )

  // arith_double
  let arith_double = knf_prog.functions.get("arith_double").unwrap()
  let llvm_func = codegen_ctx.top_function_codegen(arith_double)
  inspect(
    llvm_func,
    content=(
      #|define double @arith_double(double %0, double %1) {
      #|entry:
      #|  %2 = fadd double %0, %1
      #|  %3 = fsub double %0, %1
      #|  %4 = fmul double %0, %1
      #|  %5 = fdiv double %0, %1
      #|  ret double %5
      #|}
      #|

    ),
  )

  // int_cmp
  let int_cmp = knf_prog.functions.get("int_cmp").unwrap()
  let llvm_func = codegen_ctx.top_function_codegen(int_cmp)
  inspect(
    llvm_func,
    content=(
      #|define i1 @int_cmp(i32 %0, i32 %1) {
      #|entry:
      #|  %2 = icmp eq i32 %0, %1
      #|  %3 = icmp ne i32 %0, %1
      #|  %4 = icmp slt i32 %0, %1
      #|  %5 = icmp sle i32 %0, %1
      #|  %6 = icmp sgt i32 %0, %1
      #|  %7 = icmp sge i32 %0, %1
      #|  ret i1 %7
      #|}
      #|

    ),
  )

  // double_cmp
  let double_cmp = knf_prog.functions.get("double_cmp").unwrap()
  let llvm_func = codegen_ctx.top_function_codegen(double_cmp)
  inspect(
    llvm_func,
    content=(
      #|define i1 @double_cmp(double %0, double %1) {
      #|entry:
      #|  %2 = fcmp oeq double %0, %1
      #|  %3 = fcmp one double %0, %1
      #|  %4 = fcmp olt double %0, %1
      #|  %5 = fcmp ole double %0, %1
      #|  %6 = fcmp ogt double %0, %1
      #|  %7 = fcmp oge double %0, %1
      #|  ret i1 %7
      #|}
      #|

    ),
  )
}
