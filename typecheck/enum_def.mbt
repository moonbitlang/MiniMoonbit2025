///|
pub struct EnumDef {
  name : String
  enum_fields : Array[EnumField]
} derive(Show)

///|
pub fn EnumDef::get_field(self : Self, field_name : String) -> EnumField? {
  for field in self.enum_fields {
    if field.name == field_name {
      return Some(field)
    }
  }
  None
}

///|
pub struct EnumField {
  name : String
  types : Array[TypeKind]
} derive(Show)

///|
pub fn Context::check_enum_def(
  self : Self,
  enum_def : @parser.EnumDef,
) -> EnumDef raise TypeCheckError {
  let fields : Array[EnumField] = Array::new()
  for field in enum_def.enum_fields {
    let { name, types } = field
    let checked_types : Array[TypeKind] = types.map(t => self.check_parser_typekind(
      t.kind,
    ))
    let checked_field = EnumField::{ name, types: checked_types }
    fields.push(checked_field)
  }
  let enum_def = EnumDef::{ name: enum_def.name, enum_fields: fields }
  self.enum_defs.set(enum_def.name, enum_def)
  enum_def
}
