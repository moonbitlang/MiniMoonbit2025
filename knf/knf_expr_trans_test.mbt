/// ================================================================================
/// # 🎯 表达式 KNF 变换的综合测试：休息一下
///
/// 在完成了各种表达式的转换之后，我们现在要进行一个**综合测试**。
/// 这是一个"休息一下"的时刻，让我们来验证之前实现的所有表达式转换功能
/// 是否能够协同工作，处理更复杂的真实场景。
///
/// ## 🌟 测试内容
///
/// 这个测试包含了复杂的表达式转换：
/// - `max(a, b) + min(a, b)`：函数调用的组合
/// - `sum(arr) / arr.length()`：复杂表达式的分解
///
/// 如果测试失败，请检查函数调用处理、参数传递、临时变量创建等实现。
///
/// **准备好验证你的实现了吗？让我们开始测试！**
/// ================================================================================

///|
test "Expr Knf Transformation Test" {
  // Prelucde Parts
  // set a, b, arr, sum, point, mat, sqrt type in typecheck and knf context
  let typecheck_ctx = @typecheck.Context::new()
  let point_struct_def : @typecheck.StructDef = {
    name: "Point",
    fields: [
      { name: "x", ty: { kind: Int, mutable: false } },
      { name: "y", ty: { kind: Int, mutable: false } },
    ],
    methods: Map::new(),
  }
  typecheck_ctx.struct_defs.set("Point", point_struct_def)
  typecheck_ctx.type_env.set("a", { kind: Double, mutable: false })
  typecheck_ctx.type_env.set("b", { kind: Double, mutable: false })
  typecheck_ctx.type_env.set("arr", { kind: Array(Int), mutable: false })
  typecheck_ctx.type_env.set("point", { kind: Struct("Point"), mutable: false })
  typecheck_ctx.type_env.set("sum", {
    kind: Function([Array(Int)], Int),
    mutable: false,
  })
  typecheck_ctx.type_env.set("max", {
    kind: Function([Double, Double], Double),
    mutable: false,
  })
  typecheck_ctx.type_env.set("min", {
    kind: Function([Double, Double], Double),
    mutable: false,
  })
  let knf_ctx = @knf.Context::new()
  knf_ctx.globals.set("max", Function([Double, Double], Double))
  knf_ctx.globals.set("min", Function([Double, Double], Double))
  knf_ctx.globals.set("sum", Function([Array(Int)], Int))
  let _ = knf_ctx.add_new_name("a", Double)
  let _ = knf_ctx.add_new_name("b", Double)
  let _ = knf_ctx.add_new_name("arr", Array(Int))

  // Test Parts
  let code =
    #|max(a, b) + min(a, b) ;
    #|sum(arr) / arr.length() ;
  // Code parse, typecheck, knf transform
  let tokens = @lexer.tokenize(code)
  // Parse and transform `max(a, b) + min(a, b)`
  let (e, _) = @parser.parse_expr(tokens)
  let e = typecheck_ctx.check_expr(e)
  let (stmts, knf_expr) = knf_ctx.expr_to_knf(e)
  assert_true(
    stmts is [s1, s2] &&
    s1 is Let(n1, Double, Call({ id: "max", .. }, [a1, a2])) &&
    s2 is Let(n2, Double, Call({ id: "min", .. }, [a3, a4])) &&
    a1 is { id: "a", .. } &&
    a2 is { id: "b", .. } &&
    a3 is { id: "a", .. } &&
    a4 is { id: "b", .. } &&
    knf_expr is Binary(Add, l, r) &&
    n1 == l &&
    n2 == r,
  )
}
