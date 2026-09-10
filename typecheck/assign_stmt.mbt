///|
pub(all) struct LeftValue {
  kind : LeftValueKind
  ty : Type
}

///|
pub impl Show for LeftValue with fn output(self, logger) {
  let s = self.to_string(color=true)
  logger.write_string(s)
}

///|
pub fn LeftValue::to_string(self : Self, color? : Bool = true) -> String {
  match self.kind {
    Ident(name) => {
      let prefix = "lvalue"
      let prefix = if color { @color.taint(prefix, Magenta) } else { prefix }
      let ty_str = self.ty.to_string()
      let ty_str = if color { @color.taint(ty_str, Green) } else { ty_str }
      "\{prefix} \{name} (\{ty_str})"
    }
    ArrayAccess(left_value, index_expr) => {
      let prefix = "lvalue array access"
      let prefix = if color { @color.taint(prefix, Magenta) } else { prefix }
      let ty_str = self.ty.to_string()
      let ty_str = if color { @color.taint(ty_str, Green) } else { ty_str }
      let prefix_with_type = "\{prefix} (\{ty_str})"
      let lvalue_str = left_value.to_string(color~)
      let lvalue_lines = lvalue_str
        .split("\n")
        .map(fn(sv) { sv.to_owned() })
        .to_array()
      let lvalue_formatted = @parser.format_lines(
        lvalue_lines,
        head_with="├-",
        continue_with="│ ",
      )
      let index_str = index_expr.to_string(color~)
      let index_lines = index_str
        .split("\n")
        .map(fn(sv) { sv.to_owned() })
        .to_array()
      let index_formatted = @parser.format_lines(
        index_lines,
        head_with="└-",
        continue_with="  ",
      )
      "\{prefix_with_type}\n\{lvalue_formatted}\n\{index_formatted}"
    }
    FieldAccess(left_value, field) => {
      let prefix = "lvalue field access"
      let prefix = if color { @color.taint(prefix, Magenta) } else { prefix }
      let ty_str = self.ty.to_string()
      let ty_str = if color { @color.taint(ty_str, Green) } else { ty_str }
      let prefix_with_type = "\{prefix} .\{field} (\{ty_str})"
      let inner_str = left_value.to_string(color~)
      let lines = inner_str.split("\n").map(fn(sv) { sv.to_owned() }).to_array()
      let formatted = @parser.format_lines(lines)
      "\{prefix_with_type}\n\{formatted}"
    }
  }
}

///|
pub(all) enum LeftValueKind {
  Ident(String)
  ArrayAccess(LeftValue, Expr)
  FieldAccess(LeftValue, String)
}

///|
pub(all) struct AssignStmt {
  left_value : LeftValue
  op : AssignOp
  expr : Expr
}

///|
pub impl Show for AssignStmt with fn output(self, logger) {
  let s = self.to_string(color=true)
  logger.write_string(s)
}

///|
pub fn AssignStmt::to_string(self : Self, color? : Bool = true) -> String {
  let op_str = match self.op {
    Assign => "="
    PlusAssign => "+="
    MinusAssign => "-="
    MultAssign => "*="
    DivAssign => "/="
    ModAssign => "%="
  }
  let prefix = "assign statement: \{op_str}"
  let prefix = if color { @color.taint(prefix, Magenta) } else { prefix }

  // Format left value
  let lvalue_str = self.left_value.to_string(color~)
  let lvalue_lines = lvalue_str
    .split("\n")
    .map(fn(sv) { sv.to_owned() })
    .to_array()
  let lvalue_formatted = @parser.format_lines(
    lvalue_lines,
    head_with="├-lvalue: ",
    continue_with="│         ",
  )

  // Format expression
  let expr_str = self.expr.to_string(color~)
  let expr_lines = expr_str.split("\n").map(fn(sv) { sv.to_owned() }).to_array()
  let expr_formatted = @parser.format_lines(
    expr_lines,
    head_with="└-expr: ",
    continue_with="        ",
  )
  "\{prefix}\n\{lvalue_formatted}\n\{expr_formatted}"
}

///|
pub(all) enum AssignOp {
  Assign // =
  PlusAssign // +=
  MinusAssign // -=
  MultAssign // *=
  DivAssign // /=
  ModAssign // %=
} derive(Eq)

///|
fn AssignOp::from_parser_assign_op(op : @parser.AssignOp) -> AssignOp {
  match op {
    Assign => Assign
    PlusAssign => PlusAssign
    MinusAssign => MinusAssign
    MultAssign => MultAssign
    DivAssign => DivAssign
    ModAssign => ModAssign
  }
}

///|
pub fn Context::check_left_value(
  self : Context,
  left_value : @parser.LeftValue,
) -> LeftValue raise TypeCheckError {
  match left_value.kind {
    Ident(name) => {
      guard self.type_env.get(name) is Some(ty) else {
        raise TypeCheckError("Undefined variable: \{name}")
      }
      LeftValue::{ kind: LeftValueKind::Ident(name), ty, }
    }
    ArrayAccess(array_lv, index_expr) => {
      let checked_array_lv = self.check_left_value(array_lv)
      let checked_index_expr = self.check_expr(index_expr)

      // Ensure the array left value is of array type
      match checked_array_lv.ty.kind {
        Array(element_type) => {
          // Ensure the index expression is of integer type
          if !(checked_index_expr.ty is Int) {
            raise TypeCheckError("Array index must be of type Int")
          }
          LeftValue::{
            kind: LeftValueKind::ArrayAccess(
              checked_array_lv, checked_index_expr,
            ),
            ty: Type::{ kind: element_type, mutable: true, },
          }
        }
        _ => raise TypeCheckError("Attempted to index a non-array type")
      }
    }
    FieldAccess(struct_lv, field_name) => {
      let checked_struct_lv = self.check_left_value(struct_lv)
      guard checked_struct_lv.ty.kind is Struct(struct_type_name) else {
        raise TypeCheckError("Attempted to access field of a non-struct type")
      }
      guard self.struct_defs.get(struct_type_name) is Some(struct_def) else {
        raise TypeCheckError("Undefined struct type: \{struct_type_name}")
      }
      let ty = for field in struct_def.fields {
        if field.name == field_name {
          break field.ty
        }
      } nobreak {
        raise TypeCheckError(
          "Struct \{struct_type_name} has no field named \{field_name}",
        )
      }
      LeftValue::{
        kind: LeftValueKind::FieldAccess(checked_struct_lv, field_name),
        ty,
      }
    }
  }
}

///|
pub fn Context::check_assign_stmt(
  self : Context,
  assign_stmt : @parser.AssignStmt,
) -> AssignStmt raise TypeCheckError {
  let checked_left_value = self.check_left_value(assign_stmt.left_value)
  guard checked_left_value.ty.mutable is true else {
    raise TypeCheckError("Cannot assign to an immutable left value")
  }
  let checked_expr = self.check_expr(assign_stmt.expr)
  guard self.is_type_compatible(checked_left_value.ty.kind, checked_expr.ty) else {
    raise TypeCheckError(
      "Type mismatch in assignment, left value type: \{checked_left_value.ty.kind}, expression type: \{checked_expr.ty}",
    )
  }
  let op = AssignOp::from_parser_assign_op(assign_stmt.op)
  let ty = self.ensure_type(checked_left_value.ty.kind)
  if !(op is Assign) && !(ty is (Int | Double)) {
    raise TypeCheckError(
      "Compound assignment operators can only be used with Int or Double types",
    )
  }
  AssignStmt::{ left_value: checked_left_value, op, expr: checked_expr, }
}

///|
test "AssignStmt to_string Test - Basic" {
  let color = false
  let ctx = Context::new()
  ctx.type_env.set("x", { kind: TypeKind::Int, mutable: true, })

  // Test simple assign: x = 42
  let code1 = "x = 42 ;"
  let tokens1 = @lexer.tokenize(code1)
  let (stmt, _) = @parser.parse_stmt(tokens1[:])
  let checked = ctx.check_stmt(stmt)
  inspect(
    checked.to_string(color~),
    content=(
      #|assign statement: =
      #|├-lvalue: lvalue x (Int)
      #|└-expr: int literal 42 (Int)
    ),
  )

  // Test += operator: x += 42
  let code2 = "x += 42 ;"
  let tokens2 = @lexer.tokenize(code2)
  let (stmt, _) = @parser.parse_stmt(tokens2[:])
  let checked = ctx.check_stmt(stmt)
  inspect(
    checked.to_string(color~),
    content=(
      #|assign statement: +=
      #|├-lvalue: lvalue x (Int)
      #|└-expr: int literal 42 (Int)
    ),
  )
}

///|
test "AssignStmt to_string Test - Complex" {
  let color = false
  let ctx = Context::new()
  ctx.type_env.set("arr", {
    kind: TypeKind::Array(TypeKind::Int),
    mutable: true,
  })
  ctx.type_env.set("point", { kind: TypeKind::Struct("Point"), mutable: true, })
  ctx.struct_defs.set("Point", {
    name: "Point",
    fields: [
      { name: "x", ty: { kind: TypeKind::Int, mutable: true, }, },
      { name: "y", ty: { kind: TypeKind::Int, mutable: true, }, },
    ],
    methods: Map([]),
  })

  // Test array access: arr[0] = 10
  let code1 = "arr[0] = 10 ;"
  let tokens1 = @lexer.tokenize(code1)
  let (stmt, _) = @parser.parse_stmt(tokens1[:])
  let checked = ctx.check_stmt(stmt)
  inspect(
    checked.to_string(color~),
    content=(
      #|assign statement: =
      #|├-lvalue: lvalue array access (Int)
      #|│         ├-lvalue arr (Array[Int])
      #|│         └-int literal 0 (Int)
      #|└-expr: int literal 10 (Int)
    ),
  )

  // Test field access: point.x = 20
  let code2 = "point.x = 20 ;"
  let tokens2 = @lexer.tokenize(code2)
  let (stmt, _) = @parser.parse_stmt(tokens2[:])
  let checked = ctx.check_stmt(stmt)
  inspect(
    checked.to_string(color~),
    content=(
      #|assign statement: =
      #|├-lvalue: lvalue field access .x (Int)
      #|│         └-lvalue point (Point)
      #|└-expr: int literal 20 (Int)
    ),
  )
}

///|
pub extend LeftValue with Show::{output}

///|
pub extend LeftValueKind with Show::{to_string, output}

///|
pub extend AssignStmt with Show::{output}

///|
pub extend AssignOp with Show::{to_string, output}

///|
pub extend AssignOp with Eq::{not_equal, equal}

///|
pub impl Show for LeftValueKind with fn output(self, logger) {
  match self {
    Ident(v0) => {
      logger.write_string("Ident(")
      logger.write_string(v0.escape())
      logger.write_string(")")
    }
    ArrayAccess(v0, v1) => {
      logger.write_string("ArrayAccess(")
      logger.write_object(v0)
      logger.write_string(", ")
      logger.write_object(v1)
      logger.write_string(")")
    }
    FieldAccess(v0, v1) => {
      logger.write_string("FieldAccess(")
      logger.write_object(v0)
      logger.write_string(", ")
      logger.write_string(v1.escape())
      logger.write_string(")")
    }
  }
}

///|
pub impl Show for AssignOp with fn output(self, logger) {
  match self {
    Assign => logger.write_string("Assign")
    PlusAssign => logger.write_string("PlusAssign")
    MinusAssign => logger.write_string("MinusAssign")
    MultAssign => logger.write_string("MultAssign")
    DivAssign => logger.write_string("DivAssign")
    ModAssign => logger.write_string("ModAssign")
  }
}
