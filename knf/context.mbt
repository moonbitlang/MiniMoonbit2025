///|
pub(all) suberror KnfTransformError String derive(Show)

///|
pub(all) struct Name {
  id : String
  slot : Int
} derive(Hash, Eq)

///|
pub fn Name::wildcard() -> Name {
  Name::{ id: "_", slot: 0 }
}

///|
pub impl Show for Name with output(self, logger) {
  logger.write_string(self.id)
  if self.slot > 0 {
    logger.write_string("$\{self.slot}")
  }
}

///|
pub(all) struct Env {
  local_ : Map[String, (Name, Type)] // defined in this scope
  capture : Map[Name, Type] // captured from outer scopes
  parent : Env?
}

///|
pub fn Env::new(parent? : Env? = None) -> Env {
  Env::{ local_: Map::new(), capture: Map::new(), parent }
}

///|
pub fn Env::get_and_capture(self : Env, name : String) -> (Name, Type)? {
  if self.local_.get(name) is Some(n) {
    return Some(n)
  }
  // In This Case, it is top function
  guard self.parent is Some(p) else { return None }
  // In This Case, it is local function, search parent
  match p.get_and_capture(name) {
    Some((n, ty)) => {
      self.capture.set(n, ty)
      Some((n, ty))
    }
    None => None
  }
}

///|
pub fn Env::get_name_type(self : Env, name : Name) -> Type? {
  let { id, .. } = name
  match self.local_.get(id) {
    Some((_, t)) => Some(t)
    None =>
      match self.parent {
        Some(p) => p.get_name_type(name)
        None => None
      }
  }
}

///|
pub fn Env::get(self : Env, name : String) -> Name? {
  match self.local_.get(name) {
    Some((n, _)) => Some(n)
    None =>
      match self.parent {
        Some(p) => p.get(name)
        None => None
      }
  }
}

///|
pub fn Env::set(self : Env, s : String, name : Name, ty : Type) -> Unit {
  self.local_.set(s, (name, ty))
}

///|
pub(all) struct Context {
  mut name_env : Env
  capture : Array[Name]
  global_stmts : Array[KnfStmt]
  globals : Map[String, Type]
  unions : Map[String, Array[String]] // union name to variant names
  struct_defs : Map[String, KnfStructDef] // struct definitions
}

///|
pub fn Context::new() -> Context {
  Context::{
    name_env: Env::new(),
    capture: Array::new(),
    global_stmts: Array::new(),
    globals: Map::new(),
    unions: Map::new(),
    struct_defs: Map::new(),
  }
}

///|
pub fn Context::lookup_name(self : Context, s : String) -> (Name, Type)? {
  match self.name_env.get_and_capture(s) {
    Some(n) => Some(n)
    None =>
      match self.globals.get(s) {
        Some(t) => {
          let name = Name::{ id: s, slot: 0 }
          Some((name, t))
        }
        None => None
      }
  }
}

///|
pub fn Context::enter_scope(self : Context) -> Unit {
  let sub_env = Env::new(parent=Some(self.name_env))
  self.name_env = sub_env
}

///|
pub fn Context::exit_scope(self : Context) -> Unit {
  self.name_env = match self.name_env.parent {
    Some(p) => p
    None => self.name_env
  }
}

///|
pub fn Context::add_new_name(self : Context, s : String, ty : Type) -> Name {
  match self.name_env.get(s) {
    Some({ id, slot }) => {
      let name = Name::{ id, slot: slot + 1 }
      self.name_env.set(s, name, ty)
      name
    }
    None => {
      let name = Name::{ id: s, slot: 0 }
      self.name_env.set(s, name, ty)
      name
    }
  }
}

///|
pub fn Context::add_temp(self : Context, ty : Type) -> Name {
  let temp_id = "tmp"
  self.add_new_name(temp_id, ty)
}
