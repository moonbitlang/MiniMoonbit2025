/// ================================================================================
/// # 类型检查语句：let 与模式匹配
///
/// 我们已经处理了 `let mut` 和顶层的 `let`。现在，我们来处理函数体内部最常见的 `let` 语句。
///
/// 它与我们之前实现的 `let` 检查最大的不同在于：**左侧可以是一个复杂的模式（Pattern）**。
///
/// ```moonbit
/// let (a, (b, c)) = (1, (true, "hello"));
/// ```
///
/// 类型检查器需要能够“解开”等号两边的结构，并将右侧值的类型正确地赋予左侧模式中的每一个变量。
///
/// ## 🎯 你的任务：实现 `check_let_stmt`
///
/// 你的任务是在 `typecheck/let_stmt.mbt` 文件中实现 `Context::check_let_stmt` 函数。
///
/// ### 💡 实现思路
///
/// 1.  **检查表达式类型：** 和之前一样，首先调用 `check_expr` 获得 `=` 右侧表达式的类型 `T`。
///
/// 2.  **处理类型注解：** 如果 `let` 语句带有类型注解（例如 `let (a, b): (Int, Int) = ...`），则需要检查表达式类型 `T` 是否与该注解兼容。
///
/// 3.  **绑定模式与类型（核心！）：**
///     *   这是本次挑战最核心的部分。你需要将左侧的 `pattern` 和右侧的类型 `T` 进行匹配和绑定。
///     *   建议为此实现一个单独的辅助函数，例如 `bind_pattern_type(pattern: Pattern, ty: TypeKind)`。
///     *   这个函数需要递归地处理模式：
///         *   **`Ident(name)`：** 最简单的情况。将 `name` 和类型 `ty` 添加到类型环境中（注意是**不可变**的 `mutable: false`）。
///         *   **`Wildcard` (`_`)：** 忽略即可，它不引入任何新的变量绑定。
///         *   **`Tuple(sub_patterns)`：** 这是递归的关键。
///             *   首先，检查类型 `ty` 是否也是一个元组类型 `Tuple(element_types)`。如果不是（例如，试图用元组模式匹配一个 `Int`），则抛出类型错误。
///             *   然后，检查模式和类型的长度是否一致。
///             *   最后，遍历 `sub_patterns` 和 `element_types`，对每一对 `(sub_pattern, element_type)` **递归调用 `bind_pattern_type`**。
///
/// 通过这种方式，你可以优雅地将任意复杂的类型“解构”并绑定到对应的变量上。
///
/// ---
///
/// **阶段性测试：**
///
/// ```bash
/// moon test -p typecheck -f typecheck_let_stmt_test.mbt
/// ```
///
/// 恭喜你！完成这一步，你的类型检查器就几乎拥有处理所有核心语言特性的能力了！
/// ================================================================================

///|
test "Let Stmt Type Check" {
  let code =
    #|let x : Double = 42.0;
    #|let (x, y) = (1, 2);
    #|let z = [];
    #|let mat = [[1, 2], z];
  let ctx = Context::new()
  // Parse
  let tokens = @lexer.tokenize(code)
  // Type check for `let x : Int = 42;`
  let (let_stmt1, tok_view) = @parser.parse_let_stmt(tokens[:])
  let checked_let_stmt1 = ctx.check_let_stmt(let_stmt1)
  assert_true(checked_let_stmt1.ty is Double)
  // Type check for `let (x, y) = (1, 2);`
  let (let_stmt2, tok_view) = @parser.parse_let_stmt(tok_view)
  let checked_let_stmt2 = ctx.check_let_stmt(let_stmt2)
  assert_true(checked_let_stmt2.ty is Tuple([Int, Int]))
  assert_true(ctx.lookup_type("x") is Some({ kind: Int, .. }))
  assert_true(ctx.lookup_type("y") is Some({ kind: Int, .. }))
  // Type check for `let z = [];`
  let (let_stmt3, tok_view) = @parser.parse_let_stmt(tok_view)
  let checked_let_stmt3 = ctx.check_let_stmt(let_stmt3)
  assert_true(checked_let_stmt3.ty is Array(TypeVar(_)))
  // Type check for `let mat = [[1, 2], z];`
  let (let_stmt4, _) = @parser.parse_let_stmt(tok_view)
  let checked_let_stmt4 = ctx.check_let_stmt(let_stmt4)
  assert_true(checked_let_stmt4.ty is Array(Array(Int)))
  assert_true(ctx.lookup_type("mat") is Some({ kind: Array(Array(Int)), .. }))
  let zty = ctx.lookup_type("z")
  assert_true(
    ctx.lookup_type("z") is Some({ kind: Array(Int), .. }),
    msg="Type of z is \{zty}",
  )
}
