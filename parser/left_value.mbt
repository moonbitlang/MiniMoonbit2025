///|
pub(all) struct LeftValue {
  kind : LeftValueKind
} derive(Show, Eq)

///|
pub(all) enum LeftValueKind {
  Ident(String)
  ArrayAccess(LeftValue, Expr)
  FieldAccess(LeftValue, String)
} derive(Show, Eq)

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
    [{ kind: Bracket('['), ..  }, .. tokens] => {
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
