/// ================================================================================
/// # 类型检查 Apply 表达式：最终章
///
/// 我们已经为 `check_apply_expr` 实现了基础的 `AtomExpr` 包装。
/// 现在，是时候完成 `check_apply_expr` 的所有剩余分支，使其能够处理所有复杂的 `ApplyExpr` 类型了。
///
/// ## 🎯 你的任务：完成 `check_apply_expr` 的所有分支
///
/// 你的任务是回到 `typecheck/apply_expr.mbt` 文件，完成 `Context::check_apply_expr` 函数中剩余的 `match` 分支。
///
/// ### 💡 实现思路
///
/// `check_apply_expr` 的核心是一个循环或递归结构，它首先检查一个基础表达式（`AtomExpr`），然后不断检查后面是否跟随 `()`、`[]` 或 `.`，并持续将表达式“包装”成更复杂的 `ApplyExpr`。
///
/// 你需要为 `check_apply_expr` 中的以下 `ApplyExprKind` 分支编写类型检查逻辑：
///
/// 1.  **`ArrayAccess(array_expr, index_expr)` (数组索引 `array[index]`)**
///     *   递归调用 `check_apply_expr` 检查 `array_expr`，并调用 `check_expr` 检查 `index_expr`。
///     *   **类型规则**：
///         *   `array_expr` 的类型必须是 `Array[T]`。
///         *   `index_expr` 的类型必须是 `Int`。
///     *   **返回类型**：整个表达式的类型是数组的元素类型 `T`。
///
/// 2.  **`FieldAccess(object_expr, field_name)` (字段访问 `object.field`)**
///     *   递归调用 `check_apply_expr` 检查 `object_expr`。
///     *   **类型规则**：
///         *   如果 `object_expr` 的类型是 `Struct(struct_name)`：你需要从 `Context` 的 `struct_defs` 中查找该结构体的定义，并找到 `field_name` 对应的字段类型。
///         *   **特殊情况：数组的内置方法**。在 MiniMoonBit 中，我们通过 `FieldAccess` 语法来访问数组的内置方法，例如 `arr.push(value)` 和 `arr.length()`。你需要识别 `object_expr` 的类型是否为 `Array[T]`，然后根据 `field_name`（`"push"` 或 `"length"`）返回对应的函数类型。
///     *   **返回类型**：整个表达式的类型就是该字段或方法的类型。
///
/// 3.  **`Call(callee_expr, arg_exprs)` (函数调用 `func(arg1, arg2, ...)`)**
///     *   递归调用 `check_apply_expr` 检查 `callee_expr`（被调用的函数）。
///     *   **类型规则**：
///         *   `callee_expr` 的类型必须是 `Function` 类型，例如 `Function([ArgT1, ArgT2], RetT)`。
///         *   遍历 `arg_exprs`，对每个参数表达式递归调用 `check_expr`。
///         *   **关键一步**：检查每个传入参数的类型是否与函数签名中对应参数的类型 `ArgT` **兼容**。这里需要大量使用 `is_type_compatible`，它会驱动我们之前实现的类型变量合一（Unification）逻辑。
///         *   参数的数量也必须匹配。
///     *   **返回类型**：整个表达式的类型是函数签名的返回类型 `RetT`。
///
/// ---
///
/// **阶段性测试：**
///
/// ```bash
/// moon test -p typecheck -f typecheck_apply_expr_test.mbt
/// ```
/// ================================================================================

///|
test "Apply Expression Type Check" {
  let code =
    #|arr[3] ; fact(5) ; print("Hello, World!")
    #|mat[3][4] ; sum(arr); max(x, y);
    #|arr.push(10); mat.length();
  let ctx = Context::new()
  ctx.type_env.set("arr", { kind: Array(Int), mutable: false })
  ctx.type_env.set("mat", { kind: Array(Array(Int)), mutable: false })
  ctx.type_env.set("fact", { kind: Function([Int], Int), mutable: false })
  ctx.type_env.set("print", { kind: Function([String], Unit), mutable: false })
  ctx.type_env.set("sum", { kind: Function([Array(Int)], Int), mutable: false })
  // Note: max is local function without type annotations
  // like: fn max(a, b) { ... }
  ctx.type_env.set("max", {
    kind: Function([TypeVar(0), TypeVar(1)], TypeVar(2)),
    mutable: false,
  })
  ctx.type_env.set("x", { kind: Double, mutable: true })
  ctx.type_env.set("y", { kind: Double, mutable: true })
  ctx.type_vars.set(0, TypeVar(0))
  ctx.type_vars.set(1, TypeVar(0))
  ctx.type_vars.set(2, TypeVar(0))
  // Parse
  let tokens = @lexer.tokenize(code)
  // Type of arr[3]
  let (a, tok_view) = @parser.parse_apply_expr(tokens[:])
  let a = ctx.check_apply_expr(a)
  assert_true(a.ty is Int)
  // Type of fact(5)
  let (a, tok_view) = @parser.parse_apply_expr(tok_view[1:])
  let a = ctx.check_apply_expr(a)
  assert_true(a.ty is Int)
  // Type of print("Hello, World!")
  let (a, tok_view) = @parser.parse_apply_expr(tok_view[1:])
  let a = ctx.check_apply_expr(a)
  assert_true(a.ty is Unit)
  // Type of mat[3][4]
  let (a, tok_view) = @parser.parse_apply_expr(tok_view[1:])
  let a = ctx.check_apply_expr(a)
  assert_true(a.ty is Int)
  // Type of sum(arr)
  let (a, tok_view) = @parser.parse_apply_expr(tok_view[1:])
  let a = ctx.check_apply_expr(a)
  assert_true(a.ty is Int)
  // Type of max(x, y)
  let (a, tok_view) = @parser.parse_apply_expr(tok_view[1:])
  let a = ctx.check_apply_expr(a)
  assert_true(a.ty is Double)
  // Type of arr.push(10)
  let (a, tok_view) = @parser.parse_apply_expr(tok_view[1:])
  let a = ctx.check_apply_expr(a)
  assert_true(a.ty is Unit)
  // Type of mat.length()
  let (a, _) = @parser.parse_apply_expr(tok_view[1:])
  let a = ctx.check_apply_expr(a)
  assert_true(a.ty is Int)
}
/// ================================================================================
/// # 类型检查语句：赋值语句
///
/// 我们已经能够通过 `let` 和 `let mut` 向环境中添加新的变量了。现在，我们要检查对这些变量的**赋值（Assignment）**操作。
///
/// 赋值语句是命令式编程的核心，它会改变一个已存在变量的值。类型检查器的职责是确保这种改变是**类型安全**且**合法**的。
///
/// ## 🎯 你的任务：实现 `check_assign_stmt`
///
/// 你的任务是在 `typecheck/assign_stmt.mbt` 文件中实现 `Context::check_assign_stmt` 函数。
///
/// ### 💡 实现思路
///
/// 1.  **检查左值（L-Value）：**
///     *   赋值语句的左侧不是任意表达式，而是一个“左值”——可以被赋值的目标，例如变量 `x`、数组元素 `arr[0]` 或结构体字段 `obj.field`。
///     *   你需要首先实现一个 `check_left_value` 辅助函数，它负责检查左值的类型。例如，对于 `x`，它需要到类型环境中查找 `x` 的类型。
///
/// 2.  **检查可变性（Mutability）：**
///     *   **这是赋值检查中最关键的一步！** 你不能给一个不可变的变量赋值。
///     *   当你从类型环境中查找到左侧变量的类型后，必须检查其 `mutable` 标志是否为 `true`。如果不是，就应该抛出类型错误。
///     *   思考一下：对于 `arr[0]` 这样的左值，它的可变性应该如何确定？（提示：它取决于 `arr` 本身是否可变，还是数组元素总是可变的？）在我们的 MiniMoonBit 中，我们做一个简化，认为只要数组本身是可访问的，其元素就是可变的。
///
/// 3.  **检查右值（R-Value）：**
///     *   调用 `self.check_expr` 检查 `=` 右侧表达式的类型。
///
/// 4.  **检查类型兼容性：**
///     *   确保右侧表达式的类型与左值的类型是兼容的。
///
/// 5.  **处理复合赋值（Compound Assignment）：**
///     *   对于 `+=`, `-=` 等操作，你还需要额外检查左右两侧的类型是否适用于该算术运算（例如，它们必须是 `Int` 或 `Double`）。
///
/// ---
///
/// **阶段性测试：**
///
/// ```bash
/// moon test -p typecheck -f typecheck_assign_stmt_test.mbt
/// ```
/// ================================================================================

///|
test "Assign Stmt Type Check" {
  let code =
    #|let mut x = 10;
    #|x = 5;
    #|let arr = [1, 2, 3];
    #|arr[0] = 10;
    #|x += true;  // Shoule fail
    #|let mut a = xxx;  // xxx's type is typevar
    #|a += 33;  // `a` and `xxx` should be inferred as Int
  let ctx = Context::new()
  // Parse
  let tokens = @lexer.tokenize(code)
  // Type of let mut x = 10; x = 5; 
  let (s, tok_view) = @parser.parse_let_mut_stmt(tokens[:])
  let _ = ctx.check_let_mut_stmt(s)
  let (a, tok_view) = @parser.parse_assign_stmt(tok_view)
  let a = ctx.check_assign_stmt(a)
  assert_true(a.left_value.ty.kind is Int)
  assert_true(a.expr.ty is Int)
  // Type of `let arr = [1, 2, 3]; arr[0] = 10;`
  let (s, tok_view) = @parser.parse_let_stmt(tok_view)
  let _ = ctx.check_let_stmt(s)
  let (a, tok_view) = @parser.parse_assign_stmt(tok_view)
  let a = ctx.check_assign_stmt(a)
  assert_true(a.left_value.ty.kind is Int)
  assert_true(a.left_value.ty.mutable is true)
  assert_true(a.expr.ty is Int)
  // Type of `x += true;` should fail
  let (a, tok_view) = @parser.parse_assign_stmt(tok_view)
  let t = try? ctx.check_assign_stmt(a)
  assert_true(t is Err(_))
  // Type of `let mut a = xxx; a += 33;`
  ctx.type_vars.set(0, TypeVar(0))
  ctx.type_env.set("xxx", { kind: TypeVar(0), mutable: false })
  let (s, tok_view) = @parser.parse_let_mut_stmt(tok_view)
  let _ = ctx.check_let_mut_stmt(s)
  let (a, _) = @parser.parse_assign_stmt(tok_view)
  let _ = ctx.check_assign_stmt(a)
  assert_true(ctx.lookup_type("a") is Some({ kind: Int, .. }))
  assert_true(ctx.lookup_type("xxx") is Some({ kind: Int, .. }))
}
/// ================================================================================
/// # 类型检查原子表达式：完整篇
///
/// 我们已经实现了 `check_atom_expr` 的基础部分，能够处理字面量和标识符。
/// 现在，是时候完成 `check_atom_expr` 的所有剩余分支，使其能够处理所有类型的原子表达式了。
///
/// ## 🎯 你的任务：完成 `check_atom_expr`
///
/// 你的任务是回到 `typecheck/atom_expr.mbt` 文件，完成 `Context::check_atom_expr` 函数中剩余的 `match` 分支。
///
/// ### 💡 实现思路
///
/// 你需要为 `check_atom_expr` 中的以下 `AtomExprKind` 分支编写类型检查逻辑：
///
/// 1.  **`Paren(expr)` (括号表达式 `(expr)`)**
///     *   递归调用 `self.check_expr(expr)` 检查内部表达式。
///     *   `Paren` 表达式的类型就是其内部表达式的类型。
///
/// 2.  **`Tuple(exprs)` (元组表达式 `(expr1, expr2, ...)`)**
///     *   遍历 `exprs` 数组，对每个子表达式递归调用 `self.check_expr`。
///     *   将所有子表达式的类型收集起来，构成一个 `TypeKind::Tuple` 类型。
///     *   **提示：** 你可以实现一个辅助函数 `check_tuple_expr` 来处理这个逻辑。
///
/// 3.  **`Array(exprs)` (数组字面量 `[expr1, expr2, ...]`)**
///     *   遍历 `exprs` 数组，对每个子表达式递归调用 `self.check_expr`。
///     *   **类型规则：** 数组的所有元素必须具有兼容的类型。你需要使用 `self.is_type_compatible` 来确保这一点。
///     *   **空数组 `[]` 的特殊处理：** 如果数组为空，它的元素类型是未知的。此时，你应该创建一个 `TypeVar` 作为其元素类型的占位符，例如 `Array(TypeVar(N))`。
///     *   **提示：** 你可以实现一个辅助函数 `check_array_expr` 来处理这个逻辑。
///
/// 4.  **`ArrayMake(size_expr, init_expr)` (`Array::make(size, init)`)**
///     *   调用 `self.check_expr` 检查 `size_expr`，其类型必须是 `Int`。
///     *   调用 `self.check_expr` 检查 `init_expr`。
///     *   整个 `ArrayMake` 表达式的类型是 `Array(init_expr.ty)`。
///     *   **提示：** 你可以实现一个辅助函数 `check_array_make_expr` 来处理这个逻辑。
///
/// 5.  **`StructConstruct(sc_expr)` (`StructName::{ field: value, ... }`)**
///     *   调用 `self.check_struct_construct_expr(sc_expr)` 来检查结构体构造表达式。
///     *   **提示：** 这个函数我们已经在之前的挑战中实现过了。
///
/// ---
///
/// **阶段性测试：**
///
/// ```bash
/// moon test -p typecheck -f typecheck_atom_expr_test.mbt
/// ```
/// ================================================================================

///|
test "Atom Expression Type Check" {
  let code =
    #|[1, 2+3, 3+4+5, 6*7+8] (1+3, !y, "Hello") Array::make(5, 0) []
  let ctx = Context::new()
  ctx.type_env.set("x", { kind: Double, mutable: false })
  ctx.type_env.set("y", { kind: Bool, mutable: false })
  ctx.type_env.set("z", { kind: String, mutable: false })
  // Parse
  let tokens = @lexer.tokenize(code)
  // Type of [1, 2+3, 3+4+5, 6*7+8]
  let (a, tok_view) = @parser.parse_atom_expr(tokens[:])
  let a = ctx.check_atom_expr(a)
  assert_true(a.ty is Array(Int))
  // Type of (1+3, !y, "Hello")
  let (b, tok_view) = @parser.parse_atom_expr(tok_view)
  let b = ctx.check_atom_expr(b)
  assert_true(b.ty is Tuple([Int, Bool, String]))
  // Type of Array::make(5, 0)
  let (c, tok_view) = @parser.parse_atom_expr(tok_view)
  let c = ctx.check_atom_expr(c)
  assert_true(c.ty is Array(Int))
  // Type of []
  let (d, _) = @parser.parse_atom_expr(tok_view)
  let d = ctx.check_atom_expr(d)
  assert_true(d.ty is Array(TypeVar(_)))
}
/// ================================================================================
/// # 类型检查语句和代码块
///
/// 我们已经可以独立地检查各种语句了。现在，我们需要一个“总指挥”来调度它们，并处理语句的集合——代码块（Block）。
///
/// ## 🎯 你的第一个任务：实现 `check_stmt`
///
/// 你的第一个任务是在 `typecheck/stmt.mbt` 文件中实现 `Context::check_stmt` 函数。
/// 这个函数将作为一个分发器（Dispatcher）。
///
/// ### 💡 `check_stmt` 实现思路
///
/// `match` 传入的 `stmt.kind`，然后调用我们已经实现的相应的检查函数：
/// *   `LetStmt(...)` -> `check_let_stmt(...)`
/// *   `LetMutStmt(...)` -> `check_let_mut_stmt(...)`
/// *   `AssignStmt(...)` -> `check_assign_stmt(...)`
/// *   `ExprStmt(expr)` -> `check_expr(expr)`
/// *   ...等等
///
/// ### ⭐ 特别关注：`ReturnStmt`
///
/// 在处理 `ReturnStmt` 时，我们需要回答一个关键问题：如何知道 `return` 语句的类型是否正确？
///
/// > 我们必须将 `return` 后面表达式的类型与**当前函数签名中声明的返回类型**进行比较。
///
/// 这个“当前函数的返回类型”信息就存放在 `Context` 中。我们约定使用 `current_func_ret_ty: Option[TypeKind]` 字段来记录它。
///
/// *   当检查 `ReturnStmt(Some(expr))` 时，你需要检查 `expr` 的类型是否与 `self.current_func_ret_ty` 兼容。
/// *   当检查 `ReturnStmt(None)` 时（即 `return;`），你需要检查 `self.current_func_ret_ty` 是否为 `Unit`。
/// *   如果 `self.current_func_ret_ty` 是 `None`，说明 `return` 语句出现在了函数之外，应该抛出错误。
///
/// ## 🎯 你的第二个任务：实现 `check_block_expr`
///
/// 完成了 `check_stmt` 后，你需要在 `typecheck/block_expr.mbt` 中实现 `check_block_expr`。
///
/// ### 💡 `check_block_expr` 实现思路
///
/// 1.  **处理作用域（Scoping）：**
///     *   代码块 `{...}` 会创建一个新的作用域。在块内定义的变量不应该“泄露”到外部。
///     *   在开始检查块内语句**之前**，调用 `self.enter_scope()` 来创建一个新的变量环境。
///     *   在所有语句检查完成**之后**，必须调用 `self.exit_scope()` 来销毁这个环境，恢复到上一层。
///
/// 2.  **遍历语句：**
///     *   遍历块内的每一条语句，调用你刚刚完成的 `self.check_stmt` 来检查它。
///
/// 3.  **确定块的类型：**
///     *   代码块本身也是一个表达式，它有自己的类型。
///     *   规则是：块的类型就是**最后一条表达式语句的类型**。
///     *   如果代码块为空，或者最后一条语句以分号结尾（即不是表达式语句），那么整个块的类型就是 `Unit`。
///
/// ---
///
/// **阶段性测试：**
///
/// ```bash
/// moon test -p typecheck -f typecheck_block_expr_test.mbt
/// ```
/// ================================================================================

///|
test "Block Expr TypeCheck Test" {
  let code =
    #|let arr = [];
    #|
    #|{
    #|  let (x, y) = (1, 2);
    #|  let mut z = x + y;
    #|  z += 10;
    #|  arr.push(z);
    #|}
    #|
    #|{
    #|  let (x, y) = (1.0, 2.0);
    #|  let z = x * y;
    #|  let arr = [1.0, z, 5.0];
    #|  arr[2] = arr[1];
    #|  arr[2]
    #|}
  let ctx = Context::new()
  // Parse
  let tokens = @lexer.tokenize(code)
  let (let_stmt, tok_view) = @parser.parse_let_stmt(tokens[:])
  let _ = ctx.check_let_stmt(let_stmt)
  // TypeCheck first block expr
  let (block_expr1, tok_view) = @parser.parse_block_expr(tok_view)
  let checked_block1 = ctx.check_block_expr(block_expr1)
  assert_true(checked_block1.stmts.length() is 4)
  assert_true(checked_block1.ty is Unit)
  // TypeCheck second block expr
  let (block_expr2, _) = @parser.parse_block_expr(tok_view)
  let checked_block2 = ctx.check_block_expr(block_expr2)
  assert_true(checked_block2.stmts.length() is 5)
  assert_true(checked_block2.ty is Double)
  // TypeCheck third block expr (should raise type error)
  assert_true(ctx.lookup_type("arr") is Some({ kind: Array(Int), .. }))
}
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
    methods: Map::new(),
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
/// ================================================================================
/// # 类型检查控制流：if-else 表达式
///
/// `if-else` 是我们语言中第一个真正的控制流结构。在 MiniMoonBit 中，`if-else` 自身也是一个表达式，它可以产生一个值。
/// 类型检查器必须保证它的逻辑是健全的。
///
/// ## 🎯 你的任务：实现 `check_if_expr`
///
/// 你的任务是在 `typecheck/if_expr.mbt` 文件中实现 `Context::check_if_expr` 函数。
///
/// ### 💡 实现思路
///
/// 检查 `if-else` 表达式需要遵循几条核心规则：
///
/// 1.  **检查条件：**
///     *   `if` 后面的条件表达式必须是一个 `Bool` 类型。你需要首先调用 `check_expr` 检查条件，并验证其类型。
///
/// 2.  **检查 `then` 分支：**
///     *   调用 `check_block_expr` 来检查 `then` 代码块，并记录下它的类型 `T_then`。
///
/// 3.  **检查 `else` 分支：**
///     *   **如果存在 `else` 分支**（无论是 `else if` 还是 `else`）：
///         *   你需要递归地检查 `else` 分支（调用 `check_if_expr` 或 `check_block_expr`），并获得其类型 `T_else`。
///         *   **核心规则：** `then` 分支的类型 `T_then` 必须与 `else` 分支的类型 `T_else` 兼容。你需要调用 `self.is_type_compatible(T_then, T_else)`。
///         *   **表达式类型：** 整个 `if-else` 表达式的类型就是 `T_then`（在合一后可能被更新的 `T_then`）。
///
///     *   **如果不存在 `else` 分支**：
///         *   这意味着 `if` 表达式在条件为 `false` 时不产生任何值。
///         *   **核心规则：** 在这种情况下，整个 `if` 表达式的类型被定为 `Unit`。
///         *   这也反过来对 `then` 分支施加了一个约束：它的类型 `T_then` 必须与 `Unit` 兼容。一个返回 `Int` 的 `then` 分支不能在没有 `else` 的情况下独立存在。
///
/// ---
///
/// **阶段性测试：**
///
/// ```bash
/// moon test -p typecheck -f typecheck_if_expr_test.mbt
/// ```
/// ================================================================================

///|
test "If Expr TypeCheck Test" {
  let code =
    #|let arr = [];
    #|
    #|if a > b {
    #|  arr.push(1);
    #|} else {
    #|  arr.push(2);
    #|}
    #|
    #|if a < b {
    #|  arr.push(a);
    #|  a
    #|}else if a == b {
    #|  arr.push(1);
    #|  a - b
    #|} else {
    #|  arr.push(b);
    #|  b
    #|}
    #|
  let ctx = Context::new()
  ctx.type_vars.set(0, TypeVar(0))
  ctx.type_vars.set(1, TypeVar(1))
  ctx.type_env.set("a", { kind: TypeVar(0), mutable: false })
  ctx.type_env.set("b", { kind: TypeVar(1), mutable: false })
  // Parse
  let tokens = @lexer.tokenize(code)
  let (let_stmt, tok_view) = @parser.parse_let_stmt(tokens[:])
  let _ = ctx.check_let_stmt(let_stmt)
  // TypeCheck first if expr
  let (if_expr1, tok_view) = @parser.parse_if_expr(tok_view)
  let checked_if1 = ctx.check_if_expr(if_expr1)
  assert_true(checked_if1.ty is Unit)
  assert_true(ctx.lookup_type("arr") is Some({ kind: Array(Int), .. }))
  // TypeCheck second if expr
  let (if_expr2, _) = @parser.parse_if_expr(tok_view)
  let checked_if2 = ctx.check_if_expr(if_expr2)
  assert_true(checked_if2.ty is Int)
  assert_true(ctx.lookup_type("a") is Some({ kind: Int, .. }))
  assert_true(ctx.lookup_type("b") is Some({ kind: Int, .. }))
}
/// ================================================================================
/// # 类型检查语句：let mut
///
/// 我们已经能够检查各种复杂的表达式了。现在，是时候将目光转向**语句（Statements）**的类型检查了。
///
/// 语句与表达式的核心区别在于：语句不一定有“值”，但它们通常会产生**副作用（Side Effects）**。
/// 在类型检查中，最重要的副作用就是**改变类型环境（Type Environment）**。
///
/// `let mut` 语句就是一个典型的例子，它会向当前作用域引入一个新的可变变量。
///
/// ## 🎯 你的任务：实现 `check_let_mut_stmt`
///
/// 你的任务是在 `typecheck/let_mut_stmt.mbt` 文件中实现 `Context::check_let_mut_stmt` 函数。
///
/// ### 💡 实现思路
///
/// `check_let_mut_stmt` 的工作流程如下：
///
/// 1.  **检查表达式：** 首先，调用 `self.check_expr` 来确定 `=` 右侧表达式的类型。
///
/// 2.  **处理类型注解（如果存在）：**
///     *   `let mut` 语句可能带有显式的类型注解，例如 `let mut x: Double = ...`。
///     *   如果存在类型注解，你需要调用 `self.check_parser_type` 来转换它。
///     *   然后，**关键一步**：使用 `self.is_type_compatible` 验证表达式的类型是否与注解的类型兼容。如果不兼容，则应抛出类型错误。
///
/// 3.  **确定变量类型：**
///     *   如果存在类型注解，变量的类型就是该注解的类型。
///     *   如果不存在，变量的类型就从表达式的类型中**推断**出来。
///
/// 4.  **更新类型环境：**
///     *   这是最重要的一步！一旦确定了新变量的名称和类型，你必须将它添加到类型环境 `self.type_env` 中。
///     *   在添加到环境时，请务必标记该类型为**可变的（mutable: true）**。这对于后续的赋值语句检查至关重要。
///
/// ### 🤔 深入思考：空数组的类型推断
///
/// 本次挑战的测试用例包含 `let mut z = []`。
///
/// > 当我们看到一个空数组时，它的元素类型是什么？`Int`? `String`?
///
/// 在这一刻，我们**无法知道**。这就是**类型变量（Type Variable）**登场的时机。
/// 当遇到无法立即确定的类型时，我们可以创建一个临时的“占位符”类型，例如 `Array(TypeVar(0))`。
///
/// 在后续代码中，当我们第一次对 `z` 进行操作时（例如 `z.push(3.14)`），我们就可以将 `TypeVar(0)` 的实际类型“绑定”为 `Double`。
/// 这就是类型推断的核心思想之一。你的 `check_array_expr` 函数可能需要支持这种行为。
///
/// ---
///
/// **阶段性测试：**
///
/// ```bash
/// moon test -p typecheck -f typecheck_let_mut_stmt_test.mbt
/// ```
/// ================================================================================

///|
test "Let Mut Stmt Type Check" {
  let code =
    #|let mut x : Double = 42.0;
    #|let mut y = 10;
    #|let mut z = [];
    #|let _ = z.push(3.14);
  let ctx = Context::new()
  // Parse
  let tokens = @lexer.tokenize(code)
  // Type check for `let mut x : Double = 42.0;`
  let (let_mut_stmt1, tok_view) = @parser.parse_let_mut_stmt(tokens[:])
  let checked_let_mut_stmt1 = ctx.check_let_mut_stmt(let_mut_stmt1)
  assert_true(checked_let_mut_stmt1.ty is Double)
  // Type check for `let mut y = 10;`
  let (let_mut_stmt2, tok_view) = @parser.parse_let_mut_stmt(tok_view)
  let checked_let_mut_stmt2 = ctx.check_let_mut_stmt(let_mut_stmt2)
  assert_true(checked_let_mut_stmt2.ty is Int)
  // Type check for `let mut z = [];`
  let (let_mut_stmt3, tok_view) = @parser.parse_let_mut_stmt(tok_view)
  let checked_let_mut_stmt3 = ctx.check_let_mut_stmt(let_mut_stmt3)
  assert_true(checked_let_mut_stmt3.ty is Array(TypeVar(_)))
  // Type check for `let _ = z.push(3.14);`
  // Parse Let Stmt
  let (let_stmt4, _) = @parser.parse_let_stmt(tok_view)
  let checked_let_stmt4 = ctx.check_let_stmt(let_stmt4)
  assert_true(checked_let_stmt4.ty is Unit)
  assert_true(ctx.lookup_type("z") is Some({ kind: Array(Double), .. }))
}
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
/// ================================================================================
/// # 终极挑战：类型检查局部函数与闭包
///
/// 欢迎来到类型检查阶段最具挑战性、也最见功力的部分：**检查局部函数（Local Functions）**。
///
/// 与必须明确标注所有类型的顶层函数不同，局部函数允许省略类型，这就要求我们的编译器具备真正的**类型推断**能力。
///
/// ## 🎯 你的任务：实现 `check_local_function`
///
/// 你的任务是在 `typecheck/local_function.mbt` 文件中实现 `Context::check_local_function` 函数。
///
/// ### 💡 实现思路：立即检查与合一
///
/// 检查一个局部函数 `fn f(a, b: T) { ... }` 的过程如下：
///
/// 1.  **创建函数类型：**
///     *   遍历函数的参数列表。
///     *   如果参数有类型注解（如 `b: T`），则转换该类型。
///     *   如果参数没有类型注解（如 `a`），则**创建一个新的类型变量 `TypeVar`** 作为其类型的占位符。
///     *   对返回值执行同样的操作：有注解则使用，无注解则创建 `TypeVar`。
///     *   将这些参数类型和返回类型组合成一个 `Function` 类型。例如 `fn f(a, b: Int)` 的类型就是 `Function([TypeVar(0), Int], TypeVar(1))`。
///
/// 2.  **更新环境（临时）：**
///     *   将这个新创建的、可能包含 `TypeVar` 的函数类型，与其名字 `f` 一起，添加到**当前**的类型环境中。这使得函数可以递归地调用自己。
///
/// 3.  **检查函数体（立即执行！）：**
///     *   **进入新作用域：** 调用 `enter_scope()`。
///     *   **设置返回类型：** 将 `Context` 的 `current_func_ret_ty` 设置为刚刚创建的函数返回类型（可能是 `TypeVar`）。
///     *   **添加参数到环境：** 将所有参数（包括类型为 `TypeVar` 的参数）添加到这个新的作用域中。
///     *   **检查函数体：** 调用 `check_block_expr` 检查函数体。在检查过程中，`is_type_compatible` 会被大量调用，驱动类型变量的**合一**（Unification），从而推断出具体类型。例如，如果函数体中有 `a > b`，那么 `a` 和 `b` 的类型变量就会被合一。
///     *   **验证返回类型：** 检查函数体的最终类型是否与函数的返回类型兼容。
///     *   **离开作用域：** 调用 `exit_scope()`。
///
/// ---
///
/// **阶段性测试：**
///
/// ```bash
/// moon test -p typecheck -f typecheck_local_func_test.mbt
/// ```
/// ================================================================================

///|
test "Local Function Type Check Test" {
  let code =
    #|fn max(a, b) {
    #|  if a > b { a } else { b }
    #|}
    #|
    #|let _ = max(10, 20);
  let ctx = Context::new()
  // Parse
  let tokens = @lexer.tokenize(code)
  let (local_func, tok_view) = @parser.parse_local_function(tokens[:])
  // TypeCheck
  let _ = ctx.check_local_function(local_func)
  // parse and check let statement
  let (let_stmt, _) = @parser.parse_let_stmt(tok_view)
  let let_stmt = ctx.check_let_stmt(let_stmt)
  assert_true(let_stmt.ty is Int)
}
/// ================================================================================
/// # 第三挑战：类型检查器（Type Checker）
///
/// 恭喜你完成了语法分析！你已经拥有了编译器冒险的第二把钥匙——抽象语法树（AST）。
/// 现在，我们将赋予这些结构以“意义”：**类型检查（Type Checking）**。
///
/// ---
///
/// ## 类型检查（Type Checking）：赋予结构以意义
///
/// 类型检查器是编译器的“守护者”。它的使命是确保代码在语义上是正确的，
/// 即变量和表达式的类型符合预期。
///
/// **例如，对于以下代码片段：**
///
/// ```
/// let triangle_area = base * height / 2.0;
/// ```
///
/// 类型检查器需要确保：
///
/// - `base` 和 `height` 是Double类型
/// - 乘法和除法操作符适用于Double类型
/// - 整个表达式的结果也是Double类型
/// - 变量 `triangle_area` 被正确地推断为Double类型
///
/// 如果类型检查器发现任何不匹配的类型（例如，将字符串与整数相乘），
/// 它将抛出错误，阻止编译过程继续进行。
///
/// 在工业级编译器中，还会给出详细的错误信息，帮助开发者定位和修复类型错误。
///
/// 优秀的类型检查器能够大幅提升代码的可靠性和安全性，与此同时，也是学术研究的热门领域。
///
/// 在我们的MiniMoonBit编译器中，所设计的类型系统相对简单，主要是没有泛型，但依然有一定的挑战性。
///
/// 例如，MiniMoonBit支持对let语句不进行显式类型声明：
///
/// ```
/// let a = 42; // a被推断为Int类型
/// ```
///
/// 再比如，MiniMoonBit支持定义闭包，且可以不进行显式类型声明：
///
/// ```
/// fn max(x, y) { if x > y { x } else { y } }
/// ...
/// let _ = max(10, 20); // 直到这一句，max才被推断为 (Int, Int) -> Int 类型
/// ```
///
/// 那么，类型检查器，到底要如何实现呢？
///
/// 我们这一章，就来带你一步一步地实现一个简单的类型检查器！
/// 
/// ---
///
/// ## 🎯 你的第一个任务：转换类型表示
///
/// 我们的类型检查器也需要有自己的类型表示。
/// 你的第一个任务，就是实现一个转换函数，将 `Parser` 解析出的类型，转换为 `TypeChecker` 内部的类型表示。
///
/// ### 💡 实现思路
///
/// 1.  **对比类型定义：**
///     *   请打开 `parser/typedef.mbt` 和 `typecheck/typedef.mbt`。
///     *   你会发现 `parser::TypeKind` 和 `typecheck::TypeKind` 的定义非常相似，但后者额外增加了 `Struct`、`Any` 和 `TypeVar` 等构造器。这为我们后续实现更强大的类型功能（如结构体和类型推断）预留了空间。
///
/// 2.  **上下文 `Context` 的作用：**
///     *   在 `typecheck/typedef.mbt` 中，我们引入了一个核心数据结构 `Context`。
///     *   `Context` 用于在类型检查过程中存储和管理上下文信息，例如已知的结构体定义、函数签名、变量类型等。
///     *   在本次任务中，我们暂时不会用到 `Context` 的复杂功能，但转换函数会作为 `Context` 的方法来实现。
///
/// ### 🚀 具体操作
///
/// 请在 `typecheck/typedef.mbt` 文件中，完成以下两个函数的实现：
///
/// *   `Context::check_parser_type`
/// *   `Context::check_parser_typekind`
///
/// 你的目标是递归地将 `parser` AST 中的 `Type` 和 `TypeKind`，转换为 `typecheck` AST 中对应的 `Type` 和 `TypeKind`。
///
/// ---
///
/// **阶段性测试：**
///
/// 在你实现完成后，使用下面的命令来单独运行当前测试：
///
/// ```
/// moon test -p typecheck -f typecheck_normal_type_test.mbt
/// ```
///
/// 准备好了吗？让我们开始为代码赋予“意义”的第一步！
/// ================================================================================

///|
test "TypeCheck Normal Type Test" {
  let ctx = Context::new()
  let code =
    #|Unit Int Bool Double String
    #|(Int, Bool, String) Array[Int]
    #|Array[(Int, Double)]
    #|(Int, Bool) -> Double
  let tokens = @lexer.tokenize(code)
  let (t, tok_view) = @parser.parse_type(tokens)
  let t = ctx.check_parser_type(t)
  assert_true(t.kind is Unit)
  let (t, tok_view) = @parser.parse_type(tok_view)
  let t = ctx.check_parser_type(t)
  assert_true(t.kind is Int)
  let (t, tok_view) = @parser.parse_type(tok_view)
  let t = ctx.check_parser_type(t)
  assert_true(t.kind is Bool)
  let (t, tok_view) = @parser.parse_type(tok_view)
  let t = ctx.check_parser_type(t)
  assert_true(t.kind is Double)
  let (t, tok_view) = @parser.parse_type(tok_view)
  let t = ctx.check_parser_type(t)
  assert_true(t.kind is String)
  let (t, tok_view) = @parser.parse_type(tok_view)
  let t = ctx.check_parser_type(t)
  assert_true(
    t.kind is Tuple([t1, t2, t3]) && t1 is Int && t2 is Bool && t3 is String,
  )
  let (t, tok_view) = @parser.parse_type(tok_view)
  let t = ctx.check_parser_type(t)
  assert_true(t.kind is Array(t1) && t1 is Int)
  let (t, tok_view) = @parser.parse_type(tok_view)
  let t = ctx.check_parser_type(t)
  assert_true(
    t.kind is Array(t1) && t1 is Tuple([t2, t3]) && t2 is Int && t3 is Double,
  )
  let (t, _) = @parser.parse_type(tok_view)
  let t = ctx.check_parser_type(t)
  assert_true(
    t.kind is Function([t1, t2], t3) && t1 is Int && t2 is Bool && t3 is Double,
  )
}

///|
test "TypeCheck Defined Type Test" {
  let ctx = Context::new()
  ctx.struct_defs.set("Point", {
    name: "Point",
    fields: [],
    methods: Map::new(),
  })
  ctx.struct_defs.set("Circle", {
    name: "Circle",
    fields: [],
    methods: Map::new(),
  })
  ctx.struct_defs.set("Rectangle", {
    name: "Rectangle",
    fields: [],
    methods: Map::new(),
  })
  // Note: No Triangle
  let code =
    #|Point Circle Rectangle Triangle
    #|Array[Point] (Point, Circle)
    #|(Rectangle, Point) -> Circle
    #|Array[Triangle]
  let tokens = @lexer.tokenize(code)
  let (t, tok_view) = @parser.parse_type(tokens)
  let t = ctx.check_parser_type(t)
  assert_true(t.kind is Struct("Point"))
  let (t, tok_view) = @parser.parse_type(tok_view)
  let t = ctx.check_parser_type(t)
  assert_true(t.kind is Struct("Circle"))
  let (t, tok_view) = @parser.parse_type(tok_view)
  let t = ctx.check_parser_type(t)
  assert_true(t.kind is Struct("Rectangle"))
  let (t, tok_view) = @parser.parse_type(tok_view)
  let t = try? ctx.check_parser_type(t)
  assert_true(t is Err(_)) // Triangle is not defined
  let (t, tok_view) = @parser.parse_type(tok_view)
  let t = ctx.check_parser_type(t)
  assert_true(t.kind is Array(t1) && t1 is Struct("Point"))
  let (t, tok_view) = @parser.parse_type(tok_view)
  let t = ctx.check_parser_type(t)
  assert_true(
    t.kind is Tuple([t1, t2]) && t1 is Struct("Point") && t2 is Struct("Circle"),
  )
  let (t, tok_view) = @parser.parse_type(tok_view)
  let t = ctx.check_parser_type(t)
  assert_true(
    t.kind is Function([t1, t2], t3) &&
    t1 is Struct("Rectangle") &&
    t2 is Struct("Point") &&
    t3 is Struct("Circle"),
  )
  let (t, _) = @parser.parse_type(tok_view)
  let t = try? ctx.check_parser_type(t)
  assert_true(t is Err(_)) // Triangle is not defined
}
/// ================================================================================
/// # 倒数第二章：检查整个程序
///
/// 🎉 **祝贺你！你已经到达了类型检查阶段的重要里程碑！** 🎉
///
/// 我们已经分别构建了用于检查表达式、语句、函数和结构体的所有组件。
/// 现在，是时候将它们全部整合起来，在 `typecheck/program.mbt` 中实现最终的入口函数 `check_program`，
/// 它将负责对整个程序进行完整的类型检查。
///
/// ## 🎯 你的任务：实现 `check_program`
///
/// `check_program` 函数是整个类型检查阶段的总指挥。它的核心是采用一个经典的两阶段（Two-Pass）策略来解决前向引用（Forward Reference）和互相递归的问题。
///
/// ### 💡 实现思路：两阶段检查（Two-Pass Checking）
///
/// **第一阶段：注册（Registration Pass）**
///
/// 在真正检查任何函数体或表达式之前，我们首先需要“总览”整个程序，了解所有顶层定义的名字和“签名”。
///
/// 1.  **注册结构体：**
///     *   实现一个 `collect_struct_names` 辅助函数。
///     *   遍历程序中所有的 `struct` 定义，将它们的名字（`name`）记录到 `Context` 的 `struct_defs` 表中。此时，我们只关心名字，不关心其内部字段。
///
/// 2.  **注册函数和全局变量：**
///     *   实现一个 `collect_function_types` 辅助函数。
///     *   遍历所有顶层的 `fn` 定义。对于每一个函数，转换其参数和返回值的类型，构造出 `Function` 类型，然后将其名字和类型签名存入 `Context` 的 `func_types` 和全局 `type_env` 中。
///     *   同样，遍历所有顶层的 `let` 绑定，检查其类型并存入全局 `type_env`。
///
/// > 完成第一阶段后，`Context` 就有了一张“全局符号表”，知道了程序中所有顶层“有什么”，即使我们还没检查它们“做什么”。
///
/// **第二阶段：检查（Checking Pass）**
///
/// 现在，所有定义都已“备案”，我们可以开始真正的检查了。
///
/// 1.  在 `check_program` 函数中，按顺序调用你之前实现的检查函数：
/// 2.  遍历并调用 `check_struct_def` 检查每个结构体的字段类型。
/// 3.  遍历并调用 `check_top_let` 检查每个全局 `let` 绑定的表达式。
/// 4.  遍历并调用 `check_top_function` 检查每个顶层函数的函数体。由于所有函数签名都已在第一阶段注册，函数间的互相调用和递归调用此时都可以被正确地检查。
///
/// ---
///
/// ### 🚀 见证你的成果！
///
/// 完成 `check_program` 后，你就拥有了一个功能完备的 MiniMoonBit 类型检查器！
///
/// **再次祝贺你完成了这一重要的里程碑！接下来，我们将进入类型检查的最终阶段！**
///
/// ---
///
/// **阶段性测试：**
///
/// ```bash
/// moon test -p typecheck -f typecheck_program_test.mbt
/// ```
/// ================================================================================

///|
test "Program TypeCheck Test" {
  let code =
    #|let a = 3;
    #|let b = 4;
    #|fn fold(arr: Array[Int], f: (Int, Int) -> Int, init: Int) -> Int { 
    #|  let mut result = init;
    #|  let mut i = 0; 
    #|  while i < arr.length() {
    #|    result = f(result, arr[i]);
    #|  }
    #|  result
    #|}
    #|
    #|fn main {
    #|  fn max(a, b) { if a > b { a } else { b } }
    #|  fn min(a, b) { if a < b { a } else { b } }
    #|  let numbers = [a, 1, b, 1, 5, 9, 2, 6, 5];
    #|  let maximum = fold(numbers, max, -1000);
    #|  let minimum = fold(numbers, min, 1000);
    #|  let max_min_diff = maximum - minimum;
    #|  print_int(max_min_diff);
    #|}
  let ctx = Context::new()
  ctx.type_env.set("print_int", Type::{
    kind: Function([Int], Unit),
    mutable: false,
  })
  ctx.func_types.set("print_int", Function([Int], Unit))
  // Type check the program
  let tokens = @lexer.tokenize(code)
  let program = @parser.parse(tokens)
  let _ = ctx.check_program(program)

}
/// ================================================================================
/// # 类型检查表达式：ApplyExpr
///
/// 我们已经能够检查最基本的原子表达式了。现在，我们向上走一步，开始处理 `ApplyExpr`。
///
/// 在语法分析阶段，`ApplyExpr` 是一个复合概念，它以一个 `AtomExpr` 为基础，后面可以跟随一系列的函数调用 `()`、数组索引 `[]` 或字段访问 `.`。
///
/// 在类型检查阶段，我们也需要一个 `check_apply_expr` 函数来处理它。
///
/// ## 🎯 你的任务：实现 `check_apply_expr` 的基础情况
///
/// 你的任务是在 `typecheck/apply_expr.mbt` 文件中实现 `Context::check_apply_expr` 函数。
///
/// ### 💡 实现思路
///
/// 本次挑战的测试用例非常简单，只涉及 `ApplyExpr` 最基础的形式：即它仅仅是 `AtomExpr` 的一个包装。
///
/// 因此，你的 `check_apply_expr` 函数现在只需要处理 `parser::ApplyExprKind::AtomExpr` 这一种情况。
///
/// 1.  在 `check_apply_expr` 中，`match` 传入的 `apply_expr.kind`。
/// 2.  当它是 `AtomExpr(atom_expr)` 时，直接调用我们上一关实现的 `self.check_atom_expr(atom_expr)`。
/// 3.  `check_atom_expr` 会返回一个带类型的原子表达式。你需要用它来构建一个新的、带类型的 `typecheck::ApplyExpr`，并将其类型（`ty`）设置为刚刚返回的原子表达式的类型。
///
/// 我们将在后续挑战中逐步为 `check_apply_expr` 添加处理函数调用、数组访问等更复杂的能力。
///
/// ---
///
/// **阶段性测试：**
///
/// 完成后，运行以下命令来检验你的实现：
///
/// ```bash
/// moon test -p typecheck -f typecheck_simple_apply_expr_test.mbt
/// ```
///
/// 加油！我们正在稳步构建类型检查器的层次结构。
/// ================================================================================

///|
test "Simple Apply Expression Type Check" {
  let code =
    #|42 3.14 true "Hello" x y z
  let ctx = Context::new()
  ctx.type_env.set("x", { kind: TypeKind::Double, mutable: false })
  ctx.type_env.set("y", { kind: TypeKind::Bool, mutable: false })
  ctx.type_env.set("z", { kind: TypeKind::String, mutable: false })
  // Parse
  let tokens = @lexer.tokenize(code)
  // Type of 42
  let (a, tok_view) = @parser.parse_apply_expr(tokens[:])
  let a = ctx.check_apply_expr(a)
  assert_true(a.ty is Int)
  // Type of 3.14
  let (a, tok_view) = @parser.parse_apply_expr(tok_view)
  let a = ctx.check_apply_expr(a)
  assert_true(a.ty is Double)
  // Type of true
  let (a, tok_view) = @parser.parse_apply_expr(tok_view)
  let a = ctx.check_apply_expr(a)
  assert_true(a.ty is Bool)
  // Type of "Hello"
  let (a, tok_view) = @parser.parse_apply_expr(tok_view)
  let a = ctx.check_apply_expr(a)
  assert_true(a.ty is String)
  // Type of x
  let (a, tok_view) = @parser.parse_apply_expr(tok_view)
  let a = ctx.check_apply_expr(a)
  assert_true(a.ty is Double)
  // Type of y
  let (a, tok_view) = @parser.parse_apply_expr(tok_view)
  let a = ctx.check_apply_expr(a)
  assert_true(a.ty is Bool)
  // Type of z
  let (a, _) = @parser.parse_apply_expr(tok_view)
  let a = ctx.check_apply_expr(a)
  assert_true(a.ty is String)
}
/// ================================================================================
/// # 类型检查表达式：从原子表达式开始
///
/// 恭喜你，我们已经完成了对顶层声明的类型检查！
/// 现在，我们将深入编译器的核心腹地：**表达式的类型检查**。
///
/// 我们的最终目标是实现一个 `check_expr` 函数，它能够确定任何复杂表达式的类型。
/// 但正如我们在语法分析阶段所做的那样，我们将采用“自底向上”的策略，从最简单的部分开始。
///
/// ## 🎯 你的任务：实现 `check_atom_expr`
///
/// **原子表达式（AtomExpr）**是所有复杂表达式的基石。
/// 你的第一个任务是在 `typecheck/atom_expr.mbt` 文件中实现 `Context::check_atom_expr` 函数。
///
/// 这个函数接收一个来自 parser 的 `AtomExpr`，并返回一个**带有类型信息**的新 `AtomExpr`。
///
/// ### 💡 实现思路
///
/// 你需要在 `check_atom_expr` 中使用 `match` 语句来处理不同种类的原子表达式：
///
/// 1.  **字面量（Literals）：**
///     *   对于 `Int(v)`，其类型显然是 `TypeKind::Int`。
///     *   对于 `Double(v)`，其类型是 `TypeKind::Double`。
///     *   对于 `Bool(v)`，其类型是 `TypeKind::Bool`。
///     *   对于 `String(s)`，其类型是 `TypeKind::String`。
///
/// 2.  **标识符（Identifiers）：**
///     *   对于 `Ident(name)`，情况变得有趣起来。这代表一个变量。
///     *   它的类型是什么？我们必须在**类型环境（Type Environment）**中查找它！
///     *   `Context` 结构体中包含一个 `type_env` 字段，它是一个 `Map`，存储了当前作用域内所有已知变量的类型。
///     *   你需要从 `self.type_env` 中查找 `name` 对应的类型。如果找不到，就应该抛出一个 `TypeCheckError` 错误。
///
/// **请注意：**
/// 本次挑战的测试用例只包含上述几种情况。你暂时**不需要**处理 `Paren`、`Tuple`、`Array` 等更复杂的原子表达式，我们将在后续的挑战中逐步完善它们。
///
/// ---
///
/// **阶段性测试：**
///
/// 完成后，运行以下命令来检验你的实现：
///
/// ```bash
/// moon test -p typecheck -f typecheck_simple_atom_expr_test.mbt
/// ```
///
/// 加油！这是我们构建类型推断引擎的第一步！
/// ================================================================================

///|
test "Simple Atom Expression Type Check" {
  let code =
    #|42 3.14 true "Hello" x y z
  let ctx = Context::new()
  ctx.type_env.set("x", { kind: TypeKind::Double, mutable: false })
  ctx.type_env.set("y", { kind: TypeKind::Bool, mutable: false })
  ctx.type_env.set("z", { kind: TypeKind::String, mutable: false })
  // Parse
  let tokens = @lexer.tokenize(code)
  // Type of 42
  let (a, tok_view) = @parser.parse_atom_expr(tokens[:])
  let a = ctx.check_atom_expr(a)
  assert_true(a.ty is Int)
  // Type of 3.14
  let (a, tok_view) = @parser.parse_atom_expr(tok_view)
  let a = ctx.check_atom_expr(a)
  assert_true(a.ty is Double)
  // Type of true
  let (a, tok_view) = @parser.parse_atom_expr(tok_view)
  let a = ctx.check_atom_expr(a)
  assert_true(a.ty is Bool)
  // Type of "Hello"
  let (a, tok_view) = @parser.parse_atom_expr(tok_view)
  let a = ctx.check_atom_expr(a)
  assert_true(a.ty is String)
  // Type of x
  let (a, tok_view) = @parser.parse_atom_expr(tok_view)
  let a = ctx.check_atom_expr(a)
  assert_true(a.ty is Double)
  // Type of y
  let (a, tok_view) = @parser.parse_atom_expr(tok_view)
  let a = ctx.check_atom_expr(a)
  assert_true(a.ty is Bool)
  // Type of z
  let (a, _) = @parser.parse_atom_expr(tok_view)
  let a = ctx.check_atom_expr(a)
  assert_true(a.ty is String)
}
/// ================================================================================
/// # 类型检查的核心：Expr
///
/// 我们已经可以处理 `AtomExpr` 和 `ApplyExpr` 了。现在，我们来到了类型检查的核心枢纽：`check_expr` 函数。
///
/// `Expr` 是一个递归的枚举类型，它可以代表各种复杂的表达式，如一元运算、二元运算等。
/// `check_expr` 的职责就是深入到这些表达式的内部，验证它们的类型规则，并最终确定整个表达式的类型。
///
/// ## 🎯 你的任务：实现 `check_expr`
///
/// 你的任务是在 `typecheck/expr.mbt` 文件中实现 `Context::check_expr` 函数。
/// 本次挑战的测试覆盖了多种表达式，你需要一次性处理它们！
///
/// ### 💡 实现思路
///
/// 你需要在 `check_expr` 中 `match` 传入的 `expr.kind`，并为不同的情况编写类型检查逻辑：
///
/// 1.  **`ApplyExpr(apply_expr)`:**
///     *   这是最简单的情况。直接调用我们刚完成的 `self.check_apply_expr(apply_expr)`。
///     *   返回的 `ApplyExpr` 已经带有了类型，用它来构造一个 `typecheck::Expr` 并返回。
///
/// 2.  **`NotExpr(inner_expr)` (逻辑非 `!`)**
///     *   首先，递归调用 `self.check_expr(inner_expr)` 来检查内部表达式。
///     *   **类型规则：** `!` 操作符只能用于 `Bool` 类型。你需要检查 `inner_expr` 的类型是否为 `Bool`。如果不是，就抛出类型错误。
///     *   **返回类型：** `NotExpr` 本身的类型永远是 `Bool`。
///
/// 3.  **`NegExpr(inner_expr)` (取反 `-`)**
///     *   同样，递归调用 `self.check_expr(inner_expr)`。
///     *   **类型规则：** `-` 操作符在我们的语言中只能用于 `Int` 或 `Double`。你需要检查 `inner_expr` 的类型。
///     *   **返回类型：** `NegExpr` 的类型与它内部表达式的类型相同。
///
/// 4.  **`BinaryExpr(op, left, right)` (二元运算)**
///     *   这是最复杂的部分。首先，递归调用 `check_expr` 检查左右两个子表达式 `left` 和 `right`。
///     *   **通用规则：** 对于所有二元运算，左右两个操作数的类型必须兼容（在我们的简单实现中，意味着类型必须完全相同）。你可以使用 `self.is_type_compatible(...)` 辅助函数来判断。
///     *   **根据操作符 `op` 判断返回类型：**
///         *   **算术运算 (`+`, `-`, `*`, `/`, `%`)：** 操作数必须是 `Int` 或 `Double`。返回类型与操作数类型相同。
///         *   **比较运算 (`>`, `<`, `==`, `!=`, `>=`, `<=`)：** 操作数可以是 `Int` 或 `Double`。返回类型永远是 `Bool`。
///         *   **逻辑运算 (`&&`, `||`)：** 操作数必须是 `Bool`。返回类型也是 `Bool`。（注：本次测试未覆盖，但可以提前思考）
///
/// ---
///
/// **阶段性测试：**
///
/// 完成后，运行以下命令来检验你的实现：
///
/// ```bash
/// moon test -p typecheck -f typecheck_simple_expr_test.mbt
/// ```
///
/// 加油！这是类型检查器中工作量最大、也最核心的部分。
/// ================================================================================

///|
test "Simple Expression Type Check" {
  let code =
    #|42 ; 3.14 ; true ; "Hello";
    #|!true ; !false ; !x ;
    #|-42 ; -3.14 ; -y ;
    #|1 + 3; 4 - 5 ; 6 * 7; 8.0 / 2.0; 9 % 4;
    #|1 > 2; 42.0 >= y; x == true ;
  let ctx = Context::new()
  ctx.type_env.set("x", { kind: TypeKind::Bool, mutable: false })
  ctx.type_env.set("y", { kind: TypeKind::Double, mutable: false })
  // Parse
  let tokens = @lexer.tokenize(code)
  // Type of 42
  let (a, tok_view) = @parser.parse_expr(tokens[:])
  let a = ctx.check_expr(a)
  assert_true(a.ty is Int)
  // Type of 3.14
  let (a, tok_view) = @parser.parse_expr(tok_view[1:])
  let a = ctx.check_expr(a)
  assert_true(a.ty is Double)
  // Type of true
  let (a, tok_view) = @parser.parse_expr(tok_view[1:])
  let a = ctx.check_expr(a)
  assert_true(a.ty is Bool)
  // Type of "Hello"
  let (a, tok_view) = @parser.parse_expr(tok_view[1:])
  let a = ctx.check_expr(a)
  assert_true(a.ty is String)
  // Type of !true
  let (a, tok_view) = @parser.parse_expr(tok_view[1:])
  let a = ctx.check_expr(a)
  assert_true(a.ty is Bool)
  // Type of !false
  let (a, tok_view) = @parser.parse_expr(tok_view[1:])
  let a = ctx.check_expr(a)
  assert_true(a.ty is Bool)
  // Type of !x
  let (a, tok_view) = @parser.parse_expr(tok_view[1:])
  let a = ctx.check_expr(a)
  assert_true(a.ty is Bool)
  // Type of -42
  let (a, tok_view) = @parser.parse_expr(tok_view[1:])
  let a = ctx.check_expr(a)
  assert_true(a.ty is Int)
  // Type of -3.14
  let (a, tok_view) = @parser.parse_expr(tok_view[1:])
  let a = ctx.check_expr(a)
  assert_true(a.ty is Double)
  // Type of -y
  let (a, tok_view) = @parser.parse_expr(tok_view[1:])
  let a = ctx.check_expr(a)
  assert_true(a.ty is Double)
  // Type of 1 + 3
  let (a, tok_view) = @parser.parse_expr(tok_view[1:])
  let a = ctx.check_expr(a)
  assert_true(a.ty is Int)
  // Type of 4 - 5
  let (a, tok_view) = @parser.parse_expr(tok_view[1:])
  let a = ctx.check_expr(a)
  assert_true(a.ty is Int)
  // Type of 6 * 7
  let (a, tok_view) = @parser.parse_expr(tok_view[1:])
  let a = ctx.check_expr(a)
  assert_true(a.ty is Int)
  // Type of 8.0 / 2.0
  let (a, tok_view) = @parser.parse_expr(tok_view[1:])
  let a = ctx.check_expr(a)
  assert_true(a.ty is Double)
  // Type of 9 % 4
  let (a, tok_view) = @parser.parse_expr(tok_view[1:])
  let a = ctx.check_expr(a)
  assert_true(a.ty is Int)
  //// Type of 1 > 2
  let (a, tok_view) = @parser.parse_expr(tok_view[1:])
  let a = ctx.check_expr(a)
  assert_true(a.ty is Bool)
  //// Type of 42 == y
  let (a, tok_view) = @parser.parse_expr(tok_view[1:])
  let a = ctx.check_expr(a)
  assert_true(a.ty is Bool)
  //// Type of x == true
  let (a, _) = @parser.parse_expr(tok_view[1:])
  let a = ctx.check_expr(a)
  assert_true(a.ty is Bool)
}
/// ================================================================================
/// # 类型检查：结构体构造
///
/// 我们已经可以定义结构体了，现在我们需要检查它的**构造（Construction）**过程。
/// 类型检查器必须确保我们用于构造结构体的字段名和值的类型都是正确的。
///
/// ## 🎯 你的任务：实现 `check_struct_construct_expr`
///
/// 你的任务是在 `typecheck/struct_construct_expr.mbt` 文件中实现 `Context::check_struct_construct_expr` 函数。
///
/// 这个函数在 `check_atom_expr` 内部被调用，当遇到 `StructName::{...}` 语法时触发。
///
/// ### 💡 实现思路
///
/// 检查 `MyStruct::{ field1: value1, ... }` 的逻辑如下：
///
/// 1.  **查找结构体定义：**
///     *   从 `Context` 的 `struct_defs` 表中，根据名字 `MyStruct` 查找到它的定义。如果找不到，说明该结构体未定义，应抛出错误。
///
/// 2.  **遍历并检查所有字段：**
///     *   遍历构造表达式中提供的每一个 `field: value` 对。
///     *   对于每个字段，首先检查结构体定义中是否存在同名字段。如果不存在，抛出错误。
///     *   调用 `check_expr` 检查 `value` 的类型。
///     *   使用 `is_type_compatible` 验证 `value` 的类型是否与结构体定义中该字段的类型相匹配。如果不匹配，抛出错误。
///
/// 3.  **检查字段完整性：**
///     *   一个完整的实现还需要检查，构造表达式中提供的字段是否包含了结构体定义中所有未声明为可选的字段。
///     *   为了简化，在我们的 MiniMoonBit 中，我们要求构造时必须提供所有字段。你可以通过比较构造表达式中的字段数量和定义中的字段数量来做一个简单的检查。
///
/// 4.  **确定表达式类型：**
///     *   如果所有检查都通过，那么整个构造表达式的类型就是该结构体本身的类型，即 `TypeKind::Struct("MyStruct")`。
///
/// ---
///
/// **阶段性测试：**
///
/// ```bash
/// moon test -p typecheck -f typecheck_struct_construct_test.mbt
/// ```
/// ================================================================================

///|
test "Struct Construct TypeCheck Test" {
  let code =
    #|struct Point { x: Int; y: Int; }
    #|let p1 = Point::{ x: 1, y: 2 };
  let tokens = @lexer.tokenize(code)
  let ctx = Context::new()

  // 1. Parse and check the struct definition to populate the context
  let (struct_def, tok_view1) = @parser.parse_struct_def(tokens)
  let _ = ctx.check_struct_def(struct_def) // Assumes check_struct_def works

  // 2. Parse and check the valid `let p1 = ...` statement
  let (let_stmt1, _) = @parser.parse_let_stmt(tok_view1)
  let _ = ctx.check_let_stmt(let_stmt1)
  let p1_type = ctx.lookup_type("p1")
  assert_true(p1_type is Some({ kind: Struct("Point"), .. }))
}
/// ================================================================================
/// # 类型检查自定义类型：结构体
///
/// 我们已经能够将 parser 解析出的类型转换为类型检查器中的内部表示了。
/// 现在，让我们来处理一个更重要的部分：**检查用户自定义的结构体（Struct）**。
///
/// 当我们检查一个结构体定义时，主要任务是验证其所有字段的类型都是已知的、合法的类型。
///
/// ## 🎯 你的任务：实现 `check_struct_def`
///
/// 你的任务是在 `typecheck/struct_def.mbt` 文件中实现 `Context::check_struct_def` 函数。
///
/// 这个函数接收一个从 parser 传来的 `StructDef`，然后需要：
/// 1.  遍历结构体的每一个字段。
/// 2.  调用我们之前实现的 `check_parser_type`，将每个字段的 parser 类型转换为类型检查器的内部类型。
/// 3.  构造并返回一个新的、已检查过的 `StructDef`（这里的“新”指的是类型检查器内部的 AST 节点，其定义可能与 parser 的略有不同）。
///
/// ---
///
/// ### 🤔 深入思考：循环引用与前向引用
///
/// 在实现 `check_struct_def` 时，一个非常经典的编译器问题会摆在你的面前：
///
/// 考虑以下代码：
///
/// ```moonbit
/// struct Node {
///   next: List; // `List` 在这里被使用
/// }
///
/// struct List {
///   head: Node; // `Node` 在这里被使用
/// }
/// ```
///
/// 当类型检查器处理 `struct Node` 时，它遇到了 `List` 类型。但此时，`List` 结构体还尚未被处理！
/// 这种在定义之前就被引用的情况，我们称之为**前向引用（Forward Reference）**。
///
/// **请你想一想：**
///
/// > 我们的类型检查器应该如何设计，才能正确处理这种情况？
/// > 如果只是简单地从上到下依次处理每个结构体定义，会发生什么？
///
/// **💡 提示：两阶段处理（Two-Pass）**
///
/// 解决这个问题的一个经典方法是采用“两阶段处理”：
///
/// 1.  **第一阶段（注册阶段）：** 遍历所有的结构体定义，但只记录下它们的**名字**。将所有结构体的名字注册到一个集合或 `Map` 中，这样编译器就知道“存在哪些结构体”。
/// 2.  **第二阶段（检查阶段）：** 再次遍历所有的结构体定义。这一次，我们真正地去检查每个结构体内部的字段。因为在第一阶段我们已经注册了所有结构体的名字，所以当我们在 `Node` 中遇到 `List` 时，我们可以在注册表中查到 `List` 是一个已知的（虽然可能尚未完全检查的）类型，从而允许这种引用。
///
/// 在我们的 MiniMoonBit 编译器中，`check_program` 函数（位于 `typecheck/program.mbt`）已经为你搭建好了这个两阶段处理的框架。
/// 你现在需要实现的 `check_struct_def` 正是这个框架中的第二阶段的核心部分。
///
/// ---
///
/// **阶段性测试：**
///
/// 完成后，运行以下命令来检验你的实现：
///
/// ```bash
/// moon test -p typecheck -f typecheck_struct_def_test.mbt
/// ```
///
/// 加油！你正在处理编译器设计中一个非常核心且有趣的问题！
/// ================================================================================

///|
test "Struct Definition Typecheck" {
  let code =
    #|struct Point { x: Int; mut y: Int; }
    #|struct Queue { data: Array[Int]; mut front: Int; mut back: Int; }
  let tokens = @lexer.tokenize(code)
  let ctx = Context::new()
  // Parse
  let (struct_def, tok_view) = @parser.parse_struct_def(tokens[:])
  // Typecheck for `struct Point { x: Int; mut y: Int }`
  let struct_def = ctx.check_struct_def(struct_def)
  assert_true(struct_def.name is "Point")
  assert_true(struct_def.fields.length() is 2)
  assert_true(
    struct_def.fields is [f1, f2] &&
    f1 is { name: "x", ty: { kind: Int, mutable: false } } &&
    f2 is { name: "y", ty: { kind: Int, mutable: true } },
  )
  // Typecheck for `struct Queue { data: Array[Int]; mut front: Int; mut back: Int }`
  let (struct_def, _) = @parser.parse_struct_def(tok_view)
  let struct_def = ctx.check_struct_def(struct_def)
  assert_true(struct_def.name is "Queue")
  assert_true(struct_def.fields.length() is 3)
  assert_true(
    struct_def.fields is [f1, f2, f3] &&
    f1 is { name: "data", ty: { kind: Array(Int), mutable: false } } &&
    f2 is { name: "front", ty: { kind: Int, mutable: true } } &&
    f3 is { name: "back", ty: { kind: Int, mutable: true } },
  )
}
/// ================================================================================
/// # 类型检查：顶层函数
///
/// 我们已经攻克了最复杂的局部函数，现在回到顶层函数的类型检查，它要简单得多。
///
/// 顶层函数是构成程序的主体。对它们的检查是类型检查流程中非常重要的一环。
///
/// ## 🎯 你的任务：实现 `check_top_function`
///
/// 你的任务是在 `typecheck/top_function.mbt` 文件中实现 `Context::check_top_function` 函数。
///
/// ### 💡 实现思路
///
/// 检查顶层函数的主体与检查局部函数非常相似，但由于顶层函数（`main`除外）的所有类型都必须显式注解，我们无需进行复杂的类型推断。
///
/// 整个流程如下：
///
/// 1.  **查找函数签名：**
///     *   在检查函数体之前，我们假设已经通过一个“预处理”阶段，将所有顶层函数的签名（函数名、参数类型、返回类型）都注册到了 `Context` 的 `func_types` 表中。
///     *   因此，函数的第一步是从 `func_types` 中查找到当前要检查的函数 `func` 的签名。
///
/// 2.  **创建函数作用域：**
///     *   调用 `enter_scope()` 为函数体创建一个新的、独立的作用域。
///
/// 3.  **设置上下文并填充作用域：**
///     *   将 `Context` 的 `current_func_ret_ty` 设置为从函数签名中查到的返回类型。
///     *   遍历函数的所有参数，将它们的名字和类型添加到新的作用域中。
///
/// 4.  **检查函数体：**
///     *   调用 `check_block_expr` 对整个函数体进行类型检查。
///
/// 5.  **验证返回类型：**
///     *   检查 `check_block_expr` 返回的函数体类型，是否与函数签名的返回类型兼容。
///
/// 6.  **清理：**
///     *   调用 `exit_scope()` 退出函数作用域。
///     *   将 `current_func_ret_ty` 重置为 `None`。
///
/// ---
///
/// **阶段性测试：**
///
/// ```bash
/// moon test -p typecheck -f typecheck_top_func_test.mbt
/// ```
/// ================================================================================

///|
test "Top Function TypeCheck Test" {
  let code =
    #|fn fib(n : Int) -> Int {
    #|  if n <= 1 {
    #|    return n;
    #|  } else {
    #|    return fib(n - 1) + fib(n - 2);
    #|  }
    #|}
  let ctx = Context::new()
  ctx.func_types.set("fib", Function([Int], Int))
  ctx.type_env.set("fib", { kind: Function([Int], Int), mutable: false })
  // parse
  let tokens = @lexer.tokenize(code)
  let (top_func, _) = @parser.parse_top_function(tokens[:])
  let _ = ctx.check_top_function(top_func)

}
/// ================================================================================
/// # 类型检查语句：顶层 let
///
/// 除了函数内部的 `let mut`，我们的语言还支持在顶层（全局作用域）使用 `let` 来定义全局常量。
/// 对它的类型检查与 `let mut` 非常相似，但有一个关键的区别。
///
/// ## 🎯 你的任务：实现 `check_top_let`
///
/// 你的任务是在 `typecheck/top_let.mbt` 文件中实现 `Context::check_top_let` 函数。
///
/// ### 💡 实现思路
///
/// `check_top_let` 的逻辑几乎与 `check_let_mut_stmt` 完全相同：
///
/// 1.  检查 `=` 右侧表达式的类型。
/// 2.  如果存在类型注解，则验证其与表达式类型是否兼容。
/// 3.  将新变量的名称和类型添加到类型环境 `self.type_env` 中。
///
/// **唯一的区别在于：**
///
/// > 通过顶层 `let` 定义的变量是**不可变的（immutable）**。
/// > 因此，在将它添加到类型环境时，你必须将其标记为 `mutable: false`。
///
/// 这确保了编译器在后续的检查中，如果遇到试图修改该变量的赋值语句，能够正确地抛出错误。
///
/// ---
///
/// **阶段性测试：**
///
/// ```bash
/// moon test -p typecheck -f typecheck_top_let_test.mbt
/// ```
/// ================================================================================

///|
test "Top Let Stmt Type Check" {
  let code =
    #|let x : Int = 42;
    #|let y = true;
  let ctx = Context::new()
  // Parse
  let tokens = @lexer.tokenize(code)
  // Type check for `let x : Int = 42;`
  let (top_let1, tok_view) = @parser.parse_top_let(tokens[:])
  let checked_top_let1 = ctx.check_top_let(top_let1)
  assert_true(checked_top_let1.ty.kind is Int)
  let ty1 = ctx.lookup_type("x")
  assert_true(ty1 is Some(t) && t.kind is Int && t.mutable == false)

  // Type check for `let y = true;`
  let (top_let2, _) = @parser.parse_top_let(tok_view)
  let checked_top_let2 = ctx.check_top_let(top_let2)
  assert_true(checked_top_let2.ty.kind is Bool)
  let ty2 = ctx.lookup_type("y")
  assert_true(ty2 is Some(t) && t.kind is Bool && t.mutable == false)
}
/// ================================================================================
/// # 类型推断的魔法：类型变量与合一（Unification）
///
/// 欢迎来到我们编译器中最激动人心的部分之一：**类型推断（Type Inference）**。
/// 类型推断允许程序员省略部分或全部的类型注解，编译器会自动推导出这些变量的类型。
/// 它的核心魔法，就是**类型变量（Type Variables）**和**合一（Unification）**算法。
///
/// ## 🤔 为什么需要类型变量？
///
/// 想象一下这个场景：
///
/// ```moonbit
/// let a = [];
/// ```
///
/// 在这一行，`a` 的类型是 `Array[?]`。但我们完全不知道 `?` 应该是什么类型。
/// 为了解决这个问题，我们引入一个“占位符”类型，称之为**类型变量**。
/// 我们可以说 `a` 的类型是 `Array[TypeVar(0)]`，其中 `0` 是这个类型变量的唯一ID。
/// 我们将这个信息记录在 `Context` 的一张表里（例如 `type_vars: Map[Int, TypeKind]`）。
///
/// ## ⚙️ 类型变量如何工作：合一（Unification）
///
/// 类型变量的真正威力在于它们如何通过代码的上下文来获得具体的类型。这个过程称为“合一”。
///
/// **场景1：推断出具体类型**
///
/// 如果我们接下来看到 `a.push(1)`，类型检查器会分析 `push` 函数。它知道 `push` 的参数类型应该与数组的元素类型相同。
/// 因此，`Int` 类型必须与 `TypeVar(0)` 兼容。
/// 此时，我们就可以**合一** `TypeVar(0)` 和 `Int`，在我们的表中记录下：`TypeVar(0) = Int`。
/// `a` 的类型之谜就此解开，它是一个 `Array[Int]`。
///
/// **场景2：关联两个未知类型**
///
/// 假设我们有 `let b = []`，它的类型是 `Array[TypeVar(1)]`。
/// 如果代码中出现了 `a == b`，这意味着 `a` 和 `b` 的类型必须兼容。
/// 也就是说 `Array[TypeVar(0)]` 必须与 `Array[TypeVar(1)]` 兼容，这进一步要求 `TypeVar(0)` 必须与 `TypeVar(1)` 兼容。
///
/// 此时，我们将 `TypeVar(0)` 和 `TypeVar(1)` **合一**。我们可以在表中记录 `TypeVar(1) = TypeVar(0)`。
/// 这就像建立了一个“等价关系”。现在，任何关于 `TypeVar(0)` 的信息，都将自动传递给 `TypeVar(1)`。
///
/// **场景3：信息传递**
///
/// 延续场景2，如果我们稍后看到了 `a.push(1)`，我们推断出 `TypeVar(0) = Int`。
/// 因为我们已经知道 `TypeVar(1) = TypeVar(0)`，所以我们立刻也知道了 `TypeVar(1) = Int`。
/// `b` 的类型也随之确定为 `Array[Int]`。
///
/// ## 🎯 你的任务：实现 `is_type_compatible` 中的 `TypeVar` 逻辑
///
/// 你的任务就是将上述逻辑在 `typecheck/typedef.mbt` 的 `is_type_compatible` 函数中实现。
/// 你需要为 `match (a, b)` 添加处理 `TypeVar` 的分支：
///
/// *   **`TypeVar` vs. 具体类型（例如 `(TypeVar(id), Int)`）：**
///     将类型变量 `id` 与该具体类型进行合一。
/// *   **`TypeVar` vs. `TypeVar`（例如 `(TypeVar(id_a), TypeVar(id_b))`）：**
///     将两个类型变量进行合一。
///
/// 你可能需要一个辅助函数，例如 `set_var_type_to_typekind`，来更新你的类型变量表，并处理好“等价关系”的传递。
///
/// ---
///
/// **阶段性测试：**
///
/// 本次的测试用例会直接调用 `is_type_compatible` 来验证你的合一算法是否正确。
///
/// ```bash
/// moon test -p typecheck -f typecheck_type_var_test.mbt
/// ```
///
/// 加油！这是通往现代类型系统最关键、也最有趣的一步！
/// ================================================================================

///|
test "Type Var Test - 1" {
  let ctx = Context::new()
  ctx.type_vars.set(0, TypeVar(0))
  ctx.type_vars.set(1, TypeVar(1))
  ctx.type_vars.set(2, TypeVar(2))
  ctx.type_vars.set(3, TypeVar(3))
  // TVar(0) = Double
  let t1 = ctx.is_type_compatible(TypeVar(0), Double)
  assert_true(t1 is true)
  assert_true(ctx.type_vars.get(0).unwrap() is Double)
  // TVar(1) = TVar(0)
  let t2 = ctx.is_type_compatible(TypeVar(1), TypeVar(0))
  assert_true(t2 is true)
  assert_true(ctx.type_vars.get(1).unwrap() is Double)
  // TVar(2) = TVar(3)
  let t3 = ctx.is_type_compatible(TypeVar(2), TypeVar(3))
  assert_true(t3 is true)
  // TVAr(3) = Int, therefore TVar(2) = Int
  let t4 = ctx.is_type_compatible(TypeVar(3), Int)
  assert_true(t4 is true)
  assert_true(ctx.type_vars.get(2).unwrap() is Int)
  assert_true(ctx.type_vars.get(3).unwrap() is Int)
  let t5 = ctx.is_type_compatible(TypeVar(2), Double)
  assert_true(t5 is false)
}

///|
///
/// 0 == 1 == 2 == 3
/// 2 == (Double, Int)
///
/// 0, 1, 2, 3 should all resolve to (Double, Int)
test "Type Var Test - 2" {
  let ctx = Context::new()
  ctx.type_vars.set(0, TypeVar(0))
  ctx.type_vars.set(1, TypeVar(1))
  ctx.type_vars.set(2, TypeVar(2))
  ctx.type_vars.set(3, TypeVar(3))
  //
  let _ = ctx.is_type_compatible(TypeVar(0), TypeVar(1))
  let _ = ctx.is_type_compatible(TypeVar(1), TypeVar(2))
  let _ = ctx.is_type_compatible(TypeVar(2), TypeVar(3))
  let _ = ctx.is_type_compatible(TypeVar(3), TypeVar(0))
  let _ = ctx.is_type_compatible(TypeVar(2), Tuple([Double, Int]))
  let t0 = ctx.type_vars.get(0).unwrap()
  let t1 = ctx.type_vars.get(1).unwrap()
  let t2 = ctx.type_vars.get(2).unwrap()
  let t3 = ctx.type_vars.get(3).unwrap()
  assert_true(t0 is Tuple([Double, Int]))
  assert_true(t1 is Tuple([Double, Int]))
  assert_true(t2 is Tuple([Double, Int]))
  assert_true(t3 is Tuple([Double, Int]))
}
/// ================================================================================
/// # 类型检查控制流：while 循环
///
/// `while` 是我们语言中唯一的循环结构。与 `if-else` 不同，`while` 循环本身不产生值，因此它的类型检查要简单得多。
///
/// ## 🎯 你的任务：实现 `check_while_stmt`
///
/// 你的任务是在 `typecheck/while_stmt.mbt` 文件中实现 `Context::check_while_stmt` 函数。
///
/// ### 💡 实现思路
///
/// 1.  **检查条件：**
///     *   `while` 后面的条件表达式必须是 `Bool` 类型。你需要调用 `check_expr` 检查该条件。
///
/// 2.  **检查循环体：**
///     *   调用 `check_block_expr` 来检查循环体的代码块。
///     *   由于 `while` 循环不产生值，循环体块的类型可以被忽略。
///
/// 3.  **`while` 语句的类型：**
///     *   `while` 语句本身的类型永远是 `Unit`。
///
/// ---
///
/// **阶段性测试：**
///
/// ```bash
/// moon test -p typecheck -f typecheck_while_stmt_test.mbt
/// ```
/// ================================================================================

///|
test "While Stmt TypeCheck Test" {
  let code =
    #|let mut i = 0;
    #|while i < 10 {
    #|  i += 1;
    #|}
  let ctx = Context::new()
  // Parse
  let tokens = @lexer.tokenize(code)
  let (let_stmt, tok_view) = @parser.parse_let_mut_stmt(tokens[:])
  let _ = ctx.check_let_mut_stmt(let_stmt)
  let (while_stmt, _) = @parser.parse_while_stmt(tok_view)
  let _ = ctx.check_while_stmt(while_stmt)

}
/// ================================================================================
/// # 🎉 终章：完成类型检查器
///
/// 🎊 **恭喜你！你已经来到了类型检查阶段的最后一关！** 🎊
///
/// 经过前面的所有挑战，你已经构建了一个功能强大的类型检查系统。现在，是时候完成最后的步骤：
/// 实现 `typechecker.mbt` 中的 `typecheck` 函数，它将遍历整个语法树，将所有 `TypeVar` 替换为具体的实体类型。
///
/// ## 🎯 你的任务：实现 `typecheck` 函数
///
/// `typecheck` 函数是整个类型检查阶段的最终入口。它的核心任务是：
///
/// 1. **遍历整个语法树**：从程序的根节点开始，递归地访问每一个语法节点
/// 2. **替换类型变量**：将 AST 中所有的 `TypeVar` 替换为通过类型检查得到的实际类型
/// 3. **返回类型化的 AST**：返回一个所有类型都已确定的语法树
///
/// ### 💡 实现思路
///
/// 你已经实现了 `check_program` 函数，它会：
/// - 进行完整的类型检查
/// - 在 `Context` 中记录所有类型信息
/// - 确保程序在类型层面是正确的
///
/// 现在，你需要实现 `typecheck` 函数，它会：
/// - 调用 `check_program` 进行类型检查
/// - 遍历 AST，将 `TypeVar` 替换为实际类型
/// - 返回类型化后的 AST
///
/// **关键步骤：**
///
/// 1. **调用类型检查**：使用 `check_program` 对程序进行类型检查
/// 2. **遍历替换**：实现一个遍历函数，递归地访问每个节点
/// 3. **类型替换**：对于包含 `TypeVar` 的节点，从 `Context` 中查找对应的实际类型并替换
/// 4. **保持结构**：确保替换后的 AST 结构与原始结构完全一致
///
/// ## 🚀 见证你的成果！
///
/// 完成这个任务后，你就拥有了一个功能完备的 MiniMoonBit 类型检查器！
/// 你可以运行以下命令来测试你的实现：
///
/// ```bash
/// moon test -p typecheck -f typechecker_test.mbt
/// ```
///
/// 这个测试会验证你的 `typecheck` 函数是否正确地将所有 `TypeVar` 替换为了具体的类型。
///
/// ## 🎊 恭喜你完成了类型检查的所有内容！
///
/// 你已经成功构建了一个完整的类型检查系统，包括：
/// - ✅ 基础类型检查
/// - ✅ 表达式类型推断
/// - ✅ 语句类型检查
/// - ✅ 函数类型检查
/// - ✅ 结构体类型检查
/// - ✅ 程序级类型检查
/// - ✅ 类型变量替换
///
/// **这是一个了不起的成就！** 你已经掌握了现代编译器中最核心的静态分析技术之一。
///
/// **接下来，我们将进入编译器的下一个激动人心的阶段：KNF 转换！**
/// ================================================================================

///|
test "Program TypeCheck Test - 2" {
  let code =
    #|let a = 3;
    #|let b = 4;
    #|fn fold(arr: Array[Int], f: (Int, Int) -> Int, init: Int) -> Int { 
    #|  let mut result = init;
    #|  let mut i = 0; 
    #|  while i < arr.length() {
    #|    result = f(result, arr[i]);
    #|  }
    #|  result
    #|}
    #|
    #|fn main {
    #|  fn max(a, b) { if a > b { a } else { b } }
    #|  fn min(a, b) { if a < b { a } else { b } }
    #|  let numbers = [a, 1, b, 1, 5, 9, 2, 6, 5];
    #|  let maximum = fold(numbers, max, -1000);
    #|  let minimum = fold(numbers, min, 1000);
    #|  let max_min_diff = maximum - minimum;
    #|  println(max_min_diff);
    #|}
  let tokens = @lexer.tokenize(code)
  let program = @parser.parse(tokens)
  let program = typecheck(program)
  let program_str = program.to_string()
  assert_false(program_str.contains("TypeVar"))
}
