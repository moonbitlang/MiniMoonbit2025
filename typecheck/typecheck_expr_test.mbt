/// ================================================================================
/// # 类型检查表达式：组合的力量
///
/// 我们已经为 `check_expr` 和 `check_apply_expr` 搭建了基础的框架。
/// 现在，是时候为 `check_apply_expr` 添加处理复杂组合的能力了，例如函数调用、数组索引和字段访问。
///
/// ## 🎯 你的任务：完成 `check_apply_expr`
///
/// 你的任务是回到 `typecheck/apply_expr.mbt` 文件，完成 `Context::check_apply_expr` 函数中剩余的 `match` 分支。
///
/// ### 💡 实现思路
///
/// `check_apply_expr` 的核心是一个循环或递归结构，它首先检查一个基础表达式（`AtomExpr`），然后不断检查后面是否跟随 `()`、`[]` 或 `.`，并持续将表达式“包装”成更复杂的 `ApplyExpr`。
///
/// 1.  **`ArrayAccess(array_expr, index_expr)` (数组索引)**
///     *   递归调用 `check_apply_expr` 检查 `array_expr`，并调用 `check_expr` 检查 `index_expr`。
///     *   **类型规则**：
///         *   `array_expr` 的类型必须是 `Array[T]`。
///         *   `index_expr` 的类型必须是 `Int`。
///     *   **返回类型**：整个表达式的类型是数组的元素类型 `T`。
///
/// 2.  **`FieldAccess(struct_expr, field_name)` (字段访问)**
///     *   递归调用 `check_apply_expr` 检查 `struct_expr`。
///     *   **类型规则**：`struct_expr` 的类型必须是某个 `Struct(struct_name)`。
///     *   你需要从 `Context` 的 `struct_defs` 中查找该结构体的定义，并找到 `field_name` 对应的字段类型。
///     *   **返回类型**：整个表达式的类型就是该字段的类型。
///
/// 3.  **`Call(callee_expr, arg_exprs)` (函数调用)**
///     *   递归调用 `check_apply_expr` 检查 `callee_expr`（被调用的函数）。
///     *   **类型规则**：`callee_expr` 的类型必须是 `Function` 类型，例如 `Function([ArgT1, ArgT2], RetT)`。
///     *   遍历 `arg_exprs`，对每个参数表达式递归调用 `check_expr`。
///     *   **关键一步**：检查每个传入参数的类型是否与函数签名中对应参数的类型 `ArgT` **兼容**。这里需要大量使用 `is_type_compatible`，它会驱动我们上一关实现的类型变量合一（Unification）逻辑。
///     *   参数的数量也必须匹配。
///     *   **返回类型**：整个表达式的类型是函数签名的返回类型 `RetT`。
///
/// ---
///
/// **阶段性测试：**
///
/// 本次测试包含了多种复杂的表达式组合，将全面考验你的 `check_apply_expr` 实现。
///
/// ```bash
/// moon test -p typecheck -f typecheck_expr_test.mbt
/// ```
/// ================================================================================

///|
test "Expr TypeCheck Test" {
  let code =
    #|arr[3] + arr[5] ; fact(5) + fib(10) ; print_string("Hello, World!");
    #|mat.data[3][4] ; sum(arr); 3.0 > max(x, y);
  let ctx = Context::new()
  ctx.struct_defs.set("Matrix", StructDef::{
    name: "Matrix",
    fields: [{ name: "data", ty: { kind: Array(Array(Int)), mutable: false } }],
    methods: Map::new()
  })
  ctx.type_env.set("arr", { kind: Array(Int), mutable: false })
  ctx.type_env.set("mat", { kind: Struct("Matrix"), mutable: false })
  // Note: Matrix struct has a field `data` of type Array(Array(Int))
  ctx.type_env.set("fact", { kind: Function([TypeVar(0)], Int), mutable: false })
  ctx.type_env.set("fib", { kind: Function([Int], Int), mutable: false })
  ctx.type_env.set("print_string", {
    kind: Function([String], Unit),
    mutable: false,
  })
  ctx.type_env.set("sum", { kind: Function([Array(Int)], Int), mutable: false })
  // Note: max is local function without type annotations
  ctx.type_env.set("max", {
    kind: Function([TypeVar(1), TypeVar(2)], TypeVar(3)),
    mutable: false,
  })
  ctx.type_env.set("x", { kind: Double, mutable: true })
  ctx.type_env.set("y", { kind: Double, mutable: true })
  ctx.type_vars.set(0, TypeVar(0))
  ctx.type_vars.set(1, TypeVar(1))
  ctx.type_vars.set(2, TypeVar(1))
  ctx.type_vars.set(3, TypeVar(1))

  // Parse
  let tokens = @lexer.tokenize(code)
  // Type of arr[3] + arr[5]
  let (a, tok_view) = @parser.parse_expr(tokens[:])
  let a = ctx.check_expr(a)
  assert_true(a.ty is Int)
  // Type of fact(5) + fib(10)
  let (a, tok_view) = @parser.parse_expr(tok_view[1:])
  let a = ctx.check_expr(a)
  assert_true(a.ty is Int)
  // Type of print_string("Hello, World!")
  let (a, tok_view) = @parser.parse_expr(tok_view[1:])
  let a = ctx.check_expr(a)
  assert_true(a.ty is Unit)
  // Type of mat.data[3][4]
  let (a, tok_view) = @parser.parse_expr(tok_view[1:])
  let a = ctx.check_expr(a)
  assert_true(a.ty is Int)
  // Type of sum(arr)
  let (a, tok_view) = @parser.parse_expr(tok_view[1:])
  let a = ctx.check_expr(a)
  assert_true(a.ty is Int)
  // Type of 3.0 > max(x, y)
  let (a, _) = @parser.parse_expr(tok_view[1:])
  let a = ctx.check_expr(a)
  assert_true(a.ty is Bool)
  assert_true(ctx.lookup_type("x") is Some({ kind: Double, .. }))
  assert_true(ctx.lookup_type("y") is Some({ kind: Double, .. }))
}
