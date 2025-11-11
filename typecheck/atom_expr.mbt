///|
pub(all) struct AtomExpr {
  kind : AtomExprKind
  ty : TypeKind
  toks: ArrayView[Token]
} derive(Show)

///|
pub(all) enum AtomExprKind {
  Int(Int) // 1, 42, etc
  Int64(Int64) // 1L, 42L, etc
  UInt(UInt) // 1U, 42U, etc
  UInt64(UInt64) // 1UL, 42UL, etc
  Double(Double) // 1.0, 3.14, etc
  Float(Double) // 1.0F, 3.14F (stored as Double)
  Char(Char) // 'a', '\n', etc
  Bool(Bool) // true | false
  String(String) // "hello", etc
  Ident(String) // var
  Unit // ()
  Paren(Expr) // (expr)
  Tuple(Array[Expr]) // (expr, expr, ...)
  Array(Array[Expr]) // [expr, expr, ...]
  ArrayMake(Expr, Expr) // Array::make(size, init)
  StructConstruct(StructConstructExpr) // StructName::{ field: expr, ... }
  EnumConstruct(String, String, Array[Expr]) // [Tag::]Variant(expr, ...)
  Cast(TypeKind, Expr) // Type cast: e.g., n.to_int()
  BitCast(TypeKind, Expr) // Bitcast: e.g., n.reinterpret_as_float()
} derive(Show)

///|
pub fn Context::check_atom_expr(
  self : Self,
  atom_expr : @parser.AtomExpr,
) -> AtomExpr {
  let (typed_atom_expr_kind, type_kind) = match atom_expr.kind {
    Int(v) => (AtomExprKind::Int(v), TypeKind::Int)
    Int64(v) => (AtomExprKind::Int64(v), TypeKind::Int64)
    UInt(v) => (AtomExprKind::UInt(v), TypeKind::UInt)
    UInt64(v) => (AtomExprKind::UInt64(v), TypeKind::UInt64)
    Double(v) => (Double(v), Double)
    Float(v) => (Float(v), Float)
    Char(c) => (Char(c), Char)
    Bool(v) => (Bool(v), Bool)
    String(s) => (String(s), String)
    Unit => (Unit, Unit)
    Ident(name) => {
      let ty = match self.lookup_type(name) {
        Some(ty) => ty
        None => {
          self.throw_(
            atom_expr.toks[0],
            "Undefined identifier: \{name}",
            Error,
          )
          { kind: TypeKind::Unit, mutable: false }
        }
      }
      (Ident(name), ty.kind)
    }
    IdentWithTag(tag, name) => {
      let whole_name = "\{tag}$$\{name}"
      let ty = match self.lookup_type(whole_name) {
        Some(ty) => ty
        None => {
          self.throw_(
            atom_expr.toks[0],
            "Undefined identifier: \{tag}::\{name}",
            Error,
          )
          { kind: TypeKind::Unit, mutable: false }
        }
      }
      // Use the mangled name (whole_name) instead of just name
      (Ident(whole_name), ty.kind)
    }
    Paren(expr) => {
      let typed_expr = self.check_expr(expr)
      (Paren(typed_expr), typed_expr.ty)
    }
    Array(exprs) => self.check_array_expr(exprs)
    ArrayMake(size_expr, init_expr) =>
      self.check_array_make_expr(size_expr, init_expr)
    Tuple(exprs) => self.check_tuple_expr(exprs)
    EnumConstruct(tag, variant_name, exprs) => self.check_enum_constuct_expr(
      tag,
      variant_name,
      exprs,
      atom_expr,
    )
    StructConstruct(sc_expr) => self.check_struct_construct_expr(sc_expr)
  }
  AtomExpr::{ kind: typed_atom_expr_kind, ty: type_kind, toks: atom_expr.toks }
}

///|
pub fn Context::check_array_expr(
  self : Self,
  exprs : Array[@parser.Expr],
) -> (AtomExprKind, TypeKind) {
  let exprs = exprs.map(e => self.check_expr(e))
  if exprs.length() == 0 {
    let atom_expr_kind = AtomExprKind::Array([])
    let type_kind = self.add_type_var()
    return (atom_expr_kind, Array(type_kind))
  }
  for expr in exprs {
    if self.is_type_compatible(expr.ty, exprs[0].ty) == false {
      self.throw_(
        expr.toks[0],
        "Array elements must have the same type, found \{exprs[0].ty} and \{expr.ty}",
        Error,
      )
    }
  }
  let atom_expr_kind : AtomExprKind = AtomExprKind::Array(exprs)
  let type_kind = self.ensure_type(exprs[0].ty)
  (atom_expr_kind, Array(type_kind))
}

///|
pub fn Context::check_array_make_expr(
  self : Self,
  size_expr : @parser.Expr,
  init_expr : @parser.Expr,
) -> (AtomExprKind, TypeKind) {
  let typed_size_expr = self.check_expr(size_expr)
  if !(typed_size_expr.ty is Int) {
    let msg = "Array size must be of type Int, while got \{typed_size_expr.ty}"
    self.set_error_happened()
    self.throw_(typed_size_expr.toks[0], msg, Error)
  }
  let typed_init_expr = self.check_expr(init_expr)
  let atom_expr_kind = AtomExprKind::ArrayMake(typed_size_expr, typed_init_expr)
  let type_kind = TypeKind::Array(typed_init_expr.ty)
  (atom_expr_kind, type_kind)
}

///|
pub fn Context::check_tuple_expr(
  self : Self,
  exprs : Array[@parser.Expr],
) -> (AtomExprKind, TypeKind) {
  let typed_exprs = exprs.map(e => self.check_expr(e))
  let atom_expr_kind = AtomExprKind::Tuple(typed_exprs)
  let type_kind = TypeKind::Tuple(typed_exprs.map(e => e.ty))
  (atom_expr_kind, type_kind)
}
