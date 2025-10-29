///|
pub suberror TokenizeError String derive(Show)

///|
pub(all) enum Keyword {
  Fn
  Struct
  Let
  Mut
  If
  Else
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
  line : Int
  col : Int
  idx : Int
} derive(Show, Eq)

///|
pub fn Token::new(kind : TokenKind, line : Int, col : Int, idx : Int) -> Token {
  Token::{ kind, line, col, idx }
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
  let mut line = 1
  let mut col = 1
  let mut idx = 0
  loop code[:] {
    [] => {
      let tok = Token::new(EOF, line, col, idx)
      tokens.push(tok)
      break
    }
    [' ' | '\t' | '\r', .. rest] => {
      col += 1
      idx += 1
      continue rest
    }
    ['\n', .. rest] => {
      line += 1
      col = 1
      idx += 1
      continue rest
    }
    [.. "//", .. rest] =>
      continue loop rest {
          ['\n', .. rest_str] => {
            line += 1
            col = 1
            idx += 1
            break rest_str
          }
          [_, .. rest_str] => continue rest_str
          [] as rest_str => break rest_str
        }
    [.. "::", .. rest] => {
      let tok = Token::new(Symbol("::"), line, col, idx)
      tokens.push(tok)
      col += 2
      idx += 2
      continue rest
    }
    [.. "->", .. rest] => {
      let tok = Token::new(Symbol("->"), line, col, idx)
      tokens.push(tok)
      col += 2
      idx += 2
      continue rest
    }
    [.. "=>", .. rest] => {
      let tok = Token::new(Symbol("=>"), line, col, idx)
      tokens.push(tok)
      col += 2
      idx += 2
      continue rest
    }
    [.. "!=", .. rest] => {
      let tok = Token::new(BinaryOp(NE), line, col, idx)
      tokens.push(tok)
      col += 2
      idx += 2
      continue rest
    }
    [.. "==", .. rest] => {
      let tok = Token::new(BinaryOp(Eq), line, col, idx)
      tokens.push(tok)
      col += 2
      idx += 2
      continue rest
    }
    [.. "<=", .. rest] => {
      let tok = Token::new(BinaryOp(LE), line, col, idx)
      tokens.push(tok)
      col += 2
      idx += 2
      continue rest
    }
    [.. ">=", .. rest] => {
      let tok = Token::new(BinaryOp(GE), line, col, idx)
      tokens.push(tok)
      col += 2
      idx += 2
      continue rest
    }
    [.. "&&", .. rest] => {
      let tok = Token::new(BinaryOp(And), line, col, idx)
      tokens.push(tok)
      col += 2
      idx += 2
      continue rest
    }
    [.. "||", .. rest] => {
      let tok = Token::new(BinaryOp(Or), line, col, idx)
      tokens.push(tok)
      col += 2
      idx += 2
      continue rest
    }
    [.. "<<", .. rest] => {
      let tok = Token::new(BinaryOp(ShiftLeft), line, col, idx)
      tokens.push(tok)
      col += 2
      idx += 2
      continue rest
    }
    [.. ">>", .. rest] => {
      let tok = Token::new(BinaryOp(ShiftRight), line, col, idx)
      tokens.push(tok)
      col += 2
      idx += 2
      continue rest
    }
    [.. "+=", .. rest] => {
      let tok = Token::new(AssignOp(PlusAssign), line, col, idx)
      tokens.push(tok)
      col += 2
      idx += 2
      continue rest
    }
    [.. "-=", .. rest] => {
      let tok = Token::new(AssignOp(MinusAssign), line, col, idx)
      tokens.push(tok)
      col += 2
      idx += 2
      continue rest
    }
    [.. "*=", .. rest] => {
      let tok = Token::new(AssignOp(MultAssign), line, col, idx)
      tokens.push(tok)
      col += 2
      idx += 2
      continue rest
    }
    [.. "/=", .. rest] => {
      let tok = Token::new(AssignOp(DivAssign), line, col, idx)
      tokens.push(tok)
      col += 2
      idx += 2
      continue rest
    }
    [.. "%=", .. rest] => {
      let tok = Token::new(AssignOp(ModAssign), line, col, idx)
      tokens.push(tok)
      col += 2
      idx += 2
      continue rest
    }
    ['+', .. rest] => {
      let tok = Token::new(BinaryOp(Add), line, col, idx)
      tokens.push(tok)
      col += 1
      idx += 1
      continue rest
    }
    ['-', .. rest] => {
      let tok = Token::new(BinaryOp(Sub), line, col, idx)
      tokens.push(tok)
      col += 1
      idx += 1
      continue rest
    }
    ['*', .. rest] => {
      let tok = Token::new(BinaryOp(Mul), line, col, idx)
      tokens.push(tok)
      col += 1
      idx += 1
      continue rest
    }
    ['/', .. rest] => {
      let tok = Token::new(BinaryOp(Div), line, col, idx)
      tokens.push(tok)
      col += 1
      idx += 1
      continue rest
    }
    ['%', .. rest] => {
      let tok = Token::new(BinaryOp(Mod), line, col, idx)
      tokens.push(tok)
      col += 1
      idx += 1
      continue rest
    }
    ['&', .. rest] => {
      let tok = Token::new(BinaryOp(BitAnd), line, col, idx)
      tokens.push(tok)
      col += 1
      idx += 1
      continue rest
    }
    ['|', .. rest] => {
      let tok = Token::new(BinaryOp(BitOr), line, col, idx)
      tokens.push(tok)
      col += 1
      idx += 1
      continue rest
    }
    ['<', .. rest] => {
      let tok = Token::new(BinaryOp(LT), line, col, idx)
      tokens.push(tok)
      col += 1
      idx += 1
      continue rest
    }
    ['>', .. rest] => {
      let tok = Token::new(BinaryOp(GT), line, col, idx)
      tokens.push(tok)
      col += 1
      idx += 1
      continue rest
    }
    ['=', .. rest] => {
      let tok = Token::new(AssignOp(Assign), line, col, idx)
      tokens.push(tok)
      col += 1
      idx += 1
      continue rest
    }
    ['!', .. rest] => {
      let tok = Token::new(Not, line, col, idx)
      tokens.push(tok)
      col += 1
      idx += 1
      continue rest
    }
    ['(', .. rest] => {
      let tok = Token::new(Bracket('('), line, col, idx)
      tokens.push(tok)
      col += 1
      idx += 1
      continue rest
    }
    [')', .. rest] => {
      let tok = Token::new(Bracket(')'), line, col, idx)
      tokens.push(tok)
      col += 1
      idx += 1
      continue rest
    }
    ['[', .. rest] => {
      let tok = Token::new(Bracket('['), line, col, idx)
      tokens.push(tok)
      col += 1
      idx += 1
      continue rest
    }
    [']', .. rest] => {
      let tok = Token::new(Bracket(']'), line, col, idx)
      tokens.push(tok)
      col += 1
      idx += 1
      continue rest
    }
    ['{', .. rest] => {
      let tok = Token::new(Bracket('{'), line, col, idx)
      tokens.push(tok)
      col += 1
      idx += 1
      continue rest
    }
    ['}', .. rest] => {
      let tok = Token::new(Bracket('}'), line, col, idx)
      tokens.push(tok)
      col += 1
      idx += 1
      continue rest
    }
    ['.', .. rest] => {
      let tok = Token::new(Symbol("."), line, col, idx)
      tokens.push(tok)
      col += 1
      idx += 1
      continue rest
    }
    [',', .. rest] => {
      let tok = Token::new(Symbol(","), line, col, idx)
      tokens.push(tok)
      col += 1
      idx += 1
      continue rest
    }
    [':', .. rest] => {
      let tok = Token::new(Symbol(":"), line, col, idx)
      tokens.push(tok)
      col += 1
      idx += 1
      continue rest
    }
    [';', .. rest] => {
      let tok = Token::new(Symbol(";"), line, col, idx)
      tokens.push(tok)
      col += 1
      idx += 1
      continue rest
    }
    ['\"', ..] as code => {
      let (tok_kind, len, rest) = tokenize_string(code)
      let tok = Token::new(tok_kind, line, col, idx)
      tokens.push(tok)
      col += len
      idx += len
      continue rest
    }
    ['A'..='Z', ..] as code => {
      let sb = StringBuilder::new()
      let rest = loop code {
        ['A'..='Z' | 'a'..='z' | '0'..='9' | '_' as c, .. rest] => {
          sb.write_char(c)
          col += 1
          idx += 1
          continue rest
        }
        rest => break rest
      }
      let ident = sb.to_string()
      let tok = Token::new(Upper(ident), line, col, idx)
      tokens.push(tok)
      continue rest
    }
    ['_' | 'a'..='z', ..] as code => {
      let (ident, len, rest) = tokenize_lower_ident(code)
      col += len
      idx += len
      let tok = Token::new(ident, line, col, idx)
      tokens.push(tok)
      continue rest
    }
    ['0'..='9', ..] as code => {
      let (tok_kind, len, rest) = tokenize_number(code)
      let tok = Token::new(tok_kind, line, col, idx)
      tokens.push(tok)
      col += len
      idx += len
      continue rest
    }
    other_strs =>
      raise TokenizeError("Tokenize Error: Unexpected char: \{other_strs}")
  }
  tokens
}

///|
fn tokenize_lower_ident(code : StringView) -> (TokenKind, Int, StringView) {
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
    "let" => Keyword(Let)
    "mut" => Keyword(Mut)
    "if" => Keyword(If)
    "else" => Keyword(Else)
    "while" => Keyword(While)
    "for" => Keyword(For)
    "return" => Keyword(Return)
    "extern" => Keyword(Extern)
    "true" => Bool(true)
    "false" => Bool(false)
    "_" => Wildcard
    _ => Lower(ident)
  }
  (kind, ident.length(), rest)
}

///|
///
fn tokenize_number(
  code : StringView,
) -> (TokenKind, Int, StringView) raise TokenizeError {
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
  (kind, num_str.length(), rest)
}

///|
fn tokenize_string(
  code : StringView,
) -> (TokenKind, Int, StringView) raise TokenizeError {
  guard code is ['\"', .. code] else {
    println("Compiler ICE: Tokenize String Error")
    panic()
  }
  let sb = StringBuilder::new()
  let rest = loop code {
    ['\"', .. rest] => break rest
    [c, .. rest] => {
      sb.write_char(c)
      continue rest
    }
    [] => raise TokenizeError("Tokenize Error: Unterminated string literal")
  }
  let str_val = sb.to_string()
  // + 2 for the surrounding quotes
  (String(str_val), str_val.length() + 2, rest)
}
