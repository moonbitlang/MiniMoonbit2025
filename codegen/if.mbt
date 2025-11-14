///|
pub fn Context::if_codegen(
  self : Self,
  cond : @knf.KnfExpr,
  then_block : @knf.KnfBlock,
  else_block : @knf.KnfBlock,
) -> &@llvm.Value? raise {
  guard self.expr_codegen(cond) is Some(cond_value) else {
    raise CodegenError("Condition expression did not produce a value")
  }
  let current_bb = self.builder.getInsertBlock()
  let current_func = current_bb.getParent()
  let then_bb = current_func.addBasicBlock()
  let else_bb = current_func.addBasicBlock()
  let merge_bb = current_func.addBasicBlock()
  let _ = self.builder.createCondBr(cond_value, then_bb, else_bb)
  // then block
  self.builder.setInsertPoint(then_bb)
  let then_stmt_len = then_block.stmts.length()
  let then_value = if then_stmt_len > 0 {
    for stmt in then_block.stmts[:then_stmt_len - 1] {
      self.stmt_codegen(stmt)
    }
    match then_block.stmts.last().unwrap() {
      ExprStmt(expr) => self.expr_codegen(expr)
      stmt => {
        self.stmt_codegen(stmt)
        None
      }
    }
  } else {
    None
  }
  let then_end_bb = self.builder.getInsertBlock()
  let terminated_in_then = then_end_bb.getTerminator() is Some(_)
  if !terminated_in_then {
    let _ = self.builder.createBr(merge_bb)

  }
  // else block
  self.builder.setInsertPoint(else_bb)
  let else_stmt_len = else_block.stmts.length()
  let else_value = if else_stmt_len > 0 {
    for stmt in else_block.stmts[:else_stmt_len - 1] {
      self.stmt_codegen(stmt)
    }
    match else_block.stmts.last().unwrap() {
      ExprStmt(expr) => self.expr_codegen(expr)
      stmt => {
        self.stmt_codegen(stmt)
        None
      }
    }
  } else {
    None
  }
  let else_end_bb = self.builder.getInsertBlock()
  let terminated_in_else = else_end_bb.getTerminator() is Some(_)
  if !terminated_in_else {
    let _ = self.builder.createBr(merge_bb)

  }
  if terminated_in_then && terminated_in_else {
    merge_bb.removeFromParent()
    return None
  }
  // merge block
  self.builder.setInsertPoint(merge_bb)
  if !(then_block.ty is Unit) {
    // Handle partially terminated branches
    match (terminated_in_then, terminated_in_else) {
      (false, false) => {
        // Both branches reach merge, need PHI
        guard then_value is Some(tv) else {
          raise CodegenError("Then branch did not produce a value")
        }
        guard else_value is Some(ev) else {
          raise CodegenError("Else branch did not produce a value")
        }
        let phi = self.builder.createPHI(tv.getType())
        phi.addIncoming(tv, then_end_bb)
        phi.addIncoming(ev, else_end_bb)
        Some((phi : &@llvm.Value))
      }
      (false, true) =>
        // Only then branch reaches merge, no PHI needed
        then_value
      (true, false) =>
        // Only else branch reaches merge, no PHI needed
        else_value
      (true, true) => {
        // Both terminated, should have been caught above
        raise CodegenError("Internal error: both branches terminated but not caught")
      }
    }
  } else {
    None
  }
}
