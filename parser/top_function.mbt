///|
pub(all) struct Param {
  name : String
  ty : Type
} derive(Eq)

///|
pub impl Show for Param with output(self, logger) {
  let s = self.to_string(color=true)
  logger.write_string(s)
}

///|
pub fn Param::to_string(self : Self, color? : Bool = true) -> String {
  "\{self.name}: \{self.ty.to_string(color~)}"
}

///|
pub(all) struct TopFunction {
  typeTag : String
  fname : String
  param_list : Array[Param]
  ret_ty : Type
  body : BlockExpr
} derive(Eq)

///|
pub impl Show for TopFunction with output(self, logger) {
  let s = self.to_string(color=true)
  logger.write_string(s)
}

///|
pub fn TopFunction::to_string(self : Self, color? : Bool = true) -> String {
  let full_name = if self.typeTag == "" {
    "Top function: \{self.fname}"
  } else {
    "Top function: \{self.typeTag}::\{self.fname}"
  }
  let prefix = if color { @color.taint(full_name, Magenta) } else { full_name }
  let mut result = prefix

  // Format parameters
  if self.param_list.length() > 0 {
    let params_prefix = "params:"
    let params_prefix = if color {
      @color.taint(params_prefix, Blue)
    } else {
      params_prefix
    }
    result = "\{result}\n├-\{params_prefix}"
    for i = 0; i < self.param_list.length(); i = i + 1 {
      let param = self.param_list[i]
      let param_text = param.to_string(color~)
      let is_last_param = i == self.param_list.length() - 1
      let param_formatted = if is_last_param {
        format_lines([param_text], head_with="└-", continue_with="  ")
      } else {
        format_lines([param_text], head_with="├-", continue_with="│ ")
      }
      result = "\{result}\n│ \{param_formatted}"
    }
  }

  // Format return type
  let ret_text = "return: \{self.ret_ty.to_string(color~)}"
  let ret_formatted = format_lines(
    [ret_text],
    head_with="├-",
    continue_with="│ ",
  )
  result = "\{result}\n\{ret_formatted}"

  // Format body
  let body_str = self.body.to_string(color~)
  let body_lines = body_str
    .split("\n")
    .map(fn(sv) { sv.to_string() })
    .to_array()
  let body_formatted = format_lines(
    body_lines,
  )
  result = "\{result}\n\{body_formatted}\n"
  result
}

///|
pub fn TopFunction::whole_name(self : TopFunction) -> String {
  if self.typeTag == "" {
    self.fname
  } else {
    self.typeTag + "$$" + self.fname
  }
}

///|
pub fn parse_param(
  tokens : ArrayView[Token],
) -> (Param, ArrayView[Token]) raise ParseError {
  guard tokens is [{ kind: Lower(name), .. }, .. tokens] else {
    raise ParseError("Expect a lower case")
  }
  guard tokens is [{ kind: Symbol(":"), .. }, .. tokens] else {
    raise ParseError("Expect a `:`")
  }
  let (ty, tokens) = parse_type(tokens)
  let param = Param::{ name, ty }
  (param, tokens)
}

///|
pub fn parse_param_list(
  tokens : ArrayView[Token],
) -> (Array[Param], ArrayView[Token]) raise ParseError {
  let params : Array[Param] = Array::new()
  let tokens = loop tokens {
    [{ kind: Lower(_), .. }, ..] as tokens => {
      let (param, rest) = parse_param(tokens)
      params.push(param)
      continue rest
    }
    [{ kind: Symbol(","), .. }, { kind: Lower(_), .. }, ..] as tokens => {
      let (param, rest) = parse_param(tokens[1:])
      params.push(param)
      continue rest
    }
    [{ kind: Symbol(","), .. }, { kind: Bracket(')'), .. }, ..] as tokens =>
      break tokens[1:]
    [{ kind: Bracket(')'), .. }, ..] as tokens => break tokens
    [] => {
      println("Compiler ICE: Empty Token ArrayView")
      panic()
    }
    tok => raise ParseError("InValid Param List Parsing: \{tok[0]}")
  }
  (params, tokens)
}

///|
pub fn parse_top_function(
  tokens : ArrayView[Token],
) -> (TopFunction, ArrayView[Token]) raise ParseError {
  guard tokens is [{ kind: Keyword(Fn), .. }, .. tokens] else {
    println("Compiler ICE: Misuse parse_top_function")
    panic()
  }
  let (typeTag, tokens) = if tokens is [{ kind: Upper(t), .. }, .. tokens] {
    guard tokens is [{ kind: Symbol("::"), .. }, .. tokens] else {
      raise ParseError("Expect '::'")
    }
    (t, tokens)
  } else {
    ("", tokens)
  }
  guard tokens is [{ kind: Lower(fname), .. }, .. tokens] else {
    raise ParseError("Expect a lower ident")
  }
  let (param_list, ret_ty, tokens) = if !(fname is "main") {
    guard tokens is [{ kind: Bracket('('), .. }, .. tokens] else {
      raise ParseError("Expect '('")
    }
    let (param_list, tokens) = parse_param_list(tokens)
    guard tokens is [{ kind: Bracket(')'), .. }, .. tokens] else {
      raise ParseError("Expect ')'")
    }
    guard tokens is [{ kind: Symbol("->"), .. }, .. tokens] else {
      raise ParseError("Expect '->'")
    }
    let (ret_ty, tokens) = parse_type(tokens)
    (param_list, ret_ty, tokens)
  } else {
    let ret_type = Type::{ kind: Unit, toks: [] }
    (Array::new(), ret_type, tokens)
  }
  let (body, tokens) = parse_block_expr(tokens)
  let top_function = TopFunction::{ typeTag, fname, param_list, ret_ty, body }
  (top_function, tokens)
}

///|
test "TopFunction to_string Test - Simple" {
  let color = false
  let code =
    #|fn add(x: Int, y: Int) -> Int { return x + y ; }
  let tokens = @lexer.tokenize(code, source_file="test")

  // Parse simple top function
  let (top_fn, _) = parse_top_function(tokens)
  inspect(
    top_fn.to_string(color~),
    content=(
      #|Top function: add
      #|├-params:
      #|│ ├-x: Int
      #|│ └-y: Int
      #|├-return: Int
      #|└-block
      #|  └-return statement
      #|    └-binary expr: +
      #|      ├-variable x
      #|      └-variable y
      #|  
      #|

    ),
  )
}

///|
test "TopFunction to_string Test - With Type Tag" {
  let color = false
  let code =
    #|fn Point::distance(x: Int, y: Int) -> Double { return 0.0 ; }
  let tokens = @lexer.tokenize(code, source_file="test")

  // Parse top function with type tag
  let (top_fn, _) = parse_top_function(tokens)
  inspect(
    top_fn.to_string(color~),
    content=(
      #|Top function: Point::distance
      #|├-params:
      #|│ ├-x: Int
      #|│ └-y: Int
      #|├-return: Double
      #|└-block
      #|  └-return statement
      #|    └-double literal 0
      #|  
      #|

    ),
  )
}

///|
test "TopFunction to_string Test - Main" {
  let color = false
  let code =
    #|fn main { let x = 42 ; }
  let tokens = @lexer.tokenize(code, source_file="test")

  // Parse main function
  let (top_fn, _) = parse_top_function(tokens)
  inspect(
    top_fn.to_string(color~),
    content=(
      #|Top function: main
      #|├-return: Unit
      #|└-block
      #|  └-let statement
      #|    ├-pattern: ident pattern x
      #|    └-expr: int literal 42
      #|  
      #|

    ),
  )
}
