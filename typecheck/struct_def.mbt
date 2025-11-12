///|
pub(all) struct StructDef {
  name : String
  fields : Array[StructField]
  methods : Map[String, TypeKind]
}

///|
pub impl Show for StructDef with output(self, logger) {
  let s = self.to_string(color=true)
  logger.write_string(s)
}

///|
pub fn StructDef::to_string(self : Self, color? : Bool = true) -> String {
  let prefix = "struct: \{self.name}"
  let prefix = if color { @color.taint(prefix, Magenta) } else { prefix }
  if self.fields.length() == 0 {
    return "\{prefix} (no fields)"
  }
  let mut result = prefix
  for i = 0; i < self.fields.length(); i = i + 1 {
    let field = self.fields[i]
    let field_str = field.to_string(color~)
    let field_lines = field_str
      .split("\n")
      .map(fn(sv) { sv.to_string() })
      .to_array()
    let is_last = i == self.fields.length() - 1
    let field_formatted = if is_last {
      @parser.format_lines(field_lines, head_with="└-", continue_with="  ")
    } else {
      @parser.format_lines(field_lines, head_with="├-", continue_with="│ ")
    }
    result = "\{result}\n\{field_formatted}"
  }
  result + "\n"
}

///|
pub(all) struct StructField {
  name : String
  ty : Type
}

///|
pub impl Show for StructField with output(self, logger) {
  let s = self.to_string(color=true)
  logger.write_string(s)
}

///|
pub fn StructField::to_string(self : Self, color? : Bool = true) -> String {
  let mut_str = if self.ty.mutable { "mut " } else { "" }
  let ty_str = self.ty.kind.to_string()
  let ty_str = if color { @color.taint(ty_str, Green) } else { ty_str }
  "\{mut_str}\{self.name}: \{ty_str}"
}

///|
pub fn StructDef::get_field_type(self : Self, field_name : String) -> Type? {
  for field in self.fields {
    if field.name == field_name {
      return Some(field.ty)
    }
  }
  return None
}

///|
pub fn Context::check_struct_def(
  self : Self,
  struct_def : @parser.StructDef,
) -> StructDef raise TypeCheckError {
  let fields : Array[StructField] = Array::new()
  for field in struct_def.fields {
    let { name, is_mut, ty } = field
    let ty = self.check_parser_typekind(ty.kind)
    let ty = Type::{ kind: ty, mutable: is_mut }
    let checked_field = StructField::{ name, ty }
    fields.push(checked_field)
  }
  let struct_def = StructDef::{
    name: struct_def.name,
    fields,
    methods: Map::new(),
  }
  self.struct_defs.set(struct_def.name, struct_def)
  struct_def
}

///|
test "StructDef to_string Test - Simple" {
  let color = false
  let ctx = Context::new()
  let code =
    #|struct Point { x: Int; y: Int }
  let tokens = @lexer.tokenize(code)

  // Parse and check simple struct
  let (parsed, _) = @parser.parse_struct_def(tokens)
  let checked = ctx.check_struct_def(parsed)
  inspect(
    checked.to_string(color~),
    content=(
      #|struct: Point
      #|├-x: Int
      #|└-y: Int
      #|
    ),
  )
}

///|
test "StructDef to_string Test - With Mut" {
  let color = false
  let ctx = Context::new()
  let code =
    #|struct Counter { mut count: Int; name: String }
  let tokens = @lexer.tokenize(code)

  // Parse and check struct with mut field
  let (parsed, _) = @parser.parse_struct_def(tokens)
  let checked = ctx.check_struct_def(parsed)
  inspect(
    checked.to_string(color~),
    content=(
      #|struct: Counter
      #|├-mut count: Int
      #|└-name: String
      #|
    ),
  )
}
