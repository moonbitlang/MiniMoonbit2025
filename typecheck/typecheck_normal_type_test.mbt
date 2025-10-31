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
  ctx.struct_defs.set("Point", { name: "Point", fields: [], methods: Map::new() })
  ctx.struct_defs.set("Circle", { name: "Circle", fields: [], methods: Map::new() })
  ctx.struct_defs.set("Rectangle", { name: "Rectangle", fields: [], methods: Map::new() })
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
