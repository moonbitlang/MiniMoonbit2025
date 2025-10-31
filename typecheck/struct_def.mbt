///|
pub(all) struct StructDef {
  name : String
  fields : Array[StructField]
  methods: Map[String, TypeKind]
} derive(Show)

///|
pub(all) struct StructField {
  name : String
  ty : Type
} derive(Show)

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
  let struct_def = StructDef::{ name: struct_def.name, fields, methods: Map::new() }
  self.struct_defs.set(struct_def.name, struct_def)
  struct_def
}
