///|
test "LLVM call prints individual parameter attributes" {
  let ctx = @llvm.Context::new()
  let module_ = ctx.addModule("attributes")
  let builder = ctx.createBuilder()
  let i32_ty = ctx.getInt32Ty()
  let callee = module_.addFunction(
    ctx.getFunctionType(i32_ty, [i32_ty]),
    "callee",
  )
  let caller = module_.addFunction(ctx.getFunctionType(i32_ty, []), "caller")
  builder.setInsertPoint(caller.addBasicBlock(name="entry"))
  let call = builder.createCall(callee, [ctx.getConstInt32(1)], name="result")
  inspect(call, content="  %result = call i32 @callee(i32 1)")
  callee.getArg(0).unwrap().addAttr(@llvm.NoUndef)
  inspect(call, content="  %result = call i32 @callee(i32 noundef 1)")
}
