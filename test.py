#!/usr/bin/env python3
"""
MiniMoonBit 编译器测试脚本

对 examples 目录下的每个 .mbt 文件进行编译、运行和结果验证
"""

import os
import sys
import subprocess
import glob
from pathlib import Path

# 颜色输出
class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    END = '\033[0m'
    BOLD = '\033[1m'

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
            except Exception as e:
                print(f"{Colors.YELLOW}警告: 无法删除文件 {f}: {e}{Colors.END}")

def test_file(mbt_file):
    """测试单个 .mbt 文件"""
    # 获取文件名（不带扩展名）
    basename = os.path.basename(mbt_file)
    filename = os.path.splitext(basename)[0]
    
    print(f"{Colors.BLUE}测试: {basename}{Colors.END}")
    
    # 定义文件路径
    ll_file = f"{filename}.ll"
    exe_file = f"{filename}"
    ans_file = f"ans/{filename}.ans"
    
    try:
        # 步骤 1: 编译到 LLVM IR
        compile_cmd = f"moon run main -- {mbt_file} -emit-llvm -o {ll_file}"
        print(f"  编译: {compile_cmd}")
        returncode, stdout, stderr = run_command(compile_cmd)
        
        if returncode != 0:
            print(f"{Colors.RED}  ✗ 编译失败{Colors.END}")
            if stderr:
                print(f"    错误: {stderr}")
            cleanup_files(ll_file, exe_file)
            return False
        
        # 检查 .ll 文件是否生成
        if not os.path.exists(ll_file) or os.path.getsize(ll_file) == 0:
            print(f"{Colors.RED}  ✗ 未生成 LLVM IR 文件{Colors.END}")
            cleanup_files(ll_file, exe_file)
            return False
        
        # 步骤 2: 使用 clang 编译
        # clang_cmd = f"clang {ll_file} runtime.c -I/opt/homebrew/opt/bdw-gc/include -L/opt/homebrew/opt/bdw-gc/lib -lgc -lm -o {exe_file}"
        clang_cmd = f"clang {ll_file} runtime.c -lm -o {exe_file}"
        print(f"  链接: {clang_cmd}")
        returncode, stdout, stderr = run_command(clang_cmd)
        
        if returncode != 0:
            print(f"{Colors.RED}  ✗ clang 编译失败{Colors.END}")
            if stderr:
                print(f"    错误: {stderr}")
            cleanup_files(ll_file, exe_file)
            return False
        
        # 步骤 3: 运行可执行文件
        run_cmd = f"./{exe_file}"
        print(f"  运行: {run_cmd}")
        returncode, output, stderr = run_command(run_cmd)
        
        if returncode != 0:
            print(f"{Colors.RED}  ✗ 运行失败{Colors.END}")
            if stderr:
                print(f"    错误: {stderr}")
            cleanup_files(ll_file, exe_file)
            return False
        
        # 步骤 4: 读取预期结果
        if not os.path.exists(ans_file):
            print(f"{Colors.YELLOW}  ⚠ 警告: 找不到答案文件 {ans_file}{Colors.END}")
            cleanup_files(ll_file, exe_file)
            return False
        
        with open(ans_file, 'r') as f:
            expected = f.read()
        
        # 步骤 5: 比较结果
        # 去除首尾空白字符进行比较
        output_stripped = output.strip()
        expected_stripped = expected.strip()
        
        if output_stripped == expected_stripped:
            print(f"{Colors.GREEN}  ✓ 测试通过{Colors.END}")
            cleanup_files(ll_file, exe_file)
            return True
        else:
            print(f"{Colors.RED}  ✗ 输出不匹配{Colors.END}")
            print(f"    预期输出:")
            for line in expected_stripped.split('\n')[:5]:  # 只显示前5行
                print(f"      {line}")
            if len(expected_stripped.split('\n')) > 5:
                print(f"      ...")
            print(f"    实际输出:")
            for line in output_stripped.split('\n')[:5]:  # 只显示前5行
                print(f"      {line}")
            if len(output_stripped.split('\n')) > 5:
                print(f"      ...")
            cleanup_files(ll_file, exe_file)
            return False
    
    except Exception as e:
        print(f"{Colors.RED}  ✗ 异常: {e}{Colors.END}")
        cleanup_files(ll_file, exe_file)
        return False

def main():
    """主函数"""
    print(f"{Colors.BOLD}=== MiniMoonBit 编译器测试 ==={Colors.END}\n")
    
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
    
    print(f"找到 {len(mbt_files)} 个测试文件\n")
    
    # 运行测试
    passed = 0
    failed = 0
    
    for mbt_file in mbt_files:
        if test_file(mbt_file):
            passed += 1
        else:
            failed += 1
        print()  # 空行分隔
    
    # 输出总结
    print(f"{Colors.BOLD}=== 测试总结 ==={Colors.END}")
    print(f"总计: {len(mbt_files)}")
    print(f"{Colors.GREEN}通过: {passed}{Colors.END}")
    print(f"{Colors.RED}失败: {failed}{Colors.END}")
    
    if failed == 0:
        print(f"\n{Colors.GREEN}{Colors.BOLD}✓ 所有测试通过！{Colors.END}")
        return 0
    else:
        print(f"\n{Colors.RED}{Colors.BOLD}✗ 有 {failed} 个测试失败{Colors.END}")
        return 1

if __name__ == "__main__":
    sys.exit(main())

