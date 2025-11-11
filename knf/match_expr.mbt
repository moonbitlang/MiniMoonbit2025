///|
pub fn Context::match_expr_to_knf(
  self : Context,
  expr : @typecheck.MatchExpr,
) -> (Array[KnfStmt], KnfExpr) raise KnfTransformError {
  ignore(self)
  ignore(expr)
  raise KnfTransformError("match expressions are not supported in KNF")
}
