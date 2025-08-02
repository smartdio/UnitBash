#!/bin/bash

# UnitBash 项目演示脚本
# ===================================

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "UnitBash 项目演示"
echo "================="

# 检查必需的命令
check_dependencies() {
    local missing_deps=()
    local required_commands=("curl" "jq" "grep" "sed" "awk")
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo "❌ 缺少必需的命令: ${missing_deps[*]}"
        echo ""
        echo "请安装缺少的命令:"
        echo "Ubuntu/Debian: sudo apt install curl jq grep sed gawk"
        echo "CentOS/RHEL:   sudo yum install curl jq grep sed gawk"
        echo "macOS:         brew install curl jq grep gnu-sed gawk"
        exit 1
    else
        echo "✅ 所有必需命令都已安装"
    fi
}

# 显示项目结构
show_project_structure() {
    echo ""
    echo "📁 项目结构:"
    echo "============"
    
    if command -v tree &> /dev/null; then
        tree "$PROJECT_ROOT" -I "__pycache__|*.pyc|.git|.DS_Store"
    else
        find "$PROJECT_ROOT" -type f -name "*.sh" -o -name "*.conf" -o -name "*.json" -o -name "*.md" | \
        grep -E "(test/|README|LICENSE)" | \
        sort | \
        sed "s|$PROJECT_ROOT||" | \
        sed 's|^|  |'
    fi
}

# 显示核心功能
show_core_features() {
    echo ""
    echo "🚀 核心功能:"
    echo "============"
    echo "✅ 多种认证方式支持 (JWT, Basic Auth, API Key)"
    echo "✅ RESTful API测试 (GET, POST, PUT, DELETE, PATCH)"
    echo "✅ 文件上传测试支持"
    echo "✅ 响应验证机制"
    echo "✅ 多环境配置支持"
    echo "✅ 模块化设计"
    echo "✅ 并行测试执行"
    echo "✅ 测试报告生成"
    echo "✅ CI/CD集成支持"
}

# 显示配置示例
show_configuration_example() {
    echo ""
    echo "⚙️ 配置示例:"
    echo "============="
    echo "# 基础配置 (test/config/base.conf)"
    echo "API_BASE_URL=\"https://api.example.com\""
    echo "AUTH_LOGIN_URL=\"/auth/login\""
    echo "JWT_TOKEN_FIELD=\"access_token\""
    echo "SUCCESS_STATUS_CODES=\"200,201,204\""
    echo ""
    echo "# 环境变量 (test/config/.env)"
    echo "PROD_USERNAME=your_username"
    echo "PROD_PASSWORD=your_password"
    echo "API_KEY=your_api_key"
}

# 显示使用示例
show_usage_examples() {
    echo ""
    echo "💡 使用示例:"
    echo "============"
    echo "# 1. 初始化项目"
    echo "cd test && ./scripts/setup.sh"
    echo ""
    echo "# 2. 运行所有测试"
    echo "./scripts/run_all.sh"
    echo ""
    echo "# 3. 运行特定环境测试"
    echo "./scripts/run_all.sh --env test"
    echo ""
    echo "# 4. 并行执行测试"
    echo "./scripts/run_all.sh --parallel"
    echo ""
    echo "# 5. 生成测试报告"
    echo "./scripts/run_all.sh --report results.json"
    echo ""
    echo "# 6. 运行单个测试模块"
    echo "./scripts/run_all.sh system"
}

# 显示脚本示例
show_script_example() {
    echo ""
    echo "📝 测试脚本示例:"
    echo "================"
    cat << 'EOF'
#!/bin/bash
source "common/auth.sh"
source "common/http.sh"
source "common/validate.sh"

# 登录
login_with_password "admin" "password123"

# 发送API请求
http_get "$(get_api_url '/users')" "page=1&limit=10"

# 验证响应
validate_success_response
validate_json_field_exists ".data"
validate_status_code "200"

echo "测试完成！"
EOF
}

# 演示文件验证
validate_project_files() {
    echo ""
    echo "🔍 验证项目文件:"
    echo "==============="
    
    local required_files=(
        "test/config/base.conf"
        "test/common/lib.sh"
        "test/common/auth.sh"
        "test/common/http.sh"
        "test/scripts/setup.sh"
        "test/scripts/run_all.sh"
        "README.md"
    )
    
    local missing_files=()
    
    for file in "${required_files[@]}"; do
        if [[ -f "$PROJECT_ROOT/$file" ]]; then
            echo "✅ $file"
        else
            echo "❌ $file (缺失)"
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -eq 0 ]]; then
        echo ""
        echo "✅ 所有核心文件都存在！"
    else
        echo ""
        echo "❌ 发现 ${#missing_files[@]} 个缺失文件"
        return 1
    fi
}

# 运行语法检查
run_syntax_check() {
    echo ""
    echo "🔧 语法检查:"
    echo "==========="
    
    local script_files=()
    while IFS= read -r -d '' file; do
        script_files+=("$file")
    done < <(find "$PROJECT_ROOT/test" -name "*.sh" -type f -print0)
    
    local syntax_errors=0
    
    for script in "${script_files[@]}"; do
        local relative_path="${script#$PROJECT_ROOT/}"
        if bash -n "$script" 2>/dev/null; then
            echo "✅ $relative_path"
        else
            echo "❌ $relative_path (语法错误)"
            ((syntax_errors++))
        fi
    done
    
    if [[ $syntax_errors -eq 0 ]]; then
        echo ""
        echo "✅ 所有脚本语法检查通过！"
    else
        echo ""
        echo "❌ 发现 $syntax_errors 个语法错误"
        return 1
    fi
}

# 显示快速开始指南
show_quick_start() {
    echo ""
    echo "🚀 快速开始:"
    echo "==========="
    echo "1. 复制test目录到你的项目:"
    echo "   cp -r UnitBash/test /path/to/your/project/"
    echo ""
    echo "2. 配置API信息:"
    echo "   cd /path/to/your/project/test"
    echo "   vim config/dev.conf"
    echo ""
    echo "3. 运行初始化脚本:"
    echo "   ./scripts/setup.sh"
    echo ""
    echo "4. 开始测试:"
    echo "   ./scripts/run_all.sh"
    echo ""
    echo "更多信息请查看 README.md 文件"
}

# 主函数
main() {
    check_dependencies
    show_project_structure
    show_core_features
    show_configuration_example
    show_usage_examples
    show_script_example
    validate_project_files
    run_syntax_check
    show_quick_start
    
    echo ""
    echo "🎉 UnitBash 项目演示完成！"
    echo "更多详细信息请参考 README.md"
}

# 运行演示
main "$@"