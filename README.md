# UnitBash - 通用CURL测试脚本框架

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Bash](https://img.shields.io/badge/bash-4.0%2B-green.svg)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS-lightgrey.svg)

UnitBash是一个通用的CURL测试脚本框架，专门为API单元测试设计。它提供了标准化、可复用的bash脚本工具集，支持多种认证方式、RESTful API测试、文件上传测试等功能。

## ✨ 特性

- 🔐 **多种认证支持** - JWT、Basic Auth、API Key、Session认证
- 🌐 **RESTful API测试** - 支持GET、POST、PUT、DELETE、PATCH等HTTP方法
- 📁 **文件上传测试** - 单文件/多文件上传支持
- ⚙️ **灵活配置** - 多环境配置，支持开发、测试、生产环境
- 📊 **响应验证** - 丰富的响应验证机制
- 🔄 **可复用设计** - 可轻松复制到其他项目使用
- 📝 **详细日志** - 完善的日志记录和错误处理
- 🔧 **模块化设计** - 清晰的模块结构，易于扩展和维护

## 📋 系统要求

- **Bash**: 4.0+
- **必需命令**: `curl`, `jq`, `grep`, `sed`, `awk`
- **操作系统**: Linux, macOS
- **可选工具**: `bc` (用于数值计算)

### 安装依赖

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install curl jq grep sed gawk bc
```

**CentOS/RHEL:**
```bash
sudo yum install curl jq grep sed gawk bc
```

**macOS:**
```bash
brew install curl jq grep gnu-sed gawk bc
```

## 🚀 快速开始

### 1. 项目初始化

```bash
# 复制test目录到你的项目
cp -r UnitBash/test /path/to/your/project/

# 进入测试目录
cd /path/to/your/project/test

# 运行初始化脚本
./scripts/setup.sh
```

### 2. 配置环境

编辑配置文件以适配你的API：

```bash
# 编辑基础配置
vim config/base.conf

# 编辑开发环境配置
vim config/dev.conf

# 设置环境变量
cp config/env.example config/.env
vim config/.env
```

### 3. 运行测试

```bash
# 运行所有测试
./scripts/run_all.sh

# 运行特定环境的测试
./scripts/run_all.sh --env test

# 运行特定模块的测试
./scripts/run_all.sh system

# 并行执行测试
./scripts/run_all.sh --parallel

# 生成测试报告
./scripts/run_all.sh --report results.json
```

## 📁 目录结构

```
test/                   # 测试根目录
├── config/            # 配置文件
│   ├── base.conf      # 基础配置
│   ├── dev.conf       # 开发环境配置
│   ├── test.conf      # 测试环境配置
│   ├── prod.conf      # 生产环境配置
│   └── env.example    # 环境变量示例
├── mock/              # 测试模拟数据
│   ├── users.json     # 用户测试数据
│   ├── files/         # 测试用文件
│   └── responses/     # 模拟响应数据
├── common/            # 通用库文件
│   ├── auth.sh        # 认证相关函数
│   ├── data.sh        # 数据处理函数
│   ├── lib.sh         # 通用工具函数
│   ├── http.sh        # HTTP请求封装
│   ├── validate.sh    # 响应验证函数
│   └── config.sh      # 配置管理函数
├── system/            # 系统级单元测试
│   ├── test_auth.sh   # 认证测试
│   └── test_user.sh   # 用户管理测试
├── modules/           # 业务模块测试
│   ├── user/          # 用户模块
│   ├── order/         # 订单模块
│   └── product/       # 产品模块
└── scripts/           # 辅助脚本
    ├── setup.sh       # 环境初始化
    ├── run_all.sh     # 批量执行
    └── cleanup.sh     # 清理脚本
```

## ⚙️ 配置说明

### 基础配置 (config/base.conf)

```bash
# API基础配置
API_BASE_URL="https://api.example.com"
API_VERSION="v1"
API_TIMEOUT=30
API_RETRY_COUNT=3

# 认证配置
AUTH_LOGIN_URL="/auth/login"
AUTH_USERNAME_FIELD="username"
AUTH_PASSWORD_FIELD="password"
AUTH_CONTENT_TYPE="application/json"

# JWT配置
JWT_TOKEN_FIELD="access_token"
JWT_TOKEN_TYPE="Bearer"
JWT_EXPIRES_FIELD="expires_in"

# 响应配置
SUCCESS_STATUS_CODES="200,201,204"
SUCCESS_RESPONSE_FIELD="success"
ERROR_MESSAGE_FIELD="message"
DATA_FIELD="data"
```

### 环境变量 (config/.env)

```bash
# 敏感信息
PROD_USERNAME=your_username
PROD_PASSWORD=your_password
API_KEY=your_api_key
JWT_SECRET=your_jwt_secret
```

## 🔧 使用示例

### 认证示例

```bash
#!/bin/bash
source "common/auth.sh"

# 初始化认证模块
init_auth

# 用户名密码登录
login_with_password "admin" "password123"

# API Key认证
set_api_key "your_api_key" "X-API-Key"

# Basic认证
set_basic_auth "username" "password"

# 检查认证状态
show_auth_status
```

### HTTP请求示例

```bash
#!/bin/bash
source "common/http.sh"
source "common/auth.sh"

# 确保已认证
ensure_authenticated

# GET请求
http_get "$(get_api_url '/users')" "page=1&limit=10"

# POST请求
user_data='{"username":"test","email":"test@example.com"}'
http_post "$(get_api_url '/users')" "$user_data" "Content-Type: application/json"

# 文件上传
http_upload "$(get_api_url '/upload')" "/path/to/file.jpg" "avatar"

# 获取响应
response_body=$(get_response_body)
status_code=$(get_status_code)
```

### 响应验证示例

```bash
#!/bin/bash
source "common/validate.sh"

# 状态码验证
validate_status_code "200"
validate_status_code_in "200,201,204"

# JSON验证
validate_json_response
validate_json_field_exists ".data.id"
validate_json_field_value ".data.username" "admin"
validate_json_field_type ".data.age" "number"

# 标准响应验证
validate_success_response
validate_error_response

# 组合验证
run_validations \
    "validate_status_code 200" \
    "validate_json_field_exists .data" \
    "validate_json_field_type .data.users array"
```

### 数据生成示例

```bash
#!/bin/bash
source "common/data.sh"

# 生成测试用户
user_data=$(generate_user_data "testuser" "example.com")

# 生成测试产品
product_data=$(generate_product_data "测试产品" "电子产品")

# 从模拟数据中获取随机项
random_user=$(get_random_mock_item "users")

# 创建分页数据
paginated_data=$(create_paginated_data "$users_array" 1 10)
```

## 📝 编写测试脚本

### 基本测试脚本模板

```bash
#!/bin/bash

# 测试脚本标题
# ===================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_ROOT="$(dirname "$SCRIPT_DIR")"

# 导入测试框架
source "$TEST_ROOT/common/lib.sh"
source "$TEST_ROOT/common/config.sh"
source "$TEST_ROOT/common/http.sh"
source "$TEST_ROOT/common/auth.sh"
source "$TEST_ROOT/common/validate.sh"
source "$TEST_ROOT/common/data.sh"

# 测试计数器
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 测试结果记录
test_result() {
    local test_name="$1"
    local result="$2"
    
    ((TOTAL_TESTS++))
    
    if [[ "$result" == "PASS" ]]; then
        ((PASSED_TESTS++))
        print_success "✓ $test_name"
    else
        ((FAILED_TESTS++))
        print_error "✗ $test_name"
    fi
}

# 测试用例
test_example() {
    print_info "测试: 示例测试"
    
    # 测试逻辑
    if some_condition; then
        test_result "示例测试" "PASS"
    else
        test_result "示例测试" "FAIL"
    fi
}

# 主函数
main() {
    echo "测试标题"
    echo "========"
    
    # 确保配置已加载
    ensure_config_loaded || {
        print_error "配置加载失败"
        exit 1
    }
    
    # 运行测试
    test_example
    
    # 显示结果
    echo ""
    echo "测试结果总结"
    echo "============"
    echo "总测试数: $TOTAL_TESTS"
    echo "通过: $PASSED_TESTS"
    echo "失败: $FAILED_TESTS"
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        print_success "所有测试都通过了！"
        exit 0
    else
        print_error "$FAILED_TESTS 个测试失败"
        exit 1
    fi
}

# 清理函数
cleanup() {
    cleanup_http
}

# 设置清理陷阱
trap cleanup EXIT

# 运行测试
main "$@"
```

## 🔌 集成到CI/CD

### GitHub Actions示例

```yaml
name: API Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v2
    
    - name: Install dependencies
      run: |
        sudo apt update
        sudo apt install curl jq bc
    
    - name: Setup test environment
      run: |
        cd test
        ./scripts/setup.sh
    
    - name: Run tests
      env:
        API_BASE_URL: ${{ secrets.API_BASE_URL }}
        TEST_USERNAME: ${{ secrets.TEST_USERNAME }}
        TEST_PASSWORD: ${{ secrets.TEST_PASSWORD }}
      run: |
        cd test
        ./scripts/run_all.sh --env test --report results.json
    
    - name: Upload test results
      uses: actions/upload-artifact@v2
      if: always()
      with:
        name: test-results
        path: test/results.json
```

### Jenkins Pipeline示例

```groovy
pipeline {
    agent any
    
    environment {
        API_BASE_URL = credentials('api-base-url')
        TEST_USERNAME = credentials('test-username')
        TEST_PASSWORD = credentials('test-password')
    }
    
    stages {
        stage('Setup') {
            steps {
                sh '''
                    cd test
                    ./scripts/setup.sh
                '''
            }
        }
        
        stage('Test') {
            steps {
                sh '''
                    cd test
                    ./scripts/run_all.sh --env test --report results.json
                '''
            }
        }
    }
    
    post {
        always {
            archiveArtifacts artifacts: 'test/results.json', fingerprint: true
            publishHTML([
                allowMissing: false,
                alwaysLinkToLastBuild: true,
                keepAll: true,
                reportDir: 'test',
                reportFiles: 'results.json',
                reportName: 'API Test Report'
            ])
        }
    }
}
```

## 🛠️ 高级功能

### 自定义验证函数

```bash
# 在validate.sh中添加自定义验证
validate_custom_format() {
    local field_path="$1"
    local expected_pattern="$2"
    local response_body
    response_body=$(get_response_body)
    
    local field_value
    field_value=$(json_extract "$response_body" "$field_path")
    
    if [[ "$field_value" =~ $expected_pattern ]]; then
        print_success "自定义格式验证通过: $field_path"
        return 0
    else
        print_error "自定义格式验证失败: $field_path"
        return 1
    fi
}
```

### 性能测试

```bash
# 性能测试示例
test_performance() {
    local start_time=$(date +%s.%N)
    
    # 执行API调用
    http_get "$(get_api_url '/users')"
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)
    
    # 验证响应时间小于1秒
    if (( $(echo "$duration < 1.0" | bc -l) )); then
        test_result "响应时间测试" "PASS"
    else
        test_result "响应时间测试" "FAIL"
    fi
}
```

### 数据驱动测试

```bash
# 数据驱动测试示例
test_with_data_file() {
    local test_data_file="$MOCK_DATA_DIR/test_cases.json"
    local test_cases
    test_cases=$(cat "$test_data_file")
    
    local case_count
    case_count=$(echo "$test_cases" | jq 'length')
    
    for ((i=0; i<case_count; i++)); do
        local test_case
        test_case=$(echo "$test_cases" | jq ".[$i]")
        
        local input
        input=$(echo "$test_case" | jq -r '.input')
        local expected
        expected=$(echo "$test_case" | jq -r '.expected')
        
        # 执行测试用例
        run_test_case "$input" "$expected"
    done
}
```

## 🐛 故障排除

### 常见问题

1. **命令不存在错误**
   ```bash
   # 检查必需命令
   ./scripts/setup.sh
   ```

2. **配置加载失败**
   ```bash
   # 检查配置文件语法
   bash -n config/base.conf
   ```

3. **认证失败**
   ```bash
   # 检查认证配置
   source common/auth.sh
   show_auth_status
   ```

4. **JSON解析错误**
   ```bash
   # 验证JSON格式
   echo "$response" | jq .
   ```

### 调试模式

```bash
# 启用详细输出
export VERBOSE=true
export LOG_LEVEL=DEBUG

# 运行测试
./scripts/run_all.sh --verbose
```

### 日志查看

```bash
# 查看最新日志
tail -f logs/test.log

# 查看错误日志
grep ERROR logs/test.log
```

## 🤝 贡献指南

1. Fork 项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 🙏 致谢

- [curl](https://curl.se/) - HTTP客户端工具
- [jq](https://stedolan.github.io/jq/) - JSON处理工具
- Bash社区的贡献者们

## 📞 支持

如果你在使用过程中遇到问题或有建议，请：

1. 查看 [故障排除](#-故障排除) 部分
2. 搜索已有的 [Issues](../../issues)
3. 创建新的 [Issue](../../issues/new)

---

**UnitBash** - 让API测试更简单、更标准化！ 🚀