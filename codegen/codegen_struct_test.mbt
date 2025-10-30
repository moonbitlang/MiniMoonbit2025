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
