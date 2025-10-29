///|
pub(all) struct Pattern {
  kind : PatternKind
} derive(Show, Eq)

///|
pub(all) enum PatternKind {
  Wildcard
  Ident(String)
  Tuple(Array[Pattern])
} derive(Show, Eq)

///|
pub fn parse_pattern(
  tokens : ArrayView[Token],
) -> (Pattern, ArrayView[Token]) raise ParseError {
  match tokens {
    [{ kind: Wildcard, ..  }, .. tokens] => {
      let pattern = Pattern::{ kind: Wildcard }
      (pattern, tokens)
    }
    [{ kind: Lower(ident), ..  }, .. tokens] => {
      let pattern = Pattern::{ kind: Ident(ident) }
      (pattern, tokens)
    }
    [{ kind: Bracket('('), ..  }, .. tokens] => {
      let patterns : Array[Pattern] = Array::new()
      let tokens = loop tokens {
        [{ kind: Bracket(')'), ..  }, .. tokens] => break tokens
        [{ kind: Lower(_) | Wildcard | Bracket('('), ..  }, ..] as tokens => {
          let (pat, rest) = parse_pattern(tokens)
          patterns.push(pat)
          continue rest
        }
        [
          { kind: Symbol(","), ..  },
          { kind: Lower(_) | Wildcard | Bracket('(') | Bracket(')'), ..  },
          ..,
        ] as tokens => continue tokens[1:]
        [] => {
          println("Compiler ICE: Failed Parsing Pattern Empty Token ArrayView")
          panic()
        }
        tokens => raise ParseError("InValid Pattern: \{tokens[0]}")
      }
      let kind = if patterns.length() == 0 {
        raise ParseError("InValid Pattern")
      } else if patterns.length() == 1 {
        raise ParseError("InValid Pattern, must over 1 pattern for tuple")
      } else {
        PatternKind::Tuple(patterns)
      }
      let pattern = Pattern::{ kind, }
      (pattern, tokens)
    }
    [] => {
      println("Compiler ICE: Empty Token ArrayView")
      panic()
    }
    _ => raise ParseError("InValid Pattern")
  }
}
