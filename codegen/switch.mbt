///|
pub fn Context::switch_codegen(
  self : Self,
  cond_name : @knf.Name,
  cases : Array[(Int, @knf.KnfBlock)],
  default_block : @knf.KnfBlock,
) -> &@llvm.Value? raise {
  // Get the condition value (should be an integer)
  let cond_value = self.get_value_by_name_or_load(cond_name)

  // Get current function and create basic blocks
  let current_bb = self.builder.getInsertBlock()
  let current_func = current_bb.getParent()

  // Create basic blocks for each case, default, and merge
  let case_bbs : Array[@llvm.BasicBlock] = []
  for _ in cases {
    case_bbs.push(current_func.addBasicBlock())
  }
  let default_bb = current_func.addBasicBlock()
  let merge_bb = current_func.addBasicBlock()

  // Create switch instruction
  let switch_inst = self.builder.createSwitch(cond_value, default_bb)

  // Add cases to switch instruction
  for i, case in cases {
    let (case_value, _) = case
    let case_const = self.llvm_ctx.getConstInt32(case_value)
    switch_inst.addCase(case_const, case_bbs[i])
  }

  // Generate code for each case
  let case_values : Array[&@llvm.Value?] = []
  let case_end_bbs : Array[@llvm.BasicBlock] = []
  let case_terminated : Array[Bool] = []
  for i, case in cases {
    let (_, case_block) = case
    self.builder.setInsertPoint(case_bbs[i])
    let case_stmt_len = case_block.stmts.length()
    let case_value = if case_stmt_len > 0 {
      for stmt in case_block.stmts[:case_stmt_len - 1] {
        self.stmt_codegen(stmt)
      }
      match case_block.stmts.last().unwrap() {
        ExprStmt(expr) => self.expr_codegen(expr)
        stmt => {
          self.stmt_codegen(stmt)
          None
        }
      }
    } else {
      None
    }
    let case_end_bb = self.builder.getInsertBlock()
    let terminated = case_end_bb.getTerminator() is Some(_)
    case_terminated.push(terminated)
    if !terminated {
      let _ = self.builder.createBr(merge_bb)

    }
    case_values.push(case_value)
    case_end_bbs.push(case_end_bb)
  }

  // Generate code for default block
  self.builder.setInsertPoint(default_bb)
  let default_stmt_len = default_block.stmts.length()
  let default_value = if default_stmt_len > 0 {
    for stmt in default_block.stmts[:default_stmt_len - 1] {
      self.stmt_codegen(stmt)
    }
    match default_block.stmts.last().unwrap() {
      ExprStmt(expr) => self.expr_codegen(expr)
      stmt => {
        self.stmt_codegen(stmt)
        None
      }
    }
  } else {
    // Default block is empty (all cases covered)
    None
  }
  let default_end_bb = self.builder.getInsertBlock()
  let default_terminated = default_end_bb.getTerminator() is Some(_)

  // Determine if default block should contribute to PHI
  // Default block is considered "empty" if it has no statements and produces no value
  let default_is_empty = default_stmt_len == 0
  if !default_terminated {
    let _ = self.builder.createBr(merge_bb)

  }

  // Check if all branches are terminated
  let mut all_cases_terminated = true
  for terminated in case_terminated {
    if !terminated {
      all_cases_terminated = false
      break
    }
  }
  let all_terminated = default_terminated && all_cases_terminated
  if all_terminated {
    merge_bb.removeFromParent()
    return None
  }

  // Generate merge block with PHI node if needed
  self.builder.setInsertPoint(merge_bb)

  // Determine result type from the first case or default block
  let result_ty = if cases.length() > 0 {
    cases[0].1.ty
  } else {
    default_block.ty
  }
  if !(result_ty is Unit) {
    // Create PHI node
    guard case_values.get(0) is Some(Some(first_value)) else {
      raise CodegenError("Switch case did not produce a value")
    }
    let phi = self.builder.createPHI(first_value.getType())

    // Add incoming values from case blocks
    for i, case_value_opt in case_values {
      if !case_terminated[i] {
        guard case_value_opt is Some(case_value) else {
          raise CodegenError("Switch case \{i} did not produce a value")
        }
        phi.addIncoming(case_value, case_end_bbs[i])
      }
    }

    // Add incoming value from default block (only if it's not empty)
    if !default_terminated && !default_is_empty {
      guard default_value is Some(dv) else {
        raise CodegenError("Switch default block did not produce a value")
      }
      phi.addIncoming(dv, default_end_bb)
    }
    Some((phi : &@llvm.Value))
  } else {
    None
  }
}
