
fn main {
  let help_info =
    #|Usage: tmbt [options]
    #|
    #|Options:
    #|  -h, --help             Show this help message
    #|  -f, --file <file>      Specify the input TinyMoonbit source file (Must provide)
    #|  -stop-after=tokenize   Stop after tokenization
    #|  -stop-after=parse      Stop after parsing
    #|  -stop-after=typecheck  Stop after parsing
    #|  -stop-after=knf        Stop after Knf transformation
  let args = @env.args()
  let legal_args = [
    "-h", "--help", "-f", "--file",
    "-stop-after=tokenize", "-stop-after=parse",
    "-stop-after=typecheck", "-stop-after=knf",
  ]
  for arg in args[1:] {
    if arg.has_prefix("-") && !legal_args.contains(arg) {
      println("Unknown argument: \{arg}")
      println(help_info)
      return
    }
  }
  if args.contains("-h") || args.contains("--help") {
    println(help_info)
    return
  }
  let fidx = args.search_by(arg => arg is "-f" || arg is "--file")
  let code = match fidx {
    Some(idx) if idx + 1 < args.length() => {
      let filename = args[idx + 1]
      let code = @fs.read_file_to_string(filename) catch {
        err => {
          println("Error reading file '\{filename}': \{err}")
          return
        }
      }
      code
    }
    Some(_) => {
      println("Error: No file specified after -f/--file option.")
      return
    }
    None => {
      println(
        "Error: No input file specified. Use -f or --file to specify the source file.",
      )
      println(help_info)
      return
    }
  }
  let tokens = @lexer.tokenize(code) catch {
    err => {
      println("Lexing error: \{err}")
      return
    }
  }
  if args.contains("-stop-after=tokenize") {
    println(tokens)
    return
  }
  let program = @parser.parse(tokens) catch {
    err => {
      println("Parsing error: \{err}")
      return
    }
  }
  if args.contains("-stop-after=parse") {
    println(program)
    return
  }
}
