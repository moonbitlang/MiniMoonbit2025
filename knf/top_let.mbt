///|
pub(all) struct KnfTopLet {
  name : Name
  ty : Type
  expr : KnfExpr
}

///|
pub fn Context::top_let_to_knf(
  self : Context,
  top_let : @typecheck.TopLet,
) -> KnfTopLet raise KnfTransformError {
  let stmts = []
  let (expr_stmts, init_expr) = self.expr_to_knf(top_let.expr)
  stmts.append(expr_stmts)
  let ty = self.typekind_to_knf(top_let.ty.kind)
  guard self.globals.get(top_let.name) is None else {
    raise KnfTransformError(
      "Duplicate global variable declaration: \{top_let.name}",
    )
  }
  let name = self.add_new_name(top_let.name, ty)
  let knf_top_let = KnfTopLet::{ name, ty, expr: init_expr, }
  self.globals.set(top_let.name, ty)
  self.global_stmts.append(stmts)
  knf_top_let
}

///|
pub impl Show for KnfTopLet with fn output(self, logger) {
  let { name, ty, expr, } = self
  logger.write_string("let \{name} : \{ty} = \{expr};")
}

///|
pub extend KnfTopLet with Show::{to_string, output}
