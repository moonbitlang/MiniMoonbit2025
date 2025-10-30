///|
/// ================================================================================
/// # LLVM Codegen: 元组 (Tuples)
/// ================================================================================
///
/// 在处理完结构体之后，我们来处理一个与它非常相似的兄弟：**元组（Tuples）**。
///
/// ## 💡 核心思想：元组就是匿名的结构体
///
/// 从代码生成的角度来看，元组和结构体基本上是一个道理。你可以将一个元组 `(Int, Double)`
/// 想象成一个匿名的、只有字段序号没有字段名的结构体 `struct { Int; Double; }`。
///
/// - **内存布局**: 和结构体一样，元组也作为一块连续的内存存在，我们同样在**堆**上为其分配空间。
/// - **元素访问**: 访问元组的第 `n` 个元素，就和访问结构体的第 `n` 个字段完全一样。
///
/// 因此，生成元组相关代码的逻辑与我们上一关实现的结构体逻辑高度重合。
///
/// ## 🎯 你的任务
///
/// 本次挑战的目标是为元组的创建和访问生成代码。
///
/// ### 1. 元组创建 (`TupleLiteral`)
///
/// 在 `expr_codegen` 中处理 `TupleLiteral` 时：
/// a. **确定类型**: 首先，你需要根据元组中所有元素的 LLVM 类型，在 LLVM 中创建一个匿名的结构体类型，例如 `{ i32, double, i1 }`。
/// b. **分配内存**: 调用 `moonbit_malloc` 为这个匿名结构体分配堆内存。
/// c. **填充元素**: 遍历元组中的所有元素，对于第 `i` 个元素：
///    i.  使用 `getelementptr` 计算出第 `i` 个元素的地址。指令格式为：`getelementptr {..types..}, ptr %tuple_ptr, i32 0, i32 i`
///    ii. 使用 `builder.createStore` 将元素值存入该地址。
///
/// ### 2. 元组访问 (`TupleAccess` 或 `let` 解构)
///
/// 在 `expr_codegen` 中处理元组访问时（KNF 可能会将 `let (x,...) = t` 转换为对 `t` 的 `TupleAccess`）：
/// a. **获取元素指针**: 使用 `getelementptr` 计算出要访问的元素的地址。
/// b. **加载值**: 使用 `builder.createLoad` 从该地址加载元素的值。
///
/// ---
///
/// 本次测试 `codegen_tuple_test.mbt` 将检查你是否能正确地为元组的创建和访问生成代码。
///
/// 跟着下面的指引完成任务吧。
test "Codegen for Struct Create And Set Test" {
  let code =
    #|fn first(a: (Int, Double, Bool)) -> Int {
    #|  let (x, _, _) = a;
    #|  x;
    #|}
    #|
    #|fn combine(a: Int, b: Double, c: Bool) -> (Int, Double, Bool) {
    #|  let x = (a, b, c);
    #|  x;
    #|}
  let tokens = @lexer.tokenize(code)
  let ast = @parser.parse(tokens)
  let typed_ast = @typecheck.typecheck(ast)
  let knf_prog = @knf.knf_transform(typed_ast)
  let codegen_ctx = Context::new("demo")
  codegen_ctx.collect_func_values(knf_prog.functions)
  codegen_ctx.collect_struct_types(knf_prog.struct_defs)

  // 
  let first = knf_prog.functions.get("first").unwrap()
  let llvm_func = codegen_ctx.top_function_codegen(first)
  inspect(
    llvm_func,
    content=(
      #|define i32 @first(ptr %0) {
      #|entry:
      #|  %1 = getelementptr { i32, double, i1 }, ptr %0, i32 0, i32 0
      #|  %2 = load i32, ptr %1, align 4
      #|  %3 = getelementptr { i32, double, i1 }, ptr %0, i32 0, i32 1
      #|  %4 = load double, ptr %3, align 8
      #|  %5 = getelementptr { i32, double, i1 }, ptr %0, i32 0, i32 2
      #|  %6 = load i1, ptr %5, align 1
      #|  ret i32 %2
      #|}
      #|

    ),
  )
  let combine = knf_prog.functions.get("combine").unwrap()
  let llvm_func = codegen_ctx.top_function_codegen(combine)
  inspect(
    llvm_func,
    content=(
      #|define ptr @combine(i32 %0, double %1, i1 %2) {
      #|entry:
      #|  %3 = call ptr @moonbit_malloc(i32 24)
      #|  %4 = getelementptr { i32, double, i1 }, ptr %3, i32 0, i32 0
      #|  store i32 %0, ptr %4, align 4
      #|  %6 = getelementptr { i32, double, i1 }, ptr %3, i32 0, i32 1
      #|  store double %1, ptr %6, align 8
      #|  %8 = getelementptr { i32, double, i1 }, ptr %3, i32 0, i32 2
      #|  store i1 %2, ptr %8, align 1
      #|  ret ptr %3
      #|}
      #|

    ),
  )
}
