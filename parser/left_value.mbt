///|
pub(all) struct LeftValue {
  kind : LeftValueKind
} derive(Eq)

///|
pub impl Show for LeftValue with output(self, logger) {
  let s = self.to_string(color=true)
  logger.write_string(s)
}

///|
pub fn LeftValue::to_string(self : Self, color? : Bool = true) -> String {
  match self.kind {
    Ident(name) => {
      let prefix = "lvalue"
      let prefix = if color { @color.taint(prefix, Magenta) } else { prefix }
      "\{prefix} \{name}"
    }
    ArrayAccess(left_value, _index_expr) => {
      let prefix = "lvalue array access"
      let prefix = if color { @color.taint(prefix, Magenta) } else { prefix }
      let inner_str = left_value.to_string(color~)
      let lines = inner_str
        .split("\n")
        .map(fn(sv) { sv.to_string() })
        .to_array()
      let formatted = format_lines(lines)
      "\{prefix} [...]\n\{formatted}"
    }
    FieldAccess(left_value, field) => {
      let prefix = "lvalue field access"
      let prefix = if color { @color.taint(prefix, Magenta) } else { prefix }
      let inner_str = left_value.to_string(color~)
      let lines = inner_str
        .split("\n")
        .map(fn(sv) { sv.to_string() })
        .to_array()
      let formatted = format_lines(lines)
      "\{prefix} .\{field}\n\{formatted}"
    }
  }
}

///|
pub(all) enum LeftValueKind {
  Ident(String)
  ArrayAccess(LeftValue, Expr)
  FieldAccess(LeftValue, String)
} derive(Eq)

///|
pub impl Show for LeftValueKind with output(self, logger) {
  let s = match self {
    Ident(name) => "\{name}"
    ArrayAccess(left_value, _) => "\{left_value}[...]"
    FieldAccess(left_value, field) => "\{left_value}.\{field}"
  }
  logger.write_string(s)
}

///|
pub fn parse_left_value(
  tokens : ArrayView[Token],
) -> (LeftValue, ArrayView[Token]) raise ParseError {
  guard tokens is [{ kind: Lower(ident), .. }, .. tokens] else {
    raise ParseError("Expect a lower ident")
  }
  let left_value = LeftValue::{ kind: LeftValueKind::Ident(ident) }
  if !(tokens is [{ kind: Bracket('[') | Symbol("."), .. }, ..]) {
    return (left_value, tokens)
  }
  let mut left_value = left_value
  loop tokens {
    [{ kind: Bracket('['), .. }, .. tokens] => {
      let (index_expr, tokens) = parse_expr(tokens)
      guard tokens is [{ kind: Bracket(']'), .. }, .. tokens] else {
        raise ParseError("Expect ']'")
      }
      left_value = LeftValue::{
        kind: LeftValueKind::ArrayAccess(left_value, index_expr),
      }
      continue tokens
    }
    [{ kind: Symbol("."), .. }, { kind: Lower(field), .. }, .. tokens] => {
      left_value = LeftValue::{
        kind: LeftValueKind::FieldAccess(left_value, field),
      }
      continue tokens
    }
    tokens => break (left_value, tokens)
  }
}

///|
test "LeftValue to_string Test - Basic" {
  let color = false
  let code =
    #|x ; arr[0] ; point.x
  let tokens = @lexer.tokenize(code, source_file="test")

  // Parse `x` (Ident)
  let (left_value, rest) = parse_left_value(tokens)
  inspect(left_value.to_string(color~), content="lvalue x")

  // Skip semicolon and parse `arr[0]` (ArrayAccess)
  let rest = skip_semicolon(rest)
  let (left_value, rest) = parse_left_value(rest)
  inspect(
    left_value.to_string(color~),
    content=(
      #|lvalue array access [...]
      #|└-lvalue arr
    ),
  )

  // Skip semicolon and parse `point.x` (FieldAccess)
  let rest = skip_semicolon(rest)
  let (left_value, _) = parse_left_value(rest)
  inspect(
    left_value.to_string(color~),
    content=(
      #|lvalue field access .x
      #|└-lvalue point
    ),
  )
}

///|
test "LeftValue to_string Test - Nested" {
  let color = false
  let code =
    #|arr[0][1] ; point.field.x ; matrix[i].data
  let tokens = @lexer.tokenize(code, source_file="test")

  // Parse `arr[0][1]` (Nested ArrayAccess)
  let (left_value, rest) = parse_left_value(tokens)
  inspect(
    left_value.to_string(color~),
    content=(
      #|lvalue array access [...]
      #|└-lvalue array access [...]
      #|  └-lvalue arr
    ),
  )

  // Skip semicolon and parse `point.field.x` (Nested FieldAccess)
  let rest = skip_semicolon(rest)
  let (left_value, rest) = parse_left_value(rest)
  inspect(
    left_value.to_string(color~),
    content=(
      #|lvalue field access .x
      #|└-lvalue field access .field
      #|  └-lvalue point
    ),
  )

  // Skip semicolon and parse `matrix[i].data` (Mixed access)
  let rest = skip_semicolon(rest)
  let (left_value, _) = parse_left_value(rest)
  inspect(
    left_value.to_string(color~),
    content=(
      #|lvalue field access .data
      #|└-lvalue array access [...]
      #|  └-lvalue matrix
    ),
  )
}
