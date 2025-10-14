///|
pub suberror TokenizeError String derive(Show)

///|
pub(all) enum Keyword {
  Fn
  Struct
  Enum
  Let
  Mut
  If
  Else
  Match
  While
  For
  Return
  Extern
} derive(Show, Eq)

///|
pub(all) enum BinaryOp {
  Add // +
  Sub // -
  Mul // *
  Div // /
  Mod // %
  ShiftLeft // <<
  ShiftRight // >>
  Eq // ==
  NE // !=
  LT // <
  GT // >
  LE // <=
  GE // >=
  And // &&
  Or // ||
  BitAnd // &
  BitOr // |
} derive(Eq)

///|
pub impl Show for BinaryOp with output(self, logger) {
  let s = match self {
    Add => "+"
    Sub => "-"
    Mul => "*"
    Div => "/"
    Mod => "%"
    ShiftLeft => "<<"
    ShiftRight => ">>"
    Eq => "=="
    NE => "!="
    LT => "<"
    GT => ">"
    LE => "<="
    GE => ">="
    And => "&&"
    Or => "||"
    BitAnd => "&"
    BitOr => "|"
  }
  logger.write_string(s)
}

///|
pub(all) enum AssignOp {
  Assign // =
  PlusAssign // +=
  MinusAssign // -=
  MultAssign // *=
  DivAssign // /=
  ModAssign // %=
} derive(Show, Eq, ToJson)

///|
pub struct Token {
  kind : TokenKind
  // other info
} derive(Show, Eq)

///|
pub fn Token::new(kind : TokenKind) -> Token {
  Token::{ kind, }
}

///|
pub(all) enum TokenKind {
  Bool(Bool) // true, false
  Int(Int) // 1, 42, -100
  Double(Double)
  String(String) // "hello", "world"
  Keyword(Keyword)
  Upper(String)
  Lower(String)
  BinaryOp(BinaryOp) // +, -, *, /, %, =, ==, !=, <, >, <=, >=, &&, ||
  AssignOp(AssignOp) // =, +=, -=, *=, /=, %=
  Not // !
  Bracket(Char) // (, ), [, ], {, }
  Symbol(String) // . , ; : :: -> => 
  Wildcard // _
  EOF
} derive(Show, Eq)

///|
pub fn tokenize(code : String) -> Array[Token] raise TokenizeError {
  let tokens = Array::new()
  tokens.clear()
  loop code[:] {
    [] => {
      let tok = Token::new(EOF)
      tokens.push(tok)
      break
    }
    [' ' | '\t' | '\r', .. rest] => continue rest
    ['\n', .. rest] => continue rest
    [.. "//", .. rest] =>
      continue loop rest {
          ['\n', .. rest_str] => break rest_str
          [_, .. rest_str] => continue rest_str
          [] as rest_str => break rest_str
        }
    [.. "::", .. rest] => {
      let tok = Token::new(Symbol(":"))
      tokens.push(tok)
      continue rest
    }
    [.. "->", .. rest] => {
      let tok = Token::new(Symbol("->"))
      tokens.push(tok)
      continue rest
    }
    [.. "=>", .. rest] => {
      let tok = Token::new(Symbol("=>"))
      tokens.push(tok)
      continue rest
    }
    [.. "!=", .. rest] => {
      let tok = Token::new(BinaryOp(NE))
      tokens.push(tok)
      continue rest
    }
    [.. "==", .. rest] => {
      let tok = Token::new(BinaryOp(Eq))
      tokens.push(tok)
      continue rest
    }
    [.. "<=", .. rest] => {
      let tok = Token::new(BinaryOp(LE))
      tokens.push(tok)
      continue rest
    }
    [.. ">=", .. rest] => {
      let tok = Token::new(BinaryOp(GE))
      tokens.push(tok)
      continue rest
    }
    [.. "&&", .. rest] => {
      let tok = Token::new(BinaryOp(And))
      tokens.push(tok)
      continue rest
    }
    [.. "||", .. rest] => {
      let tok = Token::new(BinaryOp(Or))
      tokens.push(tok)
      continue rest
    }
    [.. "<<", .. rest] => {
      let tok = Token::new(BinaryOp(ShiftLeft))
      tokens.push(tok)
      continue rest
    }
    [.. ">>", .. rest] => {
      let tok = Token::new(BinaryOp(ShiftRight))
      tokens.push(tok)
      continue rest
    }
    [.. "+=", .. rest] => {
      let tok = Token::new(AssignOp(PlusAssign))
      tokens.push(tok)
      continue rest
    }
    [.. "-=", .. rest] => {
      let tok = Token::new(AssignOp(MinusAssign))
      tokens.push(tok)
      continue rest
    }
    [.. "*=", .. rest] => {
      let tok = Token::new(AssignOp(MultAssign))
      tokens.push(tok)
      continue rest
    }
    [.. "/=", .. rest] => {
      let tok = Token::new(AssignOp(DivAssign))
      tokens.push(tok)
      continue rest
    }
    [.. "%=", .. rest] => {
      let tok = Token::new(AssignOp(ModAssign))
      tokens.push(tok)
      continue rest
    }
    ['+', .. rest] => {
      let tok = Token::new(BinaryOp(Add))
      tokens.push(tok)
      continue rest
    }
    ['-', .. rest] => {
      let tok = Token::new(BinaryOp(Sub))
      tokens.push(tok)
      continue rest
    }
    ['*', .. rest] => {
      let tok = Token::new(BinaryOp(Mul))
      tokens.push(tok)
      continue rest
    }
    ['/', .. rest] => {
      let tok = Token::new(BinaryOp(Div))
      tokens.push(tok)
      continue rest
    }
    ['%', .. rest] => {
      let tok = Token::new(BinaryOp(Mod))
      tokens.push(tok)
      continue rest
    }
    ['&', .. rest] => {
      let tok = Token::new(BinaryOp(BitAnd))
      tokens.push(tok)
      continue rest
    }
    ['|', .. rest] => {
      let tok = Token::new(BinaryOp(BitOr))
      tokens.push(tok)
      continue rest
    }
    ['<', .. rest] => {
      let tok = Token::new(BinaryOp(LT))
      tokens.push(tok)
      continue rest
    }
    ['>', .. rest] => {
      let tok = Token::new(BinaryOp(GT))
      tokens.push(tok)
      continue rest
    }
    ['=', .. rest] => {
      let tok = Token::new(AssignOp(Assign))
      tokens.push(tok)
      continue rest
    }
    ['!', .. rest] => {
      let tok = Token::new(Not)
      tokens.push(tok)
      continue rest
    }
    ['(', .. rest] => {
      let tok = Token::new(Bracket('('))
      tokens.push(tok)
      continue rest
    }
    [')', .. rest] => {
      let tok = Token::new(Bracket(')'))
      tokens.push(tok)
      continue rest
    }
    ['[', .. rest] => {
      let tok = Token::new(Bracket('['))
      tokens.push(tok)
      continue rest
    }
    [']', .. rest] => {
      let tok = Token::new(Bracket(']'))
      tokens.push(tok)
      continue rest
    }
    ['{', .. rest] => {
      let tok = Token::new(Bracket('{'))
      tokens.push(tok)
      continue rest
    }
    ['}', .. rest] => {
      let tok = Token::new(Bracket('}'))
      tokens.push(tok)
      continue rest
    }
    ['.', .. rest] => {
      let tok = Token::new(Symbol("."))
      tokens.push(tok)
      continue rest
    }
    [',', .. rest] => {
      let tok = Token::new(Symbol(","))
      tokens.push(tok)
      continue rest
    }
    [':', .. rest] => {
      let tok = Token::new(Symbol(":"))
      tokens.push(tok)
      continue rest
    }
    [';', .. rest] => {
      let tok = Token::new(Symbol(";"))
      tokens.push(tok)
      continue rest
    }
    ['A'..='Z', ..] as code => {
      let sb = StringBuilder::new()
      let rest = loop code {
        ['A'..='Z' | 'a'..='z' | '0'..='9' | '_' as c, .. rest] => {
          sb.write_char(c)
          continue rest
        }
        rest => break rest
      }
      let ident = sb.to_string()
      let tok = Token::new(Upper(ident))
      tokens.push(tok)
      continue rest
    }
    ['_' | 'a'..='z', ..] as code => {
      let (ident, rest) = tokenize_lower_ident(code)
      let tok = Token::new(ident)
      tokens.push(tok)
      continue rest
    }
    ['0'..='9', ..] as code => {
      let (tok, rest) = tokenize_number(code)
      tokens.push(tok)
      continue rest
    }
    other_strs =>
      raise TokenizeError("Tokenize Error: Unexpected char: \{other_strs}")
  }
  tokens
}

///|
fn tokenize_lower_ident(code : StringView) -> (TokenKind, StringView) {
  let sb = StringBuilder::new()
  let rest = loop code {
    ['a'..='z' | 'A'..='Z' | '0'..='9' | '_' as c, .. rest] => {
      sb.write_char(c)
      continue rest
    }
    rest => break rest
  }
  let ident = sb.to_string()
  let kind = match ident {
    "fn" => Keyword(Fn)
    "struct" => Keyword(Struct)
    "enum" => Keyword(Enum)
    "let" => Keyword(Let)
    "mut" => Keyword(Mut)
    "if" => Keyword(If)
    "else" => Keyword(Else)
    "match" => Keyword(Match)
    "while" => Keyword(While)
    "for" => Keyword(For)
    "return" => Keyword(Return)
    "true" => Bool(true)
    "false" => Bool(false)
    "extern" => Keyword(Extern)
    "_" => Wildcard
    _ => Lower(ident)
  }
  (kind, rest)
}

///|
///
/// Handle Int64, UInt, UInt64, Float, Double
/// Support:
///
/// 1. normal integer: 42 1577
/// 2. hex integer: 0x1A 0xFF
/// 3. binary integer: 0b1010 0b1101
/// 4. integer with suffix: 42L, 100u (allowed: u, U, l, L, ul, uL, Ul, UL)
/// 5. float: 3.14, 2.71f (allowed suffix: f, F)
fn tokenize_number(
  code : StringView,
) -> (Token, StringView) raise TokenizeError {
  let sb = StringBuilder::new()
  let mut is_float = false

  // Parse the numeric part
  let rest = loop code {
    ['0'..='9' as c, .. rest] => {
      sb.write_char(c)
      continue rest
    }
    rest => break rest
  }
  // Check for decimal point (float)
  let rest = match rest {
    ['.', '0'..='9', ..] as dot_rest => {
      is_float = true
      sb.write_char('.')
      let rest_after_dot = match dot_rest {
        ['.', .. rest] => rest
        _ => panic()
      }
      // Parse fractional part
      loop rest_after_dot {
        ['0'..='9' as c, .. rest] => {
          sb.write_char(c)
          continue rest
        }
        rest => break rest
      }
    }
    _ => rest
  }
  let num_str = sb.to_string()
  let (kind, rest) = if is_float {
    let value = @strconv.parse_double(num_str) catch {
      _ => raise TokenizeError("Invalid Float literal: \{num_str}")
    }
    (TokenKind::Double(value), rest)
  } else {
    let value = @strconv.parse_int(num_str) catch {
      _ => raise TokenizeError("Invalid Int literal: \{num_str}")
    }
    (TokenKind::Int(value), rest)
  }
  (Token::new(kind), rest)
}
