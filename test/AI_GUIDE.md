# UnitBash AI 开发指引

> 为AI助手和大模型提供的简洁、精准的测试脚本开发指南

## 🎯 核心概念

UnitBash是一个bash脚本API测试框架，使用curl进行HTTP请求，jq处理JSON响应。

## 📁 关键文件结构

```
test/
├── common/          # 核心库（勿修改）
├── config/          # 配置文件（需要适配）
├── system/          # 系统测试示例
├── modules/         # 业务测试（主要开发区域）
└── scripts/         # 执行脚本
```

## ⚡ 测试脚本模板

```bash
#!/bin/bash
# 标准测试脚本模板

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"  # 如果在modules子目录

# 导入框架（必需）
source "$TEST_ROOT/common/lib.sh"
source "$TEST_ROOT/common/config.sh"
source "$TEST_ROOT/common/http.sh"
source "$TEST_ROOT/common/auth.sh"
source "$TEST_ROOT/common/validate.sh"

# 测试计数器
TOTAL_TESTS=0; PASSED_TESTS=0; FAILED_TESTS=0

# 测试结果记录
test_result() {
    ((TOTAL_TESTS++))
    if [[ "$2" == "PASS" ]]; then
        ((PASSED_TESTS++)); print_success "✓ $1"
    else
        ((FAILED_TESTS++)); print_error "✗ $1"
    fi
}

# 确保认证
ensure_auth() {
    init_auth || return 1
    is_token_valid || login_with_password "${DEV_USERNAME:-admin}" "${DEV_PASSWORD:-admin123}" || return 1
    ensure_authenticated
}

# 测试函数示例
test_api_endpoint() {
    print_info "测试: API端点"
    local url=$(get_api_url "/endpoint")
    
    if http_get "$url"; then
        validate_success_response && test_result "API端点测试" "PASS" || test_result "API端点测试" "FAIL"
    else
        test_result "API端点测试" "FAIL"
    fi
}

# 主函数
main() {
    echo "测试标题"; echo "========"
    ensure_config_loaded || exit 1
    ensure_auth || exit 1
    
    # 运行测试
    test_api_endpoint
    
    # 显示结果
    echo -e "\n测试结果: $PASSED_TESTS/$TOTAL_TESTS 通过"
    [[ $FAILED_TESTS -eq 0 ]] && exit 0 || exit 1
}

# 清理和执行
trap cleanup_http EXIT
main "$@"
```

## 🔧 核心API函数

### HTTP请求
```bash
# GET请求
http_get "$(get_api_url '/users')" "page=1&limit=10"

# POST请求  
http_post "$(get_api_url '/users')" '{"name":"test"}' "Content-Type: application/json"

# PUT/DELETE请求
http_put "$(get_api_url '/users/1')" '{"name":"updated"}'
http_delete "$(get_api_url '/users/1')"

# 文件上传
http_upload "$(get_api_url '/upload')" "/path/to/file.jpg" "avatar"
```

### 认证
```bash
# JWT登录
login_with_password "username" "password"

# API Key认证
set_api_key "your_api_key" "X-API-Key"

# Basic认证
set_basic_auth "username" "password"

# 检查认证状态
ensure_authenticated
```

### 响应验证
```bash
# 基础验证
validate_status_code "200"
validate_success_response
validate_json_response

# 字段验证
validate_json_field_exists ".data.id"
validate_json_field_value ".data.name" "expected_value"
validate_json_field_type ".data.count" "number"

# 组合验证
run_validations \
    "validate_status_code 200" \
    "validate_json_field_exists .data" \
    "validate_json_field_type .data.users array"
```

### 数据生成
```bash
# 生成测试数据
user_data=$(generate_user_data "testuser")
product_data=$(generate_product_data "测试产品")

# 从模拟数据获取
random_user=$(get_random_mock_item "users")
```

## 📋 常用测试模式

### CRUD操作测试
```bash
test_crud_operations() {
    local base_url=$(get_api_url "/users")
    
    # CREATE
    local create_data='{"username":"test","email":"test@example.com"}'
    http_post "$base_url" "$create_data" "Content-Type: application/json"
    validate_status_code "201"
    local user_id=$(get_response_body | jq -r '.data.id')
    
    # READ
    http_get "${base_url}/${user_id}"
    validate_success_response
    
    # UPDATE  
    local update_data='{"username":"updated"}'
    http_put "${base_url}/${user_id}" "$update_data" "Content-Type: application/json"
    validate_success_response
    
    # DELETE
    http_delete "${base_url}/${user_id}"
    validate_status_code_in "200,204"
}
```

### 分页和搜索测试
```bash
test_pagination() {
    http_get "$(get_api_url '/users')" "page=1&limit=5"
    validate_json_field_exists ".pagination.totalCount"
    validate_json_field_type ".data" "array"
}

test_search() {
    http_get "$(get_api_url '/users/search')" "q=admin&limit=10"
    validate_success_response
}
```

### 错误处理测试
```bash
test_error_handling() {
    # 测试404
    http_get "$(get_api_url '/users/99999')"
    validate_status_code "404"
    
    # 测试400
    http_post "$(get_api_url '/users')" '{"invalid":"data"}' "Content-Type: application/json"
    validate_status_code "400"
    validate_error_response
}
```

## ⚙️ 配置要点

### 基础配置 (config/base.conf)
```bash
# 必须修改的配置
API_BASE_URL="https://your-api.com"
AUTH_LOGIN_URL="/auth/login"
JWT_TOKEN_FIELD="access_token"          # 根据API响应调整
SUCCESS_STATUS_CODES="200,201,204"     # 根据API调整
AUTH_USERNAME_FIELD="username"         # 根据登录接口调整
AUTH_PASSWORD_FIELD="password"         # 根据登录接口调整
```

### 环境变量 (config/.env)
```bash
DEV_USERNAME=admin
DEV_PASSWORD=admin123
API_KEY=your_api_key
```

## 🚨 关键注意事项

1. **路径导入**: 根据脚本位置调整TEST_ROOT路径
2. **认证流程**: 先`ensure_auth`再发送请求
3. **错误处理**: 每个HTTP请求后检查返回值
4. **清理资源**: 使用`trap cleanup_http EXIT`
5. **配置加载**: 主函数开始时调用`ensure_config_loaded`

## 📊 执行方式

```bash
# 单个测试
bash test_script.sh

# 批量执行
./scripts/run_all.sh modules/your_module

# 并行执行
./scripts/run_all.sh --parallel

# 生成报告
./scripts/run_all.sh --report results.json
```

## 🔍 调试技巧

```bash
# 启用详细输出
export VERBOSE=true
export LOG_LEVEL=DEBUG

# 查看HTTP请求详情
curl命令会自动记录到HTTP_RESPONSE_FILE和HTTP_HEADERS_FILE

# 检查响应内容
echo "Response: $(get_response_body)"
echo "Status: $(get_status_code)"
```

## ✅ 开发检查清单

- [ ] 导入了所有必需的common库
- [ ] 设置了测试计数器和test_result函数
- [ ] 实现了ensure_auth函数
- [ ] 每个测试函数都有适当的验证
- [ ] 主函数包含了配置加载和认证检查
- [ ] 设置了cleanup陷阱
- [ ] 脚本有可执行权限

---

**AI开发提示**: 遵循此模板，专注于业务逻辑测试，框架已处理底层细节。