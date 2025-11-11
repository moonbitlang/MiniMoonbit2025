///|
/// ================================================================================
/// # LLVM Codegen: 数组的访问与更新
/// ================================================================================
///
/// 我们已经学会了如何创建数组。现在，我们来学习如何与数组进行交互：
/// 读取数组中的元素（`get`）和更新数组中的元素（`put`）。
///
/// ## 🎯 你的任务
///
/// 本次挑战的目标是扩展 `expr_codegen` 和 `stmt_codegen`，使其能够处理：
/// 1.  **数组访问表达式** (`KnfExpr::ArrayAccess`)
/// 2.  **数组更新语句** (`KnfStmt::ArrayPut`)
///
/// ## 💡 实现指南：调用内建函数
///
/// 与数组创建一样，对数组的访问和更新也是通过调用 `Context` 中预先定义好的内建函数来完成的。
/// 你需要做的就是根据数组的元素类型，选择正确的函数并使用 `builder.createCall` 来调用它。
///
/// ### 数组元素访问 (Get)
///
/// 在 `expr_codegen` 中处理 `ArrayAccess(array_name, index_name)` 时：
///
/// 1.  **确定类型**: 检查 `array_name` 的 KNF 类型，确定其元素类型（如 `Int`, `Double` 等）。
/// 2.  **选择函数**: 根据元素类型，从 `builtin_funcs` 中获取对应的 `get` 函数（如 `"array_int_get"`）。
/// 3.  **生成调用**: 使用 `createCall` 生成对该函数的调用，参数为数组的指针和索引值。
///
/// ### 数组元素更新 (Put)
///
/// 在 `stmt_codegen` 中添加一个新的分支来处理 `ArrayPut(array_name, index_name, value_expr)` 语句：
///
/// 1.  **计算右值**: 首先，调用 `expr_codegen` 计算出 `value_expr` 的 LLVM 值。
/// 2.  **确定类型**: 检查 `array_name` 的 KNF 类型以确定元素类型。
/// 3.  **选择函数**: 根据元素类型，从 `builtin_funcs` 中获取对应的 `put` 函数（如 `"array_int_put"`）。
/// 4.  **生成调用**: 使用 `createCall` 生成调用，参数为数组指针、索引值和要存入的新值。
///
/// ---
///
/// 本次测试 `codegen_array_acc_and_put_test.mbt` 将检查你是否能正确生成对 `get` 和 `put` 内建函数的调用。
///
/// 跟着下面的指引完成任务吧。
test "Codegen for Array Make Test" {
  let code =
    #|fn swap_head_two(arr: Array[Int]) -> Unit {
    #|  let t = arr[0];
    #|  arr[0] = arr[1];
    #|  arr[1] = t;
    #|}
  let tokens = @lexer.tokenize(code)
  let ast = @parser.parse(tokens)
  let typed_ast = @typecheck.typecheck(ast)
  let knf_prog = @knf.knf_transform(typed_ast)
  let codegen_ctx = Context::new("demo")
  codegen_ctx.collect_func_values(knf_prog.functions)

  // make_arr
  let swap_head_two = knf_prog.functions.get("swap_head_two").unwrap()
  let llvm_func = codegen_ctx.top_function_codegen(swap_head_two)
  inspect(
    llvm_func,
    content=(
      #|define void @swap_head_two(ptr %0) {
      #|entry:
      #|  %1 = call i32 @array_int_get(ptr %0, i32 0)
      #|  %2 = call i32 @array_int_get(ptr %0, i32 1)
      #|  call void @array_int_put(ptr %0, i32 0, i32 %2)
      #|  call void @array_int_put(ptr %0, i32 1, i32 %1)
      #|  ret void
      #|}
      #|
    ),
  )
}

///|
/// ================================================================================
/// # LLVM Codegen: 数组字面量
/// ================================================================================
///
/// 我们已经学习了 `Array::make`，现在我们来处理另一种更直观的数组创建方式：**数组字面量（Array Literals）**，例如 `[1, 2, 3]`。
///
/// ## 🎯 你的任务
///
/// 本次挑战的目标是扩展 `expr_codegen` 函数，使其能够处理 `KnfExpr::ArrayLiteral` 表达式。
///
/// ## 💡 实现指南：三步走
///
/// 生成数组字面量的代码可以分解为三个步骤：
///
/// 1.  **创建空数组**:
///     首先，调用我们之前实现的 `make_..._array` 内建函数来创建一个指定大小但内容为默认值的数组。
///     - **大小**: 数组字面量中的元素数量。
///     - **初始值**: 可以是该类型的任意默认值（例如 `0` 或 `false`），因为它马上就会被覆盖。
///
/// 2.  **逐个填充元素**:
///     遍历数组字面量中的每一个元素。对于每个元素，生成一个 `array_..._put` 调用，
///     将元素的值设置到数组对应的索引位置上。
///
/// 3.  **返回数组**:
///     最后，返回第一步中创建的数组的指针。
///
/// 简单来说，`[1, 2, 3]` 的代码生成逻辑等价于：
///
/// ```skip
/// let __internal_array = Array::make(3, 0); // 步骤 1
/// __internal_array[0] = 1;                  // 步骤 2
/// __internal_array[1] = 2;
/// __internal_array[2] = 3;
/// __internal_array;                         // 步骤 3
/// ```
///
/// 同样，你需要根据数组的元素类型，从 `Context` 的 `builtin_funcs` 中选择正确的 `make` 和 `put` 函数，并使用 `createCall` 来调用它们。
///
/// ---
///
/// 本次测试 `codegen_array_expr_test.mbt` 将检查你是否能为数组字面量正确生成创建和填充指令。
///
/// 跟着下面的指引完成任务吧。
test "Codegen for Array Literal Test" {
  let code =
    #|fn create_arr() -> Array[Int] {
    #|  [1, 2, 3];
    #|}
  let tokens = @lexer.tokenize(code)
  let ast = @parser.parse(tokens)
  let typed_ast = @typecheck.typecheck(ast)
  let knf_prog = @knf.knf_transform(typed_ast)
  let codegen_ctx = Context::new("demo")
  codegen_ctx.collect_func_values(knf_prog.functions)

  // codegen
  let create_arr = knf_prog.functions.get("create_arr").unwrap()
  let llvm_func = codegen_ctx.top_function_codegen(create_arr)
  inspect(
    llvm_func,
    content=(
      #|define ptr @create_arr() {
      #|entry:
      #|  %0 = call ptr @make_int_array(i32 3, i32 0)
      #|  call void @array_int_put(ptr %0, i32 0, i32 1)
      #|  call void @array_int_put(ptr %0, i32 1, i32 2)
      #|  call void @array_int_put(ptr %0, i32 2, i32 3)
      #|  ret ptr %0
      #|}
      #|
    ),
  )
}

///|
test "Codegen for Array Make Test - 2" {
  let code =
    #|fn make_arr(x: Int) -> Array[Int] {
    #|  let arr = Array::make(x, 0);
    #|  arr
    #|}
  let tokens = @lexer.tokenize(code)
  let ast = @parser.parse(tokens)
  let typed_ast = @typecheck.typecheck(ast)
  let knf_prog = @knf.knf_transform(typed_ast)
  let codegen_ctx = Context::new("demo")
  codegen_ctx.collect_func_values(knf_prog.functions)

  // make_arr
  let make_arr = knf_prog.functions.get("make_arr").unwrap()
  let llvm_func = codegen_ctx.top_function_codegen(make_arr)
  inspect(
    llvm_func,
    content=(
      #|define ptr @make_arr(i32 %0) {
      #|entry:
      #|  %1 = call ptr @make_int_array(i32 %0, i32 0)
      #|  ret ptr %1
      #|}
      #|
    ),
  )
}

///|
///
test "Codegen for Simple Let and LetMut Test" {
  let code =
    #|fn foo(x: Int) -> Int {
    #|  let mut z = 0;
    #|  z = x;
    #|  z
    #|}
  let tokens = @lexer.tokenize(code)
  let ast = @parser.parse(tokens)
  let typed_ast = @typecheck.typecheck(ast)
  let knf_prog = @knf.knf_transform(typed_ast)
  let codegen_ctx = Context::new("demo")
  codegen_ctx.collect_func_values(knf_prog.functions)

  // foo
  let add = knf_prog.functions.get("foo").unwrap()
  let llvm_func = codegen_ctx.top_function_codegen(add)
  inspect(
    llvm_func,
    content=(
      #|define i32 @foo(i32 %0) {
      #|entry:
      #|  %1 = alloca i32, align 4
      #|  store i32 0, ptr %1, align 4
      #|  store i32 %0, ptr %1, align 4
      #|  %4 = load i32, ptr %1, align 4
      #|  ret i32 %4
      #|}
      #|
    ),
  )
}

///|
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

///|
///
test "Codegen for Simple Let and LetMut Test - 2" {
  let code =
    #|fn foo(x: Int, y: Int) -> Int {
    #|  let z = { let a = x + 1; let b = y -1; a * b };
    #|  z
    #|}
  let tokens = @lexer.tokenize(code)
  let ast = @parser.parse(tokens)
  let typed_ast = @typecheck.typecheck(ast)
  let knf_prog = @knf.knf_transform(typed_ast)
  let codegen_ctx = Context::new("demo")
  codegen_ctx.collect_func_values(knf_prog.functions)

  // foo
  let foo = knf_prog.functions.get("foo").unwrap()
  let llvm_func = codegen_ctx.top_function_codegen(foo)
  inspect(
    llvm_func,
    content=(
      #|define i32 @foo(i32 %0, i32 %1) {
      #|entry:
      #|  br label %3
      #|
      #|3:                                     ; preds = %entry
      #|  %4 = add i32 %0, 1
      #|  %5 = sub i32 %1, 1
      #|  %6 = mul i32 %4, %5
      #|  br label %8
      #|
      #|8:                                     ; preds = %3
      #|  ret i32 %6
      #|}
      #|
    ),
  )
}

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

///|
test "Codegen Closure Test" {
  let code =
    #|fn make_adder(x: Int) -> (Int) -> Int {
    #|  fn adder(y: Int) -> Int {
    #|    x + y;
    #|  }
    #|  adder;
    #|}
    #|
    #|fn main {
    #|  let add_five = make_adder(5);
    #|  let result = add_five(10);
    #|  println(result);
    #|}
  let tokens = @lexer.tokenize(code)
  let ast = @parser.parse(tokens)
  let typed_ast = @typecheck.typecheck(ast)
  let knf_prog = @knf.knf_transform(typed_ast)
  let codegen_ctx = Context::new("demo")
  codegen_ctx.collect_func_values(knf_prog.functions)
  let make_adder_func = knf_prog.functions.get("make_adder").unwrap()
  let make_adder_ir = codegen_ctx.top_function_codegen(make_adder_func)
  inspect(
    make_adder_ir,
    content=(
      #|define ptr @make_adder(i32 %0) {
      #|entry:
      #|  %1 = call ptr @moonbit_malloc(i32 16)
      #|  %2 = getelementptr { ptr, i32 }, ptr %1, i32 0, i32 0
      #|  store ptr @make_adder$adder, ptr %2, align 8
      #|  %4 = getelementptr { ptr, i32 }, ptr %1, i32 0, i32 1
      #|  store i32 %0, ptr %4, align 4
      #|  ret ptr %1
      #|}
      #|
    ),
  )
  let main_func = knf_prog.functions.get("main").unwrap()
  let main_ir = codegen_ctx.top_function_codegen(main_func)
  inspect(
    main_ir,
    content=(
      #|define void @moonbit_main() {
      #|entry:
      #|  %0 = call ptr @make_adder(i32 5)
      #|  %1 = getelementptr { ptr }, ptr %0, i32 0, i32 0
      #|  %2 = load ptr, ptr %1, align 8
      #|  %3 = call i32 %2(ptr %0, i32 10)
      #|  call void @__builtin_println_int(i32 %3)
      #|  ret void 
      #|}
      #|
    ),
  )
}
/// ================================================================================
/// # LLVM Codegen
//
// 在我们深入代码生成之前，理解两个核心概念至关重要：SSA 和 LLVM。
//
// ## 静态单赋值（Static Single Assignment, SSA）
//
// SSA 是一种中间表示（IR）的特性，它要求每个变量都只被赋值一次。
// 如果在原始代码中一个变量被多次赋值，那么在 SSA 形式中，每次赋值都会创建一个新的、带版本号的变量。
//
// 例如，下面的代码：
//
// ```
// let mut x = 1;
// x = x + 1;
// ```
//
// 在 SSA 形式下会变成：
//
// ```
// x_1 = 1;
// x_2 = x_1 + 1;
// ```
//
// **为什么 SSA 如此重要？**
//
// 这种形式极大地简化了编译器的优化过程。例如：
// - **常量传播**：如果 `x_1` 是一个常量，编译器可以立即将所有使用 `x_1` 的地方替换为该常量。
// - **死码消除**：如果一个变量（如 `x_2`）从未被使用过，编译器可以安全地移除创建它的那行代码。
//
// 我们的 KNF（Kernel Normal Form）中间表示就是为生成 SSA 形式的代码做准备的。
//
// ## LLVM：现代编译器的基石
//
// LLVM 最初是“底层虚拟机”（Low Level Virtual Machine）的缩写，但现在它已经发展成为一个庞大的、
// 包含一系列模块化和可重用编译器及工具链技术的总称。它不仅仅是一个编译器，更是一个“编译器的编译器”。
//
// **LLVM 的核心是其强大且定义良好的中间表示（LLVM IR），而 LLVM IR 正是基于 SSA 的。**
//
// **工作流程：**
//
// 1.  **前端（Frontend）**：像我们正在构建的 MiniMoonBit 编译器，负责将源代码（`.mbt` 文件）解析、类型检查，并转换为中间表示（我们的 KNF）。
// 2.  **中间表示转换**：我们将 KNF 转换为 LLVM IR。
// 3.  **LLVM 优化器（Optimizer）**：LLVM 会对生成的 IR 进行大量的优化，使其更高效。
// 4.  **后端（Backend）/代码生成器（Code Generator）**：LLVM 将优化后的 IR 转换为特定硬件平台（如 x86, ARM）的机器码。
//
// 通过利用 LLVM，我们无需从零开始编写复杂的优化算法和针对不同硬件的代码生成器，
// 而是可以站在巨人的肩膀上，生成高质量、高性能的机器码。
//
// 在接下来的挑战中，你将亲手使用 MoonBit 的 LLVM API 来将 KNF 转换为 LLVM IR。
//
// 跟着下面的指引完成任务吧。
/// ================================================================================

///|
///
/// demo_add创建了一个简单的LLVM函数来添加两个整数。
/// 如果我们写C代码，就像这样：
///
/// ```c
/// int add(int a, int b) {
///   return a + b;
/// }
/// ```
///
/// 你的任务是实现demo_add下面的demo_fma代码，逻辑为：
///
/// ```c
/// double fma(double a, double b, double c) {
///   return a * b + c;
/// }
/// ```
///
/// 提示：
///
/// - 使用 `getDoubleTy` 来获取 double 类型。
/// - 使用 `createFMul` 来创建浮点乘法指令。
/// - 使用 `createFAdd` 来创建浮点加法指令。
fn demo_add() -> @llvm.Function raise {
  // Context是LLVM的核心对象，管理着所有的LLVM数据结构。
  // 例如类型、模块和指令生成器等。
  let ctx = @llvm.Context::new()

  // 使用context来创建一个模块。模块是LLVM中代码的容器。
  let mod = ctx.addModule("demo")

  // 指令生成器用于在基本块中生成LLVM指令。
  // 记得在生成指令前设置插入点。
  // 使用`setInsertPoint`方法设置插入点。`
  let builder = ctx.createBuilder()

  // 创建函数类型和函数。使用`getInt32Ty`获取32位整数类型。
  let i32ty = ctx.getInt32Ty()

  // 使用`getFunctionType`创建函数类型，传入返回类型和参数类型列表。
  // 在原始的llvm C接口中，函数类型还需要一个布尔值参数表示是否是可变参数函数。
  // 在MoonBit中，这个参数被标记成label参数，允许省略。
  // 在我们的教程中，所有函数都不是可变参数函数，所以可以省略这个参数。
  let fn_type = ctx.getFunctionType(i32ty, [i32ty, i32ty])

  // 创建函数对象，注意函数在模块中创建。
  // 因此需要调用的是模块的方法`addFunction`。
  let fval = mod.addFunction(fn_type, "add")

  // 创建基本块对象，注意基本块在函数中创建。
  // 因此需要调用的是函数的方法`addBasicBlock`。
  let entry_bb = fval.addBasicBlock(name="entry")

  // 接下来在基本块中生成指令。需要使用builder来构建指令，在构建指令前需要设置插入点。
  builder.setInsertPoint(entry_bb)

  // 获得参数，我们已经知道函数有两个参数，因此直接使用getArg(index).unwrap()来获取参数。
  // getArg之后unwrap，得到的类型是一个`&Value`，它是一个trait Object。在llvm里，我们会有
  // 很多种不同的Value，例如指令，常量，函数参数等，它们都实现了Value这个trait。
  let arg0 = fval.getArg(0).unwrap()
  let arg1 = fval.getArg(1).unwrap()

  // 创建加法指令，使用createAdd方法。所有的指令创建方法都在builder对象上。
  // 它接收两个`&Value`参数，有一个label argument用于给指令命名。
  // 你可以省略label argument.
  //
  // 注意，createAdd方法接收的两个参数必须是整数类型。且类型需要一致，如果不一致，会出现运行时
  // 错误。
  //
  // 如果是浮点数加法，需要使用createFAdd方法，其他类似。
  let sum = builder.createAdd(arg0, arg1, name="sum")

  // 创建返回指令，使用createRet方法，注意createRet方法会返回一个指令对象，
  // 但我们这里不需要使用它，因此使用let _来忽略它。
  let _ = builder.createRet(sum)

  // 返回函数对象。
  // 如果你调用这个函数生成LLVM IR代码，可以看到生成的代码如下：
  //
  // ```llvm
  // ; ModuleID = 'demo'
  //
  // define i32 @add(i32 %0, i32 %1) {
  // entry:
  //  %sum = add i32 %0, %1
  //  ret i32 %sum
  // }
  // ```
  fval
}

///|
fn demo_fma() -> @llvm.Function raise {
  let ctx = @llvm.Context::new()
  let mod = ctx.addModule("demo_fma")
  let builder = ctx.createBuilder()
  let double_ty = ctx.getDoubleTy()
  let fn_type = ctx.getFunctionType(double_ty, [double_ty, double_ty, double_ty])
  let fval = mod.addFunction(fn_type, "fma")
  let entry_bb = fval.addBasicBlock(name="entry")
  builder.setInsertPoint(entry_bb)
  let arg0 = fval.getArg(0).unwrap()
  let arg1 = fval.getArg(1).unwrap()
  let arg2 = fval.getArg(2).unwrap()
  let mul = builder.createFMul(arg0, arg1, name="mul")
  let result = builder.createFAdd(mul, arg2, name="result")
  let _ = builder.createRet(result)
  fval
}

///|
test "LLVM Codegen Demo Test" {
  let add = demo_add()
  inspect(
    add,
    content=(
      #|define i32 @add(i32 %0, i32 %1) {
      #|entry:
      #|  %sum = add i32 %0, %1
      #|  ret i32 %sum
      #|}
      #|
    ),
  )
  let fadd = demo_fma()
  inspect(
    fadd,
    content=(
      #|define double @fma(double %0, double %1, double %2) {
      #|entry:
      #|  %mul = fmul double %0, %1
      #|  %result = fadd double %mul, %2
      #|  ret double %result
      #|}
      #|
    ),
  )
}
/// ================================================================================
/// # LLVM Codegen: 创建结构体类型
///
/// 在上一个挑战中，我们学习了如何创建简单的 LLVM 函数。现在，我们将学习如何在 LLVM 中定义复合类型，
/// 即**结构体（Structs）**。
///
/// ## 什么是 LLVM 结构体类型？
///
/// LLVM 中的结构体类型与 C 语言中的 `struct` 非常相似。它允许我们将多个不同类型的数据成员（字段）
/// 组合成一个单一的、连续的内存块。这对于表示复杂的数据结构，如坐标点、用户信息或 AST 节点至关重要。
///
/// LLVM 支持两种结构体类型：
///
/// 1.  **字面结构体（Literal Structs）**：它们是匿名的，通过其字段的类型序列来定义，例如 `{ i32, double }`。
/// 2.  **已识别结构体（Identified Structs）**：它们有自己的名字，例如 `%Point = type { i32, i32 }`。
///     在我们的编译器中，我们将主要使用已识别结构体，因为它们更易于调试和引用。
///
/// ## 🛠️ 如何创建结构体类型？
///
//  在 MoonBit 的 LLVM API 中，创建结构体类型非常直接：
///
/// 1.  **获取上下文（Context）**：和之前一样，所有操作都始于 `llvm.Context`。
///
/// 2.  **获取字段类型**：使用 `ctx.getInt32Ty()`、`ctx.getDoubleTy()` 等方法获取构成结构体的基本类型。
///
/// 3.  **创建结构体类型**：调用 `ctx.getStructType` 方法。
///
///     ```moonbit
///     let struct_ty = ctx.getStructType(
///       [i32ty, f64ty], // 字段类型的数组
///       name="i32_f64"  // 结构体的名字（推荐）
///     );
///     ```
///
///     - 第一个参数是一个包含所有字段类型的 `Array`。
///     - `name` 是一个可选的标签参数，用于给结构体命名。为结构体命名是一个好习惯，
///       因为它允许我们稍后通过 `ctx.getStructTypeByName("i32_f64")` 来引用它，避免重复定义。
///
/// ## 🎯 你的任务
///
/// 在这个文件中，`demo_i32_f64` 函数已经为你展示了如何创建一个包含 `i32` 和 `f64` 两个字段的结构体。
///
/// 你的任务是模仿它，完成 `demo_i8_i16_i32_f32_f64` 函数，创建一个包含 `i8`, `i16`, `i32`, `f32`, `f64` 五种类型的结构体。
///
/// 跟着下面的指引完成任务吧。
/// ================================================================================

///|
///
/// demo_i32_f64创建了一个包含i32和f64两个字段的结构体类型。
/// 在C语言里，这相当于定义了如下结构体：
///
/// ```c
/// struct i32_f64 {
///   int32_t a;
///   double b;
/// };
/// ```
///
/// 你的任务是实现demo_i8_i16_i32_f32_f64函数，
/// 创建一个包含i8、i16、i32、f32和f64五个字段的结构体类型。
///
/// 在C语言里，这相当于定义了如下结构体：
///
/// ```c
/// struct i8_i16_i32_f32_f64 {
///   int8_t a;
///   int16_t b;
///   int32_t c;
///   float d;
///   double e;
/// };
/// ```
///
/// 提示：
///
/// - 使用 `getInt8Ty` 来获取 i8 类型。
/// - 使用 `getInt16Ty` 来获取 i16 类型。
/// - 使用 `getInt32Ty` 来获取 i32 类型。
/// - 使用 `getFloatTy` 来获取 f32 类型。
/// - 使用 `getDoubleTy` 来获取 f64 类型。
///
/// 提醒：
///
/// 1. getStructType有一个label参数name，可以用来给结构体命名，
/// llvm允许定义匿名结构体，如果不传name参数，则创建的是匿名结构体类型。
///
/// 但建议在定义结构体类型时，最好给结构体命名。
///
/// 其中的一个重要原因，是命名的结构体可以使用context的`getStructTypeByName`方法来获取。
/// 从而避免重复定义相同名称的结构体类型。
///
/// 2. 在打印结构体时，如果直接用`println(struct_ty)`，
/// 对于非匿名的结构体类型，输出可能只显示结构体的名称。
/// 如果需要查看结构体的详细信息，可以使用`struct_ty.full_info()`方法。
fn demo_i32_f64() -> @llvm.StructType raise {
  let ctx = @llvm.Context::new()
  let i32ty = ctx.getInt32Ty()
  let f64ty = ctx.getDoubleTy()
  let struct_ty = ctx.getStructType([i32ty, f64ty], name="i32_f64")
  struct_ty
}

///|
pub fn demo_i8_i16_i32_f32_f64() -> @llvm.StructType raise {
  let ctx = @llvm.Context::new()
  let i8ty = ctx.getInt8Ty()
  let i16ty = ctx.getInt16Ty()
  let i32ty = ctx.getInt32Ty()
  let f32ty = ctx.getFloatTy()
  let f64ty = ctx.getDoubleTy()
  let struct_ty = ctx.getStructType(
    [i8ty, i16ty, i32ty, f32ty, f64ty],
    name="i8_i16_i32_f32_f64",
  )
  struct_ty
}

///|
test "Codegen Demo Struct Test" {
  let s = demo_i32_f64()
  inspect(s.full_info(), content="%i32_f64 = type { i32, double }")

  //
  let s = demo_i8_i16_i32_f32_f64()
  inspect(
    s.full_info(),
    content="%i8_i16_i32_f32_f64 = type { i8, i16, i32, float, double }",
  )
}
/// ================================================================================
/// # LLVM Codegen: 生成顶层函数
///
/// 恭喜你，我们已经完成了 KNF IR 的学习，现在正式进入代码生成的最后阶段：**LLVM IR 生成**。
/// 在这个阶段，我们会将 KNF 形式的程序逐一转换为 LLVM IR。
///
/// ## 💡 两阶段代码生成（Two-Pass Codegen）
///
/// 与Knf类似，llvm代码生成也采用“两阶段”策略来处理函数间的相互调用和递归。
///
/// 1.  **第一阶段（收集）**：遍历整个 KNF 程序，但不生成任何函数体。我们只收集所有函数和结构体的“签名”信息，
///     并在 LLVM 中创建对应的、但尚无内容的函数（Function）和结构体类型（StructType）。
///     这样，LLVM 就知道了每个函数的名字、参数和返回类型。
///
/// 2.  **第二阶段（生成）**：再次遍历 KNF 程序，这次我们真正进入每个函数内部，生成其函数体的 LLVM IR 指令。
///     由于第一阶段已经创建了所有函数的声明，所以在生成函数体时，我们可以自由地调用其他任何函数。
///
/// ## 🎯 你的任务
///
/// 本次挑战的目标是完成第一阶段的大部分工作，并为第二阶段生成一个最简单的函数。
///
/// ### 1. 阅读并实现 `context.mbt`
///
/// 首先，请仔细阅读 `codegen/context.mbt` 文件。你需要实现以下两个核心的“收集”函数：
///
///   - `collect_struct_types(struct_defs)`: 遍历 KNF 的结构体定义，并在 LLVM 中创建对应的 `StructType`。
///   - `collect_func_values(functions)`: 遍历 KNF 的函数定义，并在 LLVM 中创建对应的 `Function` **声明**。
///     **注意**：在这一步，我们**暂时不处理函数体**，只创建函数的签名。
///
/// ### 2. 实现 `top_function_codegen`
///
/// 接下来，在 `codegen/top_function.mbt` 中，你需要实现 `top_function_codegen` 函数。
/// 这个函数负责为单个 KNF 函数生成完整的 LLVM IR，包括函数体。
///
/// **LLVM API 关键提示：**
///
/// - **创建基本块**：一个函数至少需要一个入口基本块（Basic Block）。使用 `@llvm.Function::addBasicBlock` 来创建它。
///
/// - **设置插入点**：在生成指令之前，你必须告诉 LLVM 指令应该被插入到哪里。使用 `@llvm.IRBuilder::setInsertPoint` 将插入点设置到你创建的基本块上。
///
/// - **创建返回指令**：一个合法的 LLVM 基本块必须以一个“终结指令”（Terminator Instruction）结束，最常见的就是返回指令。
///   - 如果函数有返回值，使用 `builder.createRet(...)`。
///   - 如果函数返回 `Unit` (即 C 中的 `void`)，使用 `builder.createRetVoid()`。
///   - 你需要判断函数的返回类型，以决定是否以及如何添加 `ret` 指令。
///
/// 本次测试 `codegen_empty_top_func_test.mbt` 将会检查你是否能为一个没有参数和具体逻辑的空函数正确生成 LLVM IR。
///
/// 跟着下面的指引完成任务吧。
/// ================================================================================

///|
///
/// 务必注意，任何的函数的第一个参数都是隐式传入的环境指针。
/// 无论它是否是Top Level Function，也无论它是否从词法环境中捕获了变量。
///
/// 这样才能更方便地支持闭包的实现。
test "Codegen for Empty Top Function Test" {
  let code =
    #|fn foo() -> Unit {}
    #|
    #|fn bar(x: Int, y: Double) -> Unit {}
  let tokens = @lexer.tokenize(code)
  let ast = @parser.parse(tokens)
  let typed_ast = @typecheck.typecheck(ast)
  let knf_prog = @knf.knf_transform(typed_ast)
  let codegen_ctx = Context::new("demo")
  codegen_ctx.collect_func_values(knf_prog.functions)

  // foo 
  let foo = knf_prog.functions.get("foo").unwrap()
  let llvm_func = codegen_ctx.top_function_codegen(foo)
  inspect(
    llvm_func,
    content=(
      #|define void @foo() {
      #|entry:
      #|  ret void
      #|}
      #|
    ),
  )

  // bar
  let bar = knf_prog.functions.get("bar").unwrap()
  let llvm_func2 = codegen_ctx.top_function_codegen(bar)
  inspect(
    llvm_func2,
    content=(
      #|define void @bar(i32 %0, double %1) {
      #|entry:
      #|  ret void
      #|}
      #|
    ),
  )
}
/// ================================================================================
/// # LLVM Codegen: if-else 与 PHI 节点
/// ================================================================================
///
/// 我们即将处理第一个真正的控制流结构：`if-else` 表达式。
/// 这在代码生成中是一个飞跃，因为它打破了指令的线性执行流程，并引入了一个强大的新概念：**PHI 节点**。
///
/// ## `if-else` 的控制流
///
/// `if-else` 语句在 LLVM IR 中通过一系列基本块和分支指令来表示：
///
/// 1.  **入口块 (`entry_bb`)**: 计算 `if` 的条件，然后根据结果使用 `createCondBr` 指令跳转到 `then_bb` 或 `else_bb`。
/// 2.  **Then 块 (`then_bb`)**: 包含 `if` 为真时执行的代码。
/// 3.  **Else 块 (`else_bb`)**: 包含 `if` 为假时执行的代码。
/// 4.  **合并块 (`merge_bb`)**: `then` 和 `else` 分支执行完毕后，控制流会重新汇合到这个块，继续执行后续代码。
///
/// ## 💡 核心概念：PHI 节点
///
/// 考虑表达式 `let z = if cond { x } else { y }`。当控制流到达 `merge_bb` 时，`z` 的值是什么？
/// 它可能是 `x`（如果走了 `then` 分支），也可能是 `y`（如果走了 `else` 分支）。
///
/// 为了在 SSA 形式下解决这个问题（一个变量只能被赋值一次），LLVM 引入了 `phi` 指令。
///
/// **PHI 节点就像一个根据来源路径选择值的开关**。
///
/// `z = phi i32 [ %x, %then_bb ], [ %y, %else_bb ]`
///
/// 这行代码的意思是：
/// - `z` 的值是一个 `i32`。
/// - 如果控制流是从 `%then_bb` 过来的，`z` 的值就等于 `%x`。
/// - 如果控制流是从 `%else_bb` 过来的，`z` 的值就等于 `%y`。
///
/// ## 🎯 你的任务
///
/// 本次挑战的目标是实现 `if_codegen` 函数，使其能够正确处理 `if-else` 表达式。
///
/// ### 1. 创建基本块和分支
///
/// - 如上所述，为 `then`、`else` 和 `merge` 创建三个新的基本块。
/// - 生成 `createCondBr` 指令进行条件跳转。
///
/// ### 2. 实现 PHI 节点逻辑
///
/// - 如果 `if` 表达式有返回值（即它的类型不是 `Unit`），你需要在 `merge_bb` 的**最开始**创建一个 PHI 节点。
///   - **接口**: `builder.createPHI(type)`
/// - 在分别生成完 `then` 块和 `else` 块的代码后，你需要告诉 PHI 节点这两个分支分别会产生什么值。
///   - **接口**: `phi_node.addIncoming(value, block)`
///
/// ### 3. ⚠️ 注意：处理已终结的块
///
/// 在 `then` 块或 `else` 块的末尾，我们通常需要一个 `createBr` 指令跳转到 `merge_bb`。
/// 但是，如果这个块已经因为一个 `return` 指令而“终结”了呢？在一个基本块中添加两个终结指令是错误的。
///
/// - 在添加 `br` 指令前，你必须检查当前块是否已经有了终结指令。
///   - **接口**: `builder.getInsertBlock().getTerminator()`。如果返回值是 `Some(...)`，则说明已有终结指令，不应再添加 `br`。
///
/// ### 4. ⚠️ 特别当心：无用的 `merge` 块
///
/// 考虑这种情况：`fn max(a, b) { if a > b { return a; } else { return b; } }`
///
/// 在这里，`then` 块和 `else` 块都以 `return` 结束。控制流**永远不会**到达 `merge_bb`。
/// 这种情况下，`merge_bb` 成了一个没有前驱（predecessor）的“死块”。一个没有前驱的基本块是非法的（入口块除外）。
///
/// - 你需要检测这种情况（即 `then` 和 `else` 块都已被终结）。
/// - 如果发生，你应该将 `merge_bb` 从函数中移除，以保持 IR 的合法性。
///   - **接口**: `merge_bb.removeFromParent()`
///
/// ---
///
/// 这是一个复杂的挑战，但它涵盖了代码生成中关于控制流的许多核心思想。
///
/// 跟着下面的指引完成任务吧。

///|
///
test "Codegen for If Test" {
  let code =
    #|fn max(x: Int, y: Int) -> Int {
    #|  let z = if x > y { x } else { y };
    #|  z
    #|}
    #|
    #|fn min(x: Int, y: Int) -> Int {
    #|  if x < y {
    #|    return x;
    #|  } else {
    #|    return y;
    #|  }
    #|}
    #|
  let tokens = @lexer.tokenize(code)
  let ast = @parser.parse(tokens)
  let typed_ast = @typecheck.typecheck(ast)
  let knf_prog = @knf.knf_transform(typed_ast)
  let codegen_ctx = Context::new("demo")
  codegen_ctx.collect_func_values(knf_prog.functions)

  // max
  let max = knf_prog.functions.get("max").unwrap()
  let llvm_func = codegen_ctx.top_function_codegen(max)
  inspect(
    llvm_func,
    content=(
      #|define i32 @max(i32 %0, i32 %1) {
      #|entry:
      #|  %2 = icmp sgt i32 %0, %1
      #|  br i1 %2, label %4, label %6
      #|
      #|4:                                     ; preds = %entry
      #|  br label %8
      #|
      #|6:                                     ; preds = %entry
      #|  br label %8
      #|
      #|8:                                     ; preds = %4, %6
      #|  %9 = phi i32 [ %0, %4 ], [ %1, %6 ]
      #|  ret i32 %9
      #|}
      #|
    ),
  )

  // min
  let min = knf_prog.functions.get("min").unwrap()
  let llvm_func = codegen_ctx.top_function_codegen(min)
  inspect(
    llvm_func,
    content=(
      #|define i32 @min(i32 %0, i32 %1) {
      #|entry:
      #|  %2 = icmp slt i32 %0, %1
      #|  br i1 %2, label %4, label %6
      #|
      #|4:                                     ; preds = %entry
      #|  ret i32 %0
      #|
      #|6:                                     ; preds = %entry
      #|  ret i32 %1
      #|}
      #|
    ),
  )
}

///|
test "Codegen for Simple Let and LetMut Test - 3" {
  let code =
    #|fn foo(x: Int) -> Int {
    #|  let z = x;
    #|  z
    #|}
    #|
    #|fn bar(x: Int) -> Int {
    #|  let mut z = x;
    #|  z
    #|}
  let tokens = @lexer.tokenize(code)
  let ast = @parser.parse(tokens)
  let typed_ast = @typecheck.typecheck(ast)
  let knf_prog = @knf.knf_transform(typed_ast)
  let codegen_ctx = Context::new("demo")
  codegen_ctx.collect_func_values(knf_prog.functions)

  // foo
  let add = knf_prog.functions.get("foo").unwrap()
  let llvm_func = codegen_ctx.top_function_codegen(add)
  inspect(
    llvm_func,
    content=(
      #|define i32 @foo(i32 %0) {
      #|entry:
      #|  ret i32 %0
      #|}
      #|
    ),
  )

  // bar
  let bar = knf_prog.functions.get("bar").unwrap()
  let llvm_func2 = codegen_ctx.top_function_codegen(bar)
  inspect(
    llvm_func2,
    content=(
      #|define i32 @bar(i32 %0) {
      #|entry:
      #|  %1 = alloca i32, align 4
      #|  store i32 %0, ptr %1, align 4
      #|  %3 = load i32, ptr %1, align 4
      #|  ret i32 %3
      #|}
      #|
    ),
  )
}

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
      #|  %0 = call ptr @__builtin_create_string(ptr @str_lit_1)
      #|  ret ptr %0
      #|}
      #|
    ),
  )
}
/// ================================================================================
/// # LLVM Codegen: 结构体操作
/// ================================================================================
///
/// 我们已经可以处理数组了，现在我们来处理另一种重要的复合类型：**结构体（Structs）**。
/// 这包括结构体的创建、字段的读取和字段的更新。这些操作的核心都离不开一条关键指令：`getelementptr`。
///
/// ## 💡 核心指令：`getelementptr` (GEP)
///
/// `getelementptr`（获取元素指针）是 LLVM 中用于地址计算的指令。它**不访问内存**，
/// 而是根据基地址和索引，计算出结构体或数组中某个元素的内存地址。
///
/// ### GEP 指令格式
///
/// 当我们想获取一个结构体实例中某个字段的指针时，GEP 指令的格式如下：
///
/// `%field_ptr = getelementptr %MyStruct, ptr %struct_ptr, i32 0, i32 <field_index>`
///
/// - `%MyStruct`: 这是结构体的类型。
/// - `ptr %struct_ptr`: 这是指向结构体实例的基地址指针。
/// - `i32 0`: 第一个索引。它用于“穿过”`%struct_ptr` 指针。在访问结构体字段时，这个索引**总是 0**。
/// - `i32 <field_index>`: 第二个索引，代表你想要访问的字段在结构体定义中的**序号**（从 0 开始）。
///
/// 例如，对于 `struct Point { x: Int; y: Int; }`，字段 `y` 的索引就是 `1`。
///
/// ## 🎯 你的任务
///
/// 本次挑战的目标是实现结构体的创建、访问和更新。
///
/// ### 1. 结构体创建 (`CreateStruct`)
///
/// 在 `expr_codegen` 中处理 `CreateStruct` 时：
/// a. **分配内存**: 与数组类似，结构体实例也存放在堆上。你需要调用 `moonbit_malloc` 内建函数来为其分配内存。分配的大小可以通过 `module.getDataLayout().getTypeAllocSize(struct_ty)` 来获取。
/// b. **填充字段**: 遍历所有需要初始化的字段。对于每个字段：
///    i.  使用 `getelementptr` 计算出该字段的地址。
///    ii. 使用 `builder.createStore` 将初始值存入该地址。
///
/// ### 2. 字段访问 (`FieldAccess`)
///
/// 在 `expr_codegen` 中处理 `FieldAccess` 时：
/// a. **获取字段指针**: 使用 `getelementptr` 计算出字段的地址。
/// b. **加载值**: 使用 `builder.createLoad` 从该地址加载字段的值。
///
/// ### 3. 字段更新 (`StructFieldSet`)
///
/// 在 `stmt_codegen` 中添加对 `StructFieldSet` 的处理：
/// a. **获取字段指针**: 同样，使用 `getelementptr` 计算出字段的地址。
/// b. **存储新值**: 使用 `builder.createStore` 将新值存入该地址。
///
/// ---
///
/// 本次测试 `codegen_struct_test.mbt` 将检查你是否能正确地为结构体的创建、访问和更新生成代码。
///
/// 跟着下面的指引完成任务吧。

///|
///
test "Codegen for Struct Create, Access and Set Test" {
  let code =
    #|struct Point {
    #|  mut x: Int;
    #|  mut y: Int;
    #|}
    #|
    #|fn create_point() -> Point {
    #|  let p = Point::{ x: 10, y: 20 };
    #|  p;
    #|}
    #|
    #|fn swap_x_y(p: Point) -> Unit {
    #|  let t = p.x;
    #|  p.x = p.y;
    #|  p.y = t;
    #|}
  let tokens = @lexer.tokenize(code)
  let ast = @parser.parse(tokens)
  let typed_ast = @typecheck.typecheck(ast)
  let knf_prog = @knf.knf_transform(typed_ast)
  let codegen_ctx = Context::new("demo")
  codegen_ctx.collect_func_values(knf_prog.functions)
  codegen_ctx.collect_struct_types(knf_prog.struct_defs)

  // codegen for create_point
  let create_point = knf_prog.functions.get("create_point").unwrap()
  let llvm_func = codegen_ctx.top_function_codegen(create_point)
  inspect(
    llvm_func,
    content=(
      #|define ptr @create_point() {
      #|entry:
      #|  %0 = call ptr @moonbit_malloc(i32 8)
      #|  %1 = getelementptr %Point, ptr %0, i32 0, i32 0
      #|  store i32 10, ptr %1, align 4
      #|  %3 = getelementptr %Point, ptr %0, i32 0, i32 1
      #|  store i32 20, ptr %3, align 4
      #|  ret ptr %0
      #|}
      #|
    ),
  )

  // codegen for swap_x_y
  let swap_x_y = knf_prog.functions.get("swap_x_y").unwrap()
  let llvm_func = codegen_ctx.top_function_codegen(swap_x_y)
  inspect(
    llvm_func,
    content=(
      #|define void @swap_x_y(ptr %0) {
      #|entry:
      #|  %1 = getelementptr %Point, ptr %0, i32 0, i32 0
      #|  %2 = load i32, ptr %1, align 4
      #|  %3 = getelementptr %Point, ptr %0, i32 0, i32 1
      #|  %4 = load i32, ptr %3, align 4
      #|  %5 = getelementptr %Point, ptr %0, i32 0, i32 0
      #|  store i32 %4, ptr %5, align 4
      #|  %7 = getelementptr %Point, ptr %0, i32 0, i32 1
      #|  store i32 %2, ptr %7, align 4
      #|  ret void
      #|}
      #|
    ),
  )
}

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
