///|
pub(all) struct ExternFunction {
  fname : String
  param_list : Array[Param]
  ret_ty : Type?
  ffi_name : String
} derive(Show, Eq)

///|
///
///extern_func := "extern" str "fn" lower "(" param_list ")" "->" type "=" ffi_name
///
/// str can `"C"`, `"Js"` ect
/// but actually, we just parse it as a string literal here, don't care about its content.
///
/// just because the original moonbit support that, we keep it.
pub fn parse_extern_function(
  tokens : ArrayView[Token],
) -> (ExternFunction, ArrayView[Token]) raise ParseError {
  guard tokens is [{ kind: Keyword(Extern), .. }, .. tokens] else {
    println("Compiler ICE: Misuse parse_extern_function")
    panic()
  }
  guard tokens is [{ kind: String(_), .. }, .. tokens] else {
    @lexer.throw_(tokens[0], "Expect a language string, \"c\", \"ss\", \"wasm\" ect", Error)
    raise ParseError("Expect a language string, \"c\", \"ss\", \"wasm\" ect")
  }
  guard tokens is [{ kind: Keyword(Fn), .. }, .. tokens] else {
    @lexer.throw_(tokens[0], "Expect 'fn'", Error)
    raise ParseError("Expect 'fn'")
  }
  guard tokens is [{ kind: Lower(fname), .. }, .. tokens] else {
    @lexer.throw_(tokens[0], "Expect a lower ident", Error)
    raise ParseError("Expect a lower ident")
  }
  guard tokens is [{ kind: Bracket('('), .. }, .. tokens] else {
    @lexer.throw_(tokens[0], "Expect '('", Error)
    raise ParseError("Expect '('")
  }
  let (param_list, tokens) = parse_param_list(tokens)
  guard tokens is [{ kind: Bracket(')'), .. }, .. tokens] else {
    @lexer.throw_(tokens[0], "Expect ')'", Error)
    raise ParseError("Expect ')'")
  }
  let (ret_ty, tokens) = if tokens
    is [{ kind: Symbol("->"), .. }, .. rest_tokens] {
    let (ret_ty, tokens) = parse_type(rest_tokens)
    (Some(ret_ty), tokens)
  } else {
    (None, tokens)
  }
  guard tokens is [{ kind: AssignOp(Assign), .. }, .. tokens] else {
    @lexer.throw_(tokens[0], "Expect '='", Error)
    raise ParseError("Expect '='")
  }
  guard tokens is [{ kind: String(ffi_name), line, .. }, .. tokens] else {
    @lexer.throw_(tokens[0], "Expect FFI name", Error)
    raise ParseError("Expect FFI name")
  }
  let tokens = if tokens is [{ kind: Symbol(";"), .. }, .. tokens] {
    tokens
  } else if tokens is [tok, ..] && tok.line != line {
    tokens
  } else if tokens is [{ kind: Bracket('}'), .. }, ..] {
    tokens
  } else {
    @lexer.throw_(tokens[0], "Parse Error: Expect ';' or '}' or newline after let statement", Error)
    raise ParseError("Expect ';' or '}' or newline after let statement")
  }
  let extern_function = ExternFunction::{ fname, param_list, ret_ty, ffi_name }
  (extern_function, tokens)
}
