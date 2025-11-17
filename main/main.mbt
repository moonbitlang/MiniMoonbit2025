suberror ArgError {
  RedundantOption(String)
  InValidOption(String)
  NoInputFiles(String)
  MultipleInputFiles(String)
  InValidFile(String)
  InValidOutput(String)
} derive(Show)

fn main_err() -> Unit raise {
  let files: Array[String] = Array::new()
  let output: Ref[String] = @ref.new("")
  let print_tokens : Ref[Bool] = @ref.new(false)
  let print_ast : Ref[Bool] = @ref.new(false)
  let print_typed_ast : Ref[Bool] = @ref.new(false)
  let print_knf : Ref[Bool] = @ref.new(false)
  let print_all : Ref[Bool] = @ref.new(false)
  let emit_llvm : Ref[Bool] = @ref.new(false)
  let out_rv64 : Ref[Bool] = @ref.new(false)
  let out_aarch64 : Ref[Bool] = @ref.new(false)

  let spec: Array[(String, String, @ArgParser.Spec, String)] = [
    ("--print-tokens", "-toks", Set(print_tokens), "Stop after lexing phase and print tokens."),
    ("--print-ast", "-ast", Set(print_ast), "Stop after parsing phase and print AST."),
    ("--print-typed-ast", "-typed", Set(print_typed_ast), "Stop after type checking phase and print typed AST."),
    ("--print-knf", "-knf", Set(print_knf), "Stop after KNF transformation phase and print KNF."),
    ("--emit-llvm", "-emit-llvm", Set(emit_llvm), "Emit the generated LLVM IR. (Default target)"),
    ("--target=riscv64", "-target=riscv64", Set(out_rv64), "Set target architecture to RISC-V 64-bit."),
    ("--target=aarch64", "-target=aarch64", Set(out_aarch64), "Set target architecture to AArch64."),
    ("--print-all", "-all", Set(print_all), "Print all intermediate representations."),
    ("--output", "-o", Set_string(output), "Specify output file name."),
  ]

  let usage = 
    #|MiniMoonBit Compiler
    #|
    #|Usage: minimoonc [options] <source files>"

  let args = @env.args()[1:].to_array()
  @ArgParser.parse(spec, file => files.push(file), usage, args)

  let print_tokens = print_tokens.val || print_all.val
  let print_ast = print_ast.val || print_all.val
  let print_typed_ast = print_typed_ast.val || print_all.val
  let print_knf = print_knf.val || print_all.val

  // Check valid arguments
  // 1. must only one file
  if files.length() == 0 {
    raise NoInputFiles("No input files specified!")
  } else if files.length() > 1 {
    let opt = files[1]
    if opt.has_suffix(".mbt") {
      raise MultipleInputFiles("Multiple input files specified. Only one input file is allowed! while got \{files}")
    } else {
      raise InValidOption("Invalid option `\{opt}` detected!")
    }
  }

  // 2. file must be end with .mbt
  let source_file = files[0]
  if !source_file.has_suffix(".mbt") {
    raise InValidFile("`\{source_file}` is Not a valid MiniMoonBit source file name, input file must have `.mbt` extension!")
  }

  // 3. emit-llvm, target=riscv64, target=aarch64, only one can be specified
  let target_specified : Array[String] = Array::new()
  if emit_llvm.val { target_specified.push("--emit-llvm") }
  if out_rv64.val { target_specified.push("--target=riscv64") }
  if out_aarch64.val { target_specified.push("--target=aarch64") }
  if target_specified.length() > 1 {
    let special_opt = target_specified[0]
    let redundant_opt = target_specified[1]
    raise RedundantOption("Cannot specify \{redundant_opt} when \{special_opt} is specified.")
  }

  if target_specified.length() == 0 {
    // default target is riscv64
    emit_llvm.val = true
  }

  // 5. if --output specified, if --target=riscv64 or --target=aarch64 is specified, output file must end with .s
  // if --emit-llvm is specified, output file must end with .ll
  // if not specified, default output to stdout
  if emit_llvm.val && output.val != "" && !output.val.has_suffix(".ll") {
    raise InValidOutput("`\{output.val}` is InValid name. Output file must have a .ll extension when no target specified or  `--emit-llvm` is specified")
  }
  if out_aarch64.val && output.val != "" && !output.val.has_suffix(".s") {
    raise InValidOutput("`\{output.val}` is InValid name. Output file must have a .s extension when `--target=aarch64` is specified.")
  }
  if out_rv64.val && output.val != "" && !output.val.has_suffix(".s") {
    raise InValidOutput("`\{output.val}` is InValid name. Output file must have a .s extension when `--target=riscv64` is specified.")
  }

  // Proceed with compilation steps...
  let code = @fs.read_file_to_string(source_file)

  // Lexer
  let tokens = @lexer.tokenize(code, source_file~)
  if print_tokens { tokens.each(tok => println(tok)); if !print_all.val { return }
 }
  
  // Parser
  let ast = @parser.parse(tokens)
  if print_ast { println(ast); if !print_all.val { return } }

  // Typechecker
  let typed_ast = @typecheck.typecheck(ast)
  if print_typed_ast { println(typed_ast); if !print_all.val { return } }

  // KNF Transformation
  let knf = @knf.knf_transform(typed_ast)
  if print_knf { println(knf); if !print_all.val { return } }

  // Code Generation, llvm
  let llvm_mod = @codegen.codegen(knf)
  if print_all.val { println(llvm_mod) }
  if emit_llvm.val {
    if output.val != "" {
      @fs.write_string_to_file(output.val, llvm_mod.to_string())
    } else {
      if !print_all.val {
        println(llvm_mod)
      }
    }
    return
  }

  // riscv64
  if out_rv64.val {
    let rv_module = @riscv64.compile(llvm_mod)
    if print_all.val {
      println(rv_module)
    }
    if output.val != "" {
      @fs.write_string_to_file(output.val, rv_module.to_string())
    } else {
      if !print_all.val {
        println(rv_module)
      }
    }
  }

  if out_aarch64.val {
    let aarch64_module = @aarch64.compile(llvm_mod)
    if print_all.val {
      println(aarch64_module)
    }
    if output.val != "" {
      @fs.write_string_to_file(output.val, aarch64_module.to_string())
    } else {
      if !print_all.val {
        println(aarch64_module)
      }
    }
  }
}

fn main {
  try main_err() catch {
    @ArgParser.ErrorMsg(msg) => { println(msg); panic() }
    NoInputFiles(msg) => { println("\{msg}"); panic() }
    MultipleInputFiles(msg) => { println("\{msg}"); panic() }
    InValidFile(msg) => { println("\{msg}"); panic() }
    InValidOutput(msg) => { println("\{msg}"); panic() }
    RedundantOption(msg) => { println("\{msg}"); panic() }
    InValidOption(msg) => { println("\{msg}"); panic() }
    err => { println("Compilation Error: \{err}"); panic() }
  } noraise {
    _ => ()
  }
}
