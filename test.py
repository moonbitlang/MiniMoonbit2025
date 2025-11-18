#!/usr/bin/env python3
"""
MiniMoonBit 多后端测试脚本

支持测试 llvm IR, aarch64 和 riscv64 三个编译后端
"""

import os
import sys
import subprocess
import glob
import argparse
from pathlib import Path

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
    exe_file = f"{filename}"
    
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
    exe_file = f"{filename}"
    
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
        
        # 使用 clang 编译
        cmd = f"clang {s_file} runtime.c -lm -o {exe_file}"
        returncode, stdout, stderr = run_command(cmd)
        if returncode != 0:
            cleanup_files(s_file, exe_file)
            return False, FailureReason.ASSEMBLE_ERROR
        
        # 运行
        returncode, output, stderr = run_command(f"./{exe_file}")
        if returncode != 0:
            cleanup_files(s_file, exe_file)
            return False, FailureReason.RUN_ERROR
        
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
    exe_file = f"{filename}"
    
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
        
        # 使用 riscv64-unknown-elf-gcc 编译
        cmd = f"riscv64-unknown-elf-gcc -o {exe_file} {s_file} runtime.c -lm"
        returncode, stdout, stderr = run_command(cmd)
        if returncode != 0:
            cleanup_files(s_file, exe_file)
            return False, FailureReason.ASSEMBLE_ERROR
        
        # 使用 spike 运行
        returncode, output, stderr = run_command(f"spike pk {exe_file}")
        if returncode != 0:
            cleanup_files(s_file, exe_file)
            return False, FailureReason.RUN_ERROR
        
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
    python test.py [OPTIONS]

选项:
    --target=BACKEND    指定测试的后端，可以使用多次
                        可选值: llvm, aarch64, riscv64, all
    --help, -h          显示此帮助信息

示例:
    python test2.py --target=llvm
    python test2.py --target=aarch64 --target=riscv64
    python test2.py --target=all
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
    for arg in sys.argv[1:]:
        if arg.startswith('--target='):
            target = arg.split('=', 1)[1]
            if target == 'all':
                targets = ['llvm', 'aarch64', 'riscv64']
                break
            elif target in ['llvm', 'aarch64', 'riscv64']:
                if target not in targets:
                    targets.append(target)
            else:
                print(f"{Colors.RED}错误: 未知的目标 '{target}'{Colors.END}")
                print_help()
                return 1
    
    if not targets:
        print(f"{Colors.RED}错误: 未指定测试目标{Colors.END}")
        print_help()
        return 1
    
    # 检查必要的文件和目录
    if not os.path.exists("examples"):
        print(f"{Colors.RED}错误: 找不到 examples 目录{Colors.END}")
        return 1
    
    if not os.path.exists("ans"):
        print(f"{Colors.RED}错误: 找不到 ans 目录{Colors.END}")
        return 1
    
    if not os.path.exists("runtime.c"):
        print(f"{Colors.RED}错误: 找不到 runtime.c 文件{Colors.END}")
        return 1
    
    # 获取所有 .mbt 文件
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

