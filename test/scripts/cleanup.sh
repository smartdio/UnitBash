#!/bin/bash

# 清理脚本
# ===================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_ROOT="$(dirname "$SCRIPT_DIR")"

# 导入公共库
source "$TEST_ROOT/common/lib.sh"

echo "UnitBash 环境清理"
echo "=================="

print_info "开始清理测试环境..."

# 清理会话文件
if [[ -d "$TEST_ROOT/.session" ]]; then
    print_info "清理会话文件..."
    rm -rf "$TEST_ROOT/.session"/*
    print_success "会话文件清理完成"
fi

# 清理日志文件
if [[ -d "$TEST_ROOT/logs" ]]; then
    print_info "清理日志文件..."
    find "$TEST_ROOT/logs" -name "*.log" -type f -mtime +7 -delete
    print_success "旧日志文件清理完成"
fi

# 清理临时文件
print_info "清理临时文件..."
find "$TEST_ROOT" -name "*.tmp" -type f -delete 2>/dev/null || true
find "$TEST_ROOT" -name ".DS_Store" -type f -delete 2>/dev/null || true
find "/tmp" -name "unitbash_*" -type f -delete 2>/dev/null || true

# 清理测试报告（可选）
if [[ "$1" == "--reports" ]]; then
    if [[ -d "$TEST_ROOT/reports" ]]; then
        print_info "清理测试报告..."
        rm -rf "$TEST_ROOT/reports"/*
        print_success "测试报告清理完成"
    fi
fi

# 清理下载的文件（如果有）
if [[ -d "$TEST_ROOT/downloads" ]]; then
    print_info "清理下载文件..."
    rm -rf "$TEST_ROOT/downloads"/*
    print_success "下载文件清理完成"
fi

print_success "环境清理完成！"

print_info "清理选项:"
echo "  $0                # 清理基本文件（会话、日志、临时文件）"
echo "  $0 --reports      # 同时清理测试报告"