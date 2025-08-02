# UnitBash 测试框架使用指南

这是UnitBash通用CURL测试脚本框架的核心目录。将此目录复制到您的项目中即可快速开始API测试。

## 🚀 快速开始

### 1. 复制到项目
```bash
# 将整个test目录复制到您的项目根目录
cp -r /path/to/UnitBash/test /path/to/your/project/

# 进入测试目录
cd /path/to/your/project/test
```

### 2. 环境初始化
```bash
# 运行初始化脚本
./scripts/setup.sh

# 检查必需的命令是否已安装
# 如果缺少命令，请根据提示安装
```

### 3. 配置适配
```bash
# 编辑基础配置文件
vim config/base.conf

# 根据您的API修改以下关键配置：
# - API_BASE_URL="https://your-api.com"
# - AUTH_LOGIN_URL="/your/login/endpoint"
# - JWT_TOKEN_FIELD="your_token_field"

# 编辑开发环境配置
vim config/dev.conf

# 设置环境变量（复制示例文件）
cp config/env.example config/.env
vim config/.env
```

### 4. 运行测试
```bash
# 运行所有测试
./scripts/run_all.sh

# 运行特定环境的测试
./scripts/run_all.sh --env dev

# 运行特定模块的测试
./scripts/run_all.sh system
```

## 📁 目录结构说明

```
test/
├── README.md          # 本说明文件
├── config/            # 配置文件目录
│   ├── base.conf      # 基础配置（必须修改）
│   ├── dev.conf       # 开发环境配置
│   ├── test.conf      # 测试环境配置
│   ├── prod.conf      # 生产环境配置
│   └── env.example    # 环境变量示例
├── common/            # 核心库文件（无需修改）
│   ├── auth.sh        # 认证相关函数
│   ├── config.sh      # 配置管理函数
│   ├── data.sh        # 数据处理函数
│   ├── http.sh        # HTTP请求封装
│   ├── lib.sh         # 通用工具函数
│   └── validate.sh    # 响应验证函数
├── mock/              # 测试模拟数据
│   ├── users.json     # 用户测试数据
│   ├── files/         # 测试用文件
│   └── responses/     # 模拟响应数据
├── system/            # 系统级测试示例
│   ├── test_auth.sh   # 认证测试示例
│   └── test_user.sh   # 用户管理测试示例
├── modules/           # 业务模块测试（添加您的测试）
│   ├── user/          # 用户模块测试
│   ├── order/         # 订单模块测试
│   └── product/       # 产品模块测试
└── scripts/           # 辅助脚本
    ├── setup.sh       # 环境初始化
    ├── run_all.sh     # 批量执行测试
    └── cleanup.sh     # 清理脚本
```

## ⚙️ 配置指南

### 必需配置项 (config/base.conf)

```bash
# API基础信息（必须修改）
API_BASE_URL="https://your-api.example.com"
API_VERSION="v1"                    # 如果API有版本号
API_TIMEOUT=30                      # 请求超时时间

# 认证配置（根据您的API修改）
AUTH_LOGIN_URL="/auth/login"        # 登录接口路径
AUTH_USERNAME_FIELD="username"      # 用户名字段名
AUTH_PASSWORD_FIELD="password"      # 密码字段名
AUTH_CONTENT_TYPE="application/json" # 登录请求格式

# JWT配置（根据您的API响应格式修改）
JWT_TOKEN_FIELD="access_token"      # token在响应中的字段名
JWT_TOKEN_TYPE="Bearer"             # token类型
JWT_REFRESH_FIELD="refresh_token"   # 刷新token字段名

# 响应格式配置
SUCCESS_STATUS_CODES="200,201,204"  # 成功状态码
SUCCESS_RESPONSE_FIELD="success"    # 成功标识字段
ERROR_MESSAGE_FIELD="message"       # 错误信息字段
DATA_FIELD="data"                   # 数据字段名
```

### 环境变量配置 (config/.env)

```bash
# 敏感信息配置
DEV_USERNAME=your_dev_username
DEV_PASSWORD=your_dev_password
TEST_USERNAME=your_test_username
TEST_PASSWORD=your_test_password
API_KEY=your_api_key
```

## 📝 编写测试脚本

### 基本测试脚本模板

在 `modules/` 目录下创建您的测试脚本：

```bash
#!/bin/bash
# modules/your_module/test_your_feature.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

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

# 测试结果记录函数
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

# 确保已认证
ensure_auth() {
    if ! init_auth; then
        print_error "认证模块初始化失败"
        return 1
    fi
    
    if ! is_token_valid; then
        local username="${DEV_USERNAME:-admin}"
        local password="${DEV_PASSWORD:-admin123}"
        
        if ! login_with_password "$username" "$password"; then
            print_error "登录失败"
            return 1
        fi
    fi
    
    ensure_authenticated
}

# 示例测试函数
test_example_api() {
    print_info "测试: 示例API"
    
    local api_url
    api_url=$(get_api_url "/your/endpoint")
    
    if http_get "$api_url"; then
        if validate_success_response; then
            test_result "示例API测试" "PASS"
        else
            test_result "示例API测试" "FAIL"
        fi
    else
        test_result "示例API测试" "FAIL"
    fi
}

# 主函数
main() {
    echo "您的功能测试"
    echo "============"
    
    # 确保配置已加载
    ensure_config_loaded || {
        print_error "配置加载失败"
        exit 1
    }
    
    # 确保已认证
    ensure_auth || {
        print_error "认证失败"
        exit 1
    }
    
    # 运行测试
    test_example_api
    
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

## 🔧 常用API测试模式

### 1. 基本CRUD操作测试

```bash
# GET 获取列表
test_get_list() {
    local url=$(get_api_url "/users")
    http_get "$url" "page=1&limit=10"
    validate_success_response
    validate_json_field_exists ".data"
}

# POST 创建资源
test_create_resource() {
    local url=$(get_api_url "/users")
    local data='{"username":"test","email":"test@example.com"}'
    http_post "$url" "$data" "Content-Type: application/json"
    validate_status_code "201"
    validate_json_field_exists ".data.id"
}

# PUT 更新资源
test_update_resource() {
    local url=$(get_api_url "/users/1")
    local data='{"username":"updated"}'
    http_put "$url" "$data" "Content-Type: application/json"
    validate_success_response
}

# DELETE 删除资源
test_delete_resource() {
    local url=$(get_api_url "/users/1")
    http_delete "$url"
    validate_status_code_in "200,204"
}
```

### 2. 文件上传测试

```bash
test_file_upload() {
    local url=$(get_api_url "/upload")
    local file_path="mock/files/test.jpg"
    
    # 确保测试文件存在
    if [[ ! -f "$file_path" ]]; then
        echo "test file content" > "$file_path"
    fi
    
    http_upload "$url" "$file_path" "file"
    validate_success_response
}
```

### 3. 响应验证示例

```bash
# 验证JSON响应结构
validate_user_response() {
    validate_json_field_exists ".data.id"
    validate_json_field_exists ".data.username"
    validate_json_field_type ".data.id" "number"
    validate_json_field_type ".data.username" "string"
}

# 验证分页响应
validate_paginated_response() {
    validate_json_field_exists ".data"
    validate_json_field_exists ".pagination"
    validate_json_field_exists ".pagination.page"
    validate_json_field_exists ".pagination.totalCount"
}
```

## 🎯 集成到项目

### 1. 添加到项目的Makefile

```makefile
# Makefile
test:
	cd test && ./scripts/run_all.sh

test-auth:
	cd test && ./scripts/run_all.sh system

test-parallel:
	cd test && ./scripts/run_all.sh --parallel

test-report:
	cd test && ./scripts/run_all.sh --report results.json

clean-test:
	cd test && ./scripts/cleanup.sh
```

### 2. 添加到package.json（如果是Node.js项目）

```json
{
  "scripts": {
    "test:api": "cd test && ./scripts/run_all.sh",
    "test:api:dev": "cd test && ./scripts/run_all.sh --env dev",
    "test:api:parallel": "cd test && ./scripts/run_all.sh --parallel"
  }
}
```

### 3. CI/CD集成示例

```yaml
# .github/workflows/api-test.yml
name: API Tests
on: [push, pull_request]

jobs:
  api-test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    
    - name: Install dependencies
      run: sudo apt install curl jq bc
    
    - name: Setup test environment
      run: cd test && ./scripts/setup.sh
    
    - name: Run API tests
      env:
        TEST_USERNAME: ${{ secrets.TEST_USERNAME }}
        TEST_PASSWORD: ${{ secrets.TEST_PASSWORD }}
      run: cd test && ./scripts/run_all.sh --env test --report results.json
```

## 📋 检查清单

复制到新项目后，请确认以下事项：

- [ ] 已安装必需的命令：`curl`, `jq`, `grep`, `sed`, `awk`
- [ ] 已修改 `config/base.conf` 中的API基础信息
- [ ] 已配置 `config/.env` 中的敏感信息
- [ ] 已运行 `./scripts/setup.sh` 初始化环境
- [ ] 已编写针对项目的测试脚本
- [ ] 测试脚本可以正常运行
- [ ] 已集成到项目的构建流程中

## 🆘 常见问题

### Q: 如何修改API的响应格式？
A: 编辑 `config/base.conf` 中的响应配置项，如 `JWT_TOKEN_FIELD`、`DATA_FIELD` 等。

### Q: 如何添加自定义认证方式？
A: 可以在 `common/auth.sh` 中添加新的认证函数，或在测试脚本中使用 `set_custom_header`。

### Q: 如何处理复杂的JSON响应？
A: 使用 `jq` 工具处理，参考 `common/validate.sh` 中的验证函数。

### Q: 如何调试失败的测试？
A: 设置 `VERBOSE=true` 或 `LOG_LEVEL=DEBUG`，查看详细的执行日志。

## 📞 获取帮助

- 查看主项目文档：`../README.md`
- 运行演示：`../demo.sh`
- 检查语法：`bash -n script_name.sh`
- 查看日志：`tail -f logs/test.log`

---

**开始您的API测试之旅！** 🚀

如果您在使用过程中遇到问题，请参考主项目的文档或提交Issue。