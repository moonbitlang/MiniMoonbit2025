# Kaida-Aemthyst/MiniMoonbit

MiniMoonbit 是一个 MoonBit 语言子集的编译器，将 MoonBit 源代码编译到 LLVM IR。

可以编译成llvm IR, aarch64汇编和riscv64汇编。

例子放在examples目录下

## 安装MoonBit

首先请确保安装了MoonBit工具链：

Linux/MacOs用户：

```
curl -fsSL https://cli.moonbitlang.cn/install/unix.sh | bash
```

Windows用户：

```
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser; irm https://cli.moonbitlang.cn/install/powershell.ps1 | iex
```

## Usage

以下的`{file}.mbt`代指MiniMoonBit语法文件，可以查看examples目录下的示例程序。

1. `moon run main` （打印帮助信息)

1. `moon run main -- x --help`（打印帮助信息，这里需要一个额外的x，或者任意字符串，因为当前的Moonbit工具链存在一个bug）

1. `moon run main -- {file}.mbt` （默认输出llvm IR，无需安装llvm 工具链）

2. `moon run main -- {file}.mbt --emit-llvm` （输出llvm IR）

3. `moon run main -- {file}.mbt --target=aarch64` （输出aarch64汇编）

4. `moon run main -- {file}.mbt --target=riscv64` （输出riscv64汇编）

## 特性

1. 支持基本的运算，控制流，字符串，数组，结构体，ADT，模式匹配等语法
2. 带有简单的错误恢复

以下是两个简单的错误恢复例子

简单的类型错误：

```plaintext
[err.mbt:5:7] Warning:
4|  let y = x + true;
5|  let (x) = 5;
6|      ^ Warning: Should Not use tuple pattern for single pattern

[err.mbt:3:15] Error:
2|fn main {
3|  let mut x = 8 + 1.0;
4|              ^ TypeMismatch: Binary Expression Must have same type for both side while got Int and Double

[err.mbt:4:12] Error:
3|  let mut x = 8 + 1.0;
4|  let y = x + true;
5|           ^ TypeMismatch: Binary Expression Must have same type for both side while got Int and Bool

[err.mbt:6:9] Error:
5|  let (x) = 5;
6|  return false;
7|        ^ Return type mismatch, wanted: Unit, got: Bool

Compilation Error: TypeCheckError("Type checking failed.")
RuntimeError: unreachable
    at wasm://wasm/0071595e:wasm-function[8919]:0x1700b3
error: failed to run
```

模式匹配的完备性检测：

```plaintext
moon run main -- enum.mbt
[enum.mbt:10:10] Error:
9|
10|  match a {
11|         ^ Non-exhaustive match expression, some patterns are not covered:
RGB(_, _, _)
RGB(255, _, _)
RGB(255, 0, _)
RGBA(_, _, _, _)
RGBA(255, _, _, _)
... and 2 more patterns

Compilation Error: TypeCheckError("Type checking failed.")
RuntimeError: unreachable
    at wasm://wasm/0071595e:wasm-function[8919]:0x1700b3
error: failed to run
```


## 编译运行

无论何种target，都需要注意与runtime.c链接。

## 其它选项

1. `--print-tokens`: 打印词法分析的结果。
2. `--print-ast`: 打印词法分析的结果。
3. `--print-typed-ast`: 打印类型标记的结果。
4. `--print-knf`： 打印knf转换后的结果。

## Example

运行`moon run main -- examples/fib.mbt`:

```llvm
;; ModuleID = 'demo'
;; Source File = "demo"

declare void @print_int(i32)

define i32 @fib(i32 %0) {
entry:
  %1 = icmp sle i32 %0, 1
  br i1 %1, label %3, label %5

3:                                     ; preds = %entry
  ret i32 %0

5:                                     ; preds = %entry
  br label %7

7:                                     ; preds = %5
  %8 = sub i32 %0, 1
  %9 = sub i32 %0, 2
  %10 = call i32 @fib(i32 %8)
  %11 = call i32 @fib(i32 %9)
  %12 = add i32 %10, %11
  ret i32 %12
}

define void @moonbit_main() {
entry:
  %0 = call i32 @fib(i32 10)
  call void @print_int(i32 %0)
  ret void 
}
```

运行`moon run main -- examples/fib.mbt --print-ast`

```plaintext
extern function: print_int
├-params:
│ └-x: Int
└-ffi: "print_int"

Top function: fib
├-params:
│ └-n: Int
├-return: Int
└-block
  ├-if expression
  │ ├-cond: binary expr: <=
  │ │       ├-variable n
  │ │       └-int literal 1
  │ └-then: block
  │         └-return statement
  │           └-variable n
  │         
  └-binary expr: +
    ├-function call
    │ ├-variable fib
    │ └-binary expr: -
    │   ├-variable n
    │   └-int literal 1
    └-function call
      ├-variable fib
      └-binary expr: -
        ├-variable n
        └-int literal 2
  
Top function: main
├-return: Unit
└-block
  ├-let statement
  │ ├-pattern: ident pattern result
  │ └-expr: function call
  │         ├-variable fib
  │         └-int literal 10
  └-function call
    ├-variable print_int
    └-variable result
```

运行`moon run main -- examples/fib.mbt --print-typed-ast`

```plaintext
extern function: print_int
├-params:
│ └-x: Int
├-return: Unit
└-ffi: "print_int"

Top function: fib
├-params:
│ └-n: Int
├-return: Int
└-block (Int)
  ├-if expression (Any)
  │ ├-cond: binary expr: <= (Bool)
  │ │       ├-variable n (Int)
  │ │       └-int literal 1 (Int)
  │ └-then: block (Any)
  │         └-return statement
  │           └-variable n (Int)
  │         
  └-binary expr: + (Int)
    ├-function call (Int)
    │ ├-variable fib ((Int) -> Int)
    │ └-binary expr: - (Int)
    │   ├-variable n (Int)
    │   └-int literal 1 (Int)
    └-function call (Int)
      ├-variable fib ((Int) -> Int)
      └-binary expr: - (Int)
        ├-variable n (Int)
        └-int literal 2 (Int)
  
Top function: main
├-return: Unit
└-block (Unit)
  ├-let statement
  │ ├-pattern: ident pattern result
  │ ├-type: : Int
  │ └-expr: function call (Int)
  │         ├-variable fib ((Int) -> Int)
  │         └-int literal 10 (Int)
  └-function call (Unit)
    ├-variable print_int ((Int) -> Unit)
    └-variable result (Int)
```


运行`moon run main -- examples/fib.mbt --print-knf`

```plaintext
;; KnfProgram: examples/fib.mbt

fn fib(n: Int) -> Int {
  let tmp : Int = 1;
  if n <= tmp {
    return n;
  };
  let tmp$1 : Int = 1;
  let tmp$2 : Int = n - tmp$1;
  let tmp$3 : Int = 2;
  let tmp$4 : Int = n - tmp$3;
  let tmp$5 : Int = fib(tmp$2);
  let tmp$6 : Int = fib(tmp$4);
  tmp$5 + tmp$6;
}
fn main {
  let tmp : Int = 10;
  let result : Int = fib(tmp);
  print_int(result);
}
```
