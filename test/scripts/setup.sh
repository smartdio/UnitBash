#!/bin/bash

# 环境初始化脚本
# ===================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_ROOT="$(dirname "$SCRIPT_DIR")"

echo "UnitBash 环境初始化"
echo "==================="

# 导入公共库
source "$TEST_ROOT/common/lib.sh"
source "$TEST_ROOT/common/config.sh"

# 检查必需的命令
print_info "检查必需的命令..."
if check_required_commands; then
    print_success "所有必需命令都已安装"
else
    print_error "请安装缺失的命令后重试"
    exit 1
fi

# 创建必要的目录
print_info "创建必要的目录..."
ensure_dir "$TEST_ROOT/logs"
ensure_dir "$TEST_ROOT/.session"
ensure_dir "$TEST_ROOT/reports"

# 检查配置文件
print_info "检查配置文件..."
if [[ ! -f "$TEST_ROOT/config/base.conf" ]]; then
    print_error "基础配置文件不存在: config/base.conf"
    exit 1
fi

# 设置环境
ENVIRONMENT="${ENVIRONMENT:-dev}"
print_info "当前环境: $ENVIRONMENT"

# 加载配置
if load_config "$ENVIRONMENT"; then
    print_success "配置加载成功"
else
    print_error "配置加载失败"
    exit 1
fi

# 验证配置
if validate_config; then
    print_success "配置验证通过"
else
    print_error "配置验证失败"
    exit 1
fi

# 显示当前配置信息
echo ""
show_config

# 创建环境变量文件（如果不存在）
if [[ ! -f "$TEST_ROOT/config/.env" && -f "$TEST_ROOT/config/env.example" ]]; then
    print_info "创建环境变量文件..."
    cp "$TEST_ROOT/config/env.example" "$TEST_ROOT/config/.env"
    print_warning "请编辑 config/.env 文件并填入实际的环境变量值"
fi

# 设置文件权限
print_info "设置文件权限..."
find "$TEST_ROOT" -name "*.sh" -type f -exec chmod +x {} \;

print_success "环境初始化完成！"
echo ""
print_info "使用方法:"
echo "  1. 编辑配置文件 config/${ENVIRONMENT}.conf"
echo "  2. 设置环境变量 config/.env"
echo "  3. 运行测试: ./scripts/run_all.sh"
echo "  4. 查看日志: logs/test.log"