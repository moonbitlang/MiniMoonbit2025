#!/usr/bin/env python3
"""
MiniMoonBit 多后端测试脚本
"""

import os
import sys
import subprocess
import glob
import platform
import shutil

class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    END = '\033[0m'
    BOLD = '\033[1m'

class FailureReason:
    COMPILE_ERROR = "编译错误"
    ASSEMBLE_ERROR = "汇编错误"
    RUN_ERROR = "运行错误"
    NO_ANS_FILE = "未找到ans文件"
    OUTPUT_MISMATCH = "输出不匹配"

class Environment:
    def __init__(self):
        self.os_name = ""
        self.cpu_arch = ""
        self.has_clang = False
        self.has_qemu_aarch64 = False
        self.has_qemu_riscv64 = False
        self.has_spike = False
        self.has_riscv_gcc_linux = False
        self.has_riscv_gcc_elf = False

env = Environment()

def run_command(cmd, capture_output=True, timeout=30):
    """运行命令并返回结果"""
    try:
        if capture_output:
            result = subprocess.run(
                cmd,
                shell=True,
                capture_output=True,
                text=True,
                timeout=timeout
            )
            return result.returncode, result.stdout, result.stderr
        else:
            result = subprocess.run(
                cmd,
                shell=True,
                timeout=timeout
            )
            return result.returncode, "", ""
    except subprocess.TimeoutExpired:
        return -1, "", "Timeout"
    except Exception as e:
        return -1, "", str(e)

def check_command(cmd):
    """检测命令是否存在"""
    return shutil.which(cmd) is not None

def detect_environment(targets):
    """检测运行环境"""
    print("正在检测测试环境...")

    # 1. 检测 OS 和 CPU 架构
    sys_platform = platform.system()
    if sys_platform == 'Darwin':
        env.os_name = 'macos'
    elif sys_platform == 'Linux':
        env.os_name = 'linux'
    else:
        print(f"{Colors.RED}错误: 不支持的操作系统 {sys_platform}。仅支持 MacOS 和 Linux。{Colors.END}")
        sys.exit(1)

    machine = platform.machine().lower()
    if machine in ['x86_64', 'amd64']:
        env.cpu_arch = 'x86'
    elif machine in ['aarch64', 'arm64']:
        env.cpu_arch = 'aarch64' # Unify as aarch64
    elif machine in ['riscv64']:
        env.cpu_arch = 'riscv64'
    else:
        print(f"{Colors.YELLOW}警告: 未知的 CPU 架构 {machine}，默认为 x86{Colors.END}")
        env.cpu_arch = 'x86'

    # 2. 检测 clang (所有 target 都需要，或者至少 llvm 和 aarch64 需要)
    if not check_command('clang'):
        print(f"{Colors.RED}错误: 用户的机器上没有安装 clang，无法测试 llvm 后端。{Colors.END}")
        print(f"{Colors.YELLOW}建议用户安装 clang。{Colors.END}")
        if env.os_name == 'linux':
            print("在 Ubuntu 上安装: sudo apt-get install clang")
        elif env.os_name == 'macos':
            print("在 MacOS 上安装: xcode-select --install")
        sys.exit(1)
    env.has_clang = True

    # 3. 如果需要测试 aarch64
    if 'aarch64' in targets:
        if env.cpu_arch == 'aarch64':
            pass # Native execution
        else:
            # Check for qemu-aarch64
            if check_command('qemu-aarch64'):
                env.has_qemu_aarch64 = True
            else:
                print(f"{Colors.RED}错误: 用户的机器既不是 aarch64 架构，也没有安装 qemu-aarch64。{Colors.END}")
                if env.os_name == 'linux':
                    print("在 Ubuntu 上安装: sudo apt-get install qemu-user")
                elif env.os_name == 'macos':
                    print("在 MacOS 上安装: brew install qemu")
                sys.exit(1)

    # 4. 如果需要测试 riscv64
    if 'riscv64' in targets:
        if env.cpu_arch == 'riscv64':
            pass # Native execution
        else:
            if env.os_name == 'linux':
                if check_command('qemu-riscv64'):
                    env.has_qemu_riscv64 = True
                    # Check for gcc toolchain
                    if check_command('riscv64-linux-gnu-gcc'):
                        env.has_riscv_gcc_linux = True
                    else:
                        print(f"{Colors.RED}错误: 未找到 riscv64-linux-gnu-gcc。{Colors.END}")
                        print("在 Ubuntu 上安装: sudo apt-get install gcc-riscv64-linux-gnu")
                        sys.exit(1)
                else:
                    print(f"{Colors.RED}错误: 未找到 qemu-riscv64。{Colors.END}")
                    print("在 Ubuntu 上安装: sudo apt-get install qemu-user")
                    sys.exit(1)
            elif env.os_name == 'macos':
                # Check for spike
                # check if spike is available and is the simulator
                # spike --help might not return 0, just check existence first
                if check_command('spike'):
                    # Verify it's the right spike (RISC-V ISA Simulator)
                    code, out, err = run_command('spike --help')
                    if 'RISC-V ISA Simulator' in err or 'RISC-V ISA Simulator' in out:
                        env.has_spike = True
                        # Also need compiler for spike pk (usually riscv64-unknown-elf-gcc)
                        if check_command('riscv64-unknown-elf-gcc'):
                            env.has_riscv_gcc_elf = True
                        else:
                            # Fallback check for linux-gnu if elf not found?
                            # Usually spike pk uses elf.
                            print(f"{Colors.RED}错误: 未找到 riscv64-unknown-elf-gcc (用于配合 Spike)。{Colors.END}")
                            print("在 MacOS 上安装: brew tap riscv/riscv && brew install riscv-tools")
                            sys.exit(1)
                    else:
                        print(f"{Colors.RED}错误: 找到 'spike' 命令但似乎不是 RISC-V Simulator。{Colors.END}")
                        sys.exit(1)
                else:
                    print(f"{Colors.RED}错误: 未找到 spike 模拟器。{Colors.END}")
                    print("在 MacOS 上安装: brew tap riscv/riscv && brew install riscv-tools")
                    sys.exit(1)

def cleanup_files(*files):
    """清理生成的文件"""
    for f in files:
        if os.path.exists(f):
            try:
                os.remove(f)
            except:
                pass

def test_llvm(mbt_file, filename, ans_file):
    """测试 LLVM IR 后端"""
    ll_file = f"{filename}.ll"
    exe_file = f"{filename}_llvm"
    
    try:
        # 编译到 LLVM IR
        cmd = f"moon run main -- {mbt_file} --emit-llvm -o {ll_file}"
        returncode, stdout, stderr = run_command(cmd)
        if returncode != 0:
            cleanup_files(ll_file, exe_file)
            return False, FailureReason.COMPILE_ERROR
        
        if not os.path.exists(ll_file) or os.path.getsize(ll_file) == 0:
            cleanup_files(ll_file, exe_file)
            return False, FailureReason.COMPILE_ERROR
        
        # 使用 clang 编译
        # LLVM IR 编译为本地机器代码
        cmd = f"clang {ll_file} runtime.c -lm -o {exe_file}"
        returncode, stdout, stderr = run_command(cmd)
        if returncode != 0:
            cleanup_files(ll_file, exe_file)
            return False, FailureReason.ASSEMBLE_ERROR
        
        # 运行
        returncode, output, stderr = run_command(f"./{exe_file}")
        if returncode != 0:
            cleanup_files(ll_file, exe_file)
            return False, FailureReason.RUN_ERROR
        
        # 检查答案文件
        if not os.path.exists(ans_file):
            cleanup_files(ll_file, exe_file)
            return False, FailureReason.NO_ANS_FILE
        
        with open(ans_file, 'r') as f:
            expected = f.read()
        
        # 比较结果
        if output.strip() == expected.strip():
            cleanup_files(ll_file, exe_file)
            return True, None
        else:
            cleanup_files(ll_file, exe_file)
            return False, FailureReason.OUTPUT_MISMATCH
    
    except Exception as e:
        cleanup_files(ll_file, exe_file)
        return False, str(e)

def test_aarch64(mbt_file, filename, ans_file):
    """测试 aarch64 后端"""
    s_file = f"{filename}.s"
    exe_file = f"{filename}_aarch64"
    
    try:
        # 编译到 aarch64 汇编
        cmd = f"moon run main -- {mbt_file} --target=aarch64 -o {s_file}"
        returncode, stdout, stderr = run_command(cmd)
        if returncode != 0:
            cleanup_files(s_file, exe_file)
            return False, FailureReason.COMPILE_ERROR
        
        if not os.path.exists(s_file) or os.path.getsize(s_file) == 0:
            cleanup_files(s_file, exe_file)
            return False, FailureReason.COMPILE_ERROR
        
        # 汇编与链接
        compile_cmd = ""
        run_cmd = ""
        
        if env.cpu_arch == 'aarch64':
            # 本机是 aarch64，直接编译运行
            compile_cmd = f"clang {s_file} runtime.c -lm -o {exe_file}"
            run_cmd = f"./{exe_file}"
        else:
            # 交叉编译
            # 使用 clang 进行交叉编译
            # 注意: 这里假设 clang 支持 --target=aarch64-linux-gnu，并且环境中有相应的库
            # 如果是 MacOS 且 installed via brew, usually works if libraries present.
            # 为了 qemu-user，最好静态链接 (-static)，避免库路径问题
            target_triple = "aarch64-linux-gnu"
            compile_cmd = f"clang --target={target_triple} {s_file} runtime.c -lm -static -o {exe_file}"
            run_cmd = f"qemu-aarch64 ./{exe_file}"

        returncode, stdout, stderr = run_command(compile_cmd)
        if returncode != 0:
            cleanup_files(s_file, exe_file)
            # 尝试不带 -static (MacOS hosts sometimes struggle with static linking linux binaries easily without proper sysroot)
            if "-static" in compile_cmd:
                 compile_cmd = compile_cmd.replace(" -static", "")
                 returncode, stdout, stderr = run_command(compile_cmd)
            
            if returncode != 0:
                return False, f"{FailureReason.ASSEMBLE_ERROR}: {stderr}"
        
        # 运行
        returncode, output, stderr = run_command(run_cmd)
        if returncode != 0:
            cleanup_files(s_file, exe_file)
            return False, f"{FailureReason.RUN_ERROR}: {stderr}"
        
        # 检查答案文件
        if not os.path.exists(ans_file):
            cleanup_files(s_file, exe_file)
            return False, FailureReason.NO_ANS_FILE
        
        with open(ans_file, 'r') as f:
            expected = f.read()
        
        # 比较结果
        if output.strip() == expected.strip():
            cleanup_files(s_file, exe_file)
            return True, None
        else:
            cleanup_files(s_file, exe_file)
            return False, FailureReason.OUTPUT_MISMATCH
    
    except Exception as e:
        cleanup_files(s_file, exe_file)
        return False, str(e)

def test_riscv64(mbt_file, filename, ans_file):
    """测试 riscv64 后端"""
    s_file = f"{filename}.s"
    exe_file = f"{filename}_riscv64"
    
    try:
        # 编译到 riscv64 汇编
        cmd = f"moon run main -- {mbt_file} --target=riscv64 -o {s_file}"
        returncode, stdout, stderr = run_command(cmd)
        if returncode != 0:
            cleanup_files(s_file, exe_file)
            return False, FailureReason.COMPILE_ERROR
        
        if not os.path.exists(s_file) or os.path.getsize(s_file) == 0:
            cleanup_files(s_file, exe_file)
            return False, FailureReason.COMPILE_ERROR
        
        compile_cmd = ""
        run_cmd = ""
        
        if env.cpu_arch == 'riscv64':
            # 本机是 riscv64
            # 优先尝试 gcc
            if check_command('gcc'):
                 compile_cmd = f"gcc -o {exe_file} {s_file} runtime.c -lm"
            elif check_command('riscv64-unknown-elf-gcc'):
                 compile_cmd = f"riscv64-unknown-elf-gcc -o {exe_file} {s_file} runtime.c -lm"
            elif check_command('riscv64-linux-gnu-gcc'):
                 compile_cmd = f"riscv64-linux-gnu-gcc -o {exe_file} {s_file} runtime.c -lm"
            else:
                 return False, "未找到 riscv64 编译器"
            
            run_cmd = f"./{exe_file}"
            
        else:
            # 模拟器环境
            if env.os_name == 'linux':
                # Linux + QEMU
                compile_cmd = f"riscv64-linux-gnu-gcc -o {exe_file} {s_file} runtime.c -lm -static"
                run_cmd = f"qemu-riscv64 ./{exe_file}"
            elif env.os_name == 'macos':
                # MacOS + Spike
                # Spike 通常与 pk (proxy kernel) 一起使用，程序通常编译为 bare-metal elf
                compile_cmd = f"riscv64-unknown-elf-gcc -o {exe_file} {s_file} runtime.c -lm"
                run_cmd = f"spike pk {exe_file}"

        # 编译
        returncode, stdout, stderr = run_command(compile_cmd)
        if returncode != 0:
            cleanup_files(s_file, exe_file)
            return False, f"{FailureReason.ASSEMBLE_ERROR}: {stderr}"
        
        # 运行
        returncode, output, stderr = run_command(run_cmd)
        if returncode != 0:
            cleanup_files(s_file, exe_file)
            return False, f"{FailureReason.RUN_ERROR}: {stderr}"
        
        # 检查答案文件
        if not os.path.exists(ans_file):
            cleanup_files(s_file, exe_file)
            return False, FailureReason.NO_ANS_FILE
        
        with open(ans_file, 'r') as f:
            expected = f.read()
        
        # 比较结果
        if output.strip() == expected.strip():
            cleanup_files(s_file, exe_file)
            return True, None
        else:
            cleanup_files(s_file, exe_file)
            return False, FailureReason.OUTPUT_MISMATCH
    
    except Exception as e:
        cleanup_files(s_file, exe_file)
        return False, str(e)

def test_file(mbt_file, targets):
    """测试单个文件的指定后端"""
    basename = os.path.basename(mbt_file)
    filename = os.path.splitext(basename)[0]
    ans_file = f"ans/{filename}.ans"
    
    results = {}
    
    for target in targets:
        if target == "llvm":
            success, reason = test_llvm(mbt_file, filename, ans_file)
        elif target == "aarch64":
            success, reason = test_aarch64(mbt_file, filename, ans_file)
        elif target == "riscv64":
            success, reason = test_riscv64(mbt_file, filename, ans_file)
        else:
            success, reason = False, "未知目标"
        
        results[target] = (success, reason)
    
    return results

def print_help():
    """打印帮助信息"""
    help_text = f"""
{Colors.BOLD}MiniMoonBit 多后端测试脚本{Colors.END}

用法:
    python3 test.py [OPTIONS]

选项:
    --target=BACKEND    指定测试的后端，可以使用多次
                        可选值: llvm, aarch64, riscv64, all
    -f FILE             指定要测试的单个文件
    --help, -h          显示此帮助信息

示例:
    python3 test.py --target=llvm
    python3 test.py --target=aarch64 --target=riscv64
    python3 test.py --target=all
    python3 test.py -f examples/ack.mbt --target=all
"""
    print(help_text)

def main():
    """主函数"""
    # 检查是否需要显示帮助
    if len(sys.argv) == 1 or '--help' in sys.argv or '-h' in sys.argv:
        print_help()
        return 0
    
    # 解析命令行参数
    targets = []
    test_file_path = None
    i = 1
    while i < len(sys.argv):
        arg = sys.argv[i]
        if arg.startswith('--target='):
            target = arg.split('=', 1)[1]
            if target == 'all':
                targets = ['llvm', 'aarch64', 'riscv64']
            elif target in ['llvm', 'aarch64', 'riscv64']:
                if target not in targets:
                    targets.append(target)
            else:
                print(f"{Colors.RED}错误: 未知的目标 '{target}'{Colors.END}")
                print_help()
                return 1
        elif arg == '-f':
            if i + 1 < len(sys.argv):
                test_file_path = sys.argv[i + 1]
                i += 1
            else:
                print(f"{Colors.RED}错误: -f 选项需要指定文件路径{Colors.END}")
                print_help()
                return 1
        i += 1
    
    if not targets:
        print(f"{Colors.RED}错误: 未指定测试目标{Colors.END}")
        print_help()
        return 1
    
    # 检测环境
    detect_environment(targets)
    
    # 检查必要的文件和目录
    if not os.path.exists("ans"):
        print(f"{Colors.RED}错误: 找不到 ans 目录{Colors.END}")
        return 1
    
    if not os.path.exists("runtime.c"):
        print(f"{Colors.RED}错误: 找不到 runtime.c 文件{Colors.END}")
        return 1
    
    # 获取要测试的 .mbt 文件
    if test_file_path:
        # 测试单个文件
        if not os.path.exists(test_file_path):
            print(f"{Colors.RED}错误: 找不到文件 '{test_file_path}'{Colors.END}")
            return 1
        if not test_file_path.endswith('.mbt'):
            print(f"{Colors.RED}错误: 文件必须是 .mbt 文件{Colors.END}")
            return 1
        mbt_files = [test_file_path]
    else:
        # 测试所有文件
        if not os.path.exists("examples"):
            print(f"{Colors.RED}错误: 找不到 examples 目录{Colors.END}")
            return 1
        mbt_files = sorted(glob.glob("examples/*.mbt"))
        if not mbt_files:
            print(f"{Colors.YELLOW}警告: examples 目录下没有 .mbt 文件{Colors.END}")
            return 0
    
    print(f"{Colors.BOLD}测试后端: {', '.join(targets)}{Colors.END}")
    print(f"测试文件: {len(mbt_files)} 个\n")
    
    # 运行测试
    all_passed = True
    failures = []
    
    for mbt_file in mbt_files:
        basename = os.path.basename(mbt_file)
        results = test_file(mbt_file, targets)
        
        # 检查所有目标是否都通过
        all_targets_passed = all(success for success, _ in results.values())
        
        if all_targets_passed:
            print(f"{Colors.GREEN}✓{Colors.END} {basename}")
        else:
            print(f"{Colors.RED}✗{Colors.END} {basename}")
            all_passed = False
            for target, (success, reason) in results.items():
                if not success:
                    print(f"  - {target}: {reason}")
                    failures.append((basename, target, reason))
    
    # 输出总结
    print(f"\n{Colors.BOLD}{'='*50}{Colors.END}")
    if all_passed:
        print(f"{Colors.GREEN}{Colors.BOLD}All Tests Passed{Colors.END}")
        return 0
    else:
        print(f"{Colors.RED}{Colors.BOLD}Some Tests Failed{Colors.END}")
        print(f"\n失败详情:")
        for filename, target, reason in failures:
            print(f"  {filename} [{target}]: {reason}")
        return 1

if __name__ == "__main__":
    sys.exit(main())
