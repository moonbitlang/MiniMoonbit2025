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
    raise ParseError("Expect a language string, \"c\", \"ss\", \"wasm\" ect")
  }
  guard tokens is [{ kind: Keyword(Fn), .. }, .. tokens] else {
    raise ParseError("Expect 'fn'")
  }
  guard tokens is [{ kind: Lower(fname), .. }, .. tokens] else {
    raise ParseError("Expect a lower ident")
  }
  guard tokens is [{ kind: Bracket('('), .. }, .. tokens] else {
    raise ParseError("Expect '('")
  }
  let (param_list, tokens) = parse_param_list(tokens)
  guard tokens is [{ kind: Bracket(')'), .. }, .. tokens] else {
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
    raise ParseError("Expect '='")
  }
  guard tokens is [{ kind: String(ffi_name), .. }, .. tokens] else {
    raise ParseError("Expect FFI name")
  }
  guard tokens is [{ kind: Symbol(";"), .. }, .. tokens] else {
    raise ParseError("Expect ';'")
  }
  let extern_function = ExternFunction::{ fname, param_list, ret_ty, ffi_name }
  (extern_function, tokens)
}
