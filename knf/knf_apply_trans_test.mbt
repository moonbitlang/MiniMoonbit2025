/// ================================================================================
/// # 🔧 Apply 表达式的 KNF 转换
///
/// ## 🎯 什么是 Apply 表达式？
///
/// Apply 表达式是编程语言中用于访问和调用的表达式，它们包括：
/// - 原子表达式（AtomExpr）
/// - 数组访问（ArrayAccess）
/// - 字段访问（FieldAccess）
/// - 函数调用（Call）
///
/// Apply 表达式的特点：
/// - 支持链式访问（如 `arr[0][1]`）
/// - 支持嵌套调用（如 `f(g(x))`）
/// - 需要递归处理子表达式
/// - 可能产生复杂的中间语句
///
/// ## 🔍 结构差异分析
///
/// 在语法树中，Apply 表达式的结构相对复杂：
/// - `AtomExpr`: 原子表达式
/// - `ArrayAccess`: 数组访问（ApplyExpr, Expr）
/// - `FieldAccess`: 字段访问（ApplyExpr, String）
/// - `Call`: 函数调用（ApplyExpr, Array[Expr]）
///
/// 在 KNF 中，Apply 表达式被转换为：
/// - `AtomExpr`: 直接转换为 KNF 原子表达式
/// - `ArrayAccess`: 转换为 `ArrayAccess(Name, Name)`
/// - `FieldAccess`: 转换为 `FieldAccess(Name, String)`
/// - `Call`: 转换为 `Call(Name, Array[Name])`
///
/// ## 🛠️ 实现思路
///
/// 实现 `apply_expr_to_knf` 函数需要四个主要分支：
///
/// ### 1. AtomExpr 处理
/// - 直接调用 `atom_expr_to_knf` 转换
/// - 这是最简单的情况，不需要额外处理
///
/// ### 2. ArrayAccess 处理
/// - 递归转换数组表达式和索引表达式
/// - 使用 `expr_to_knf_name` 创建临时变量
/// - 合并所有语句并返回 `ArrayAccess`
///
/// ### 3. FieldAccess 处理
/// - 递归转换结构体表达式
/// - 使用 `expr_to_knf_name` 创建临时变量
/// - 返回 `FieldAccess`
///
/// ### 4. Call 处理
/// - 递归转换被调用表达式和所有参数
/// - 为每个表达式创建临时变量
/// - 合并所有语句并返回 `Call`
///
/// ## 🔧 关键实现细节
///
/// ### 递归处理
/// Apply 表达式需要递归处理子表达式：
/// - 数组访问：`arr[0][1]` 需要先处理 `arr[0]`，再处理 `[1]`
/// - 字段访问：`point.x.y` 需要先处理 `point.x`，再处理 `.y`
/// - 函数调用：`f(g(x))` 需要先处理 `g(x)`，再处理 `f(...)`
///
/// ### 临时变量创建
/// 使用 `expr_to_knf_name` 为复杂表达式创建临时变量：
/// - 确保每个子表达式都有对应的 Name
/// - 避免重复计算
/// - 保持 KNF 的原子性
///
/// ### 语句合并
/// 需要正确合并所有子表达式产生的语句：
/// - 按照执行顺序合并语句
/// - 确保依赖关系正确
/// - 避免语句顺序错误
///
/// ### 类型转换
/// 需要正确转换表达式的类型：
/// - 使用 `typekind_to_knf` 转换类型
/// - 确保类型一致性
/// - 支持复杂类型（数组、结构体、函数）
///
/// ## 📝 测试用例解析
///
/// ### 测试用例 1：数组访问
/// arr[3]
/// 转换过程：
/// 1. 数组表达式 `arr` 是原子表达式，直接转换
/// 2. 索引表达式 `3` 需要创建临时变量
/// 3. 返回 `ArrayAccess(arr_name, tmp_name)`
///
/// ### 测试用例 2：变量索引
/// arr[x]
/// 转换过程：
/// 1. 数组表达式 `arr` 是原子表达式，直接转换
/// 2. 索引表达式 `x` 是原子表达式，直接转换
/// 3. 返回 `ArrayAccess(arr_name, x_name)`
///
/// ### 测试用例 3：字段访问
/// point.x
/// 转换过程：
/// 1. 结构体表达式 `point` 是原子表达式，直接转换
/// 2. 字段名 `x` 直接使用
/// 3. 返回 `FieldAccess(point_name, "x")`
///
/// ### 测试用例 4：函数调用
/// max(a + b, a - b)
/// 转换过程：
/// 1. 被调用表达式 `max` 是原子表达式，直接转换
/// 2. 参数 `a + b` 需要创建临时变量
/// 3. 参数 `a - b` 需要创建临时变量
/// 4. 返回 `Call(max_name, [tmp1, tmp2])`
///
/// ## 💡 设计思想
///
/// ### 递归处理
/// Apply 表达式支持链式访问，需要递归处理每个子表达式。
///
/// ### 原子化
/// 将复杂表达式分解为原子操作，使用临时变量存储中间结果。
///
/// ### 类型安全
/// 确保每个表达式都有正确的类型，支持复杂类型系统。
///
/// ### 语句顺序
/// 按照执行顺序合并语句，确保依赖关系正确。
///
/// ## 🚀 实现挑战
///
/// ### 递归复杂性
/// Apply 表达式可能嵌套很深，需要正确处理递归调用。
///
/// ### 语句合并
/// 需要正确合并多个子表达式产生的语句。
///
/// ### 临时变量管理
/// 需要为复杂表达式创建临时变量，避免命名冲突。
///
/// ### 类型转换
/// 需要正确转换各种复杂类型。
///
/// ## 🎯 实现目标
///
/// 完成 `apply_expr.mbt` 中的 `apply_expr_to_knf` 函数，实现 Apply 表达式的 KNF 转换。
/// 函数应该：
/// 1. 正确处理四种 Apply 表达式类型
/// 2. 递归处理所有子表达式
/// 3. 正确创建临时变量
/// 4. 正确合并语句
/// 5. 支持链式访问和嵌套调用
///
/// 现在让我们开始实现 Apply 表达式的转换吧！🚀
///
/// ================================================================================

///|
test "Apply Expr Knf Transformation Test" {
  // Prelude Parts
  // set a, b, x, arr, point, max type in typecheck and knf context
  let typecheck_ctx = @typecheck.Context::new()
  typecheck_ctx.type_env.set("a", { kind: Int, mutable: false })
  typecheck_ctx.type_env.set("b", { kind: Int, mutable: false })
  typecheck_ctx.type_env.set("x", { kind: Int, mutable: false })
  let point_struct_def : @typecheck.StructDef = {
    name: "Point",
    fields: [
      { name: "x", ty: { kind: Int, mutable: false } },
      { name: "y", ty: { kind: Int, mutable: false } },
    ],
    methods: Map::new(),
  }
  typecheck_ctx.struct_defs.set("Point", point_struct_def)
  typecheck_ctx.type_env.set("arr", { kind: Array(Int), mutable: false })
  typecheck_ctx.type_env.set("point", { kind: Struct("Point"), mutable: false })
  typecheck_ctx.type_env.set("max", {
    kind: Function([Int, Int], Int),
    mutable: false,
  })
  let knf_ctx = Context::new()
  knf_ctx.globals.set("max", Function([Int, Int], Int))
  let _ = knf_ctx.add_new_name("a", Int)
  let _ = knf_ctx.add_new_name("b", Int)
  let _ = knf_ctx.add_new_name("x", Int)
  let _ = knf_ctx.add_new_name("arr", Array(Int))
  let _ = knf_ctx.add_new_name("point", Struct("Point"))

  // Test Parts
  let code =
    #|arr[3]
    #|arr[x]
    #|point.x
    #|max(a + b, a - b)
  // Code parse, typecheck, knf transform
  let tokens = @lexer.tokenize(code)
  // Parse and transform `arr[3]`.
  let (e, tok_view) = @parser.parse_apply_expr(tokens)
  let e = typecheck_ctx.check_apply_expr(e)
  let (stmts, knf_expr) = knf_ctx.apply_expr_to_knf(e)
  assert_true(
    stmts is [s1] &&
    s1 is Let(n1, Int, Int(3)) &&
    knf_expr is ArrayAccess(arr_name, index_name) &&
    arr_name is { id: "arr", .. } &&
    index_name == n1,
  )
  // Parse and transform `arr[x]`.
  let (e, tok_view) = @parser.parse_apply_expr(tok_view)
  let e = typecheck_ctx.check_apply_expr(e)
  let (stmts, knf_expr) = knf_ctx.apply_expr_to_knf(e)
  assert_true(
    stmts is [] &&
    knf_expr is ArrayAccess(arr_name, index_name) &&
    arr_name is { id: "arr", .. } &&
    index_name is { id: "x", .. },
  )
  // Parse and transform `point.x`.
  let (e, tok_view) = @parser.parse_apply_expr(tok_view)
  let e = typecheck_ctx.check_apply_expr(e)
  let (stmts, knf_expr) = knf_ctx.apply_expr_to_knf(e)
  assert_true(
    stmts is [] &&
    knf_expr is FieldAccess(struct_name, field_name) &&
    struct_name is { id: "point", .. } &&
    field_name is "x",
  )
  // Parse and transform `max(a + b, a - b)`.
  let (e, _) = @parser.parse_apply_expr(tok_view)
  let e = typecheck_ctx.check_apply_expr(e)
  let (stmts, knf_expr) = knf_ctx.apply_expr_to_knf(e)
  assert_true(
    stmts is [s1, s2] &&
    s1 is Let(n1, Int, Binary(Add, l1, r1)) &&
    l1.id is "a" &&
    r1.id is "b" &&
    s2 is Let(n2, Int, Binary(Sub, l2, r2)) &&
    l2.id is "a" &&
    r2.id is "b" &&
    knf_expr is Call(callee_name, arg_names) &&
    callee_name.id is "max" &&
    arg_names == [n1, n2],
  )
}
