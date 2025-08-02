#!/bin/bash

# 认证功能测试
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

# 测试用户名密码登录
test_login_with_password() {
    print_info "测试: 用户名密码登录"
    
    # 初始化认证模块
    if ! init_auth; then
        test_result "用户名密码登录" "FAIL"
        return 1
    fi
    
    # 使用测试账号登录
    local username="${DEV_USERNAME:-admin}"
    local password="${DEV_PASSWORD:-admin123}"
    
    if login_with_password "$username" "$password"; then
        test_result "用户名密码登录" "PASS"
        
        # 验证token是否设置
        if [[ -n "$JWT_TOKEN" ]]; then
            test_result "JWT Token设置" "PASS"
        else
            test_result "JWT Token设置" "FAIL"
        fi
        
        return 0
    else
        test_result "用户名密码登录" "FAIL"
        return 1
    fi
}

# 测试错误的登录凭据
test_login_with_wrong_credentials() {
    print_info "测试: 错误登录凭据"
    
    if ! init_auth; then
        test_result "错误登录凭据处理" "FAIL"
        return 1
    fi
    
    # 使用错误的凭据
    if login_with_password "wrong_user" "wrong_password"; then
        test_result "错误登录凭据处理" "FAIL"
        return 1
    else
        test_result "错误登录凭据处理" "PASS"
        return 0
    fi
}

# 测试token验证
test_token_validation() {
    print_info "测试: Token验证"
    
    if ! init_auth; then
        test_result "Token验证" "FAIL"
        return 1
    fi
    
    # 先登录获取token
    local username="${DEV_USERNAME:-admin}"
    local password="${DEV_PASSWORD:-admin123}"
    
    if login_with_password "$username" "$password"; then
        # 测试token是否有效
        if is_token_valid; then
            test_result "Token有效性验证" "PASS"
        else
            test_result "Token有效性验证" "FAIL"
        fi
        
        # 测试认证头部设置
        if ensure_authenticated; then
            test_result "认证头部设置" "PASS"
        else
            test_result "认证头部设置" "FAIL"
        fi
        
        return 0
    else
        test_result "Token验证" "FAIL"
        return 1
    fi
}

# 测试API Key认证
test_api_key_auth() {
    print_info "测试: API Key认证"
    
    # 设置API Key
    set_api_key "test_api_key_12345" "X-API-Key"
    test_result "API Key设置" "PASS"
    
    return 0
}

# 测试Basic认证
test_basic_auth() {
    print_info "测试: Basic认证"
    
    # 设置Basic认证
    set_basic_auth "testuser" "testpass"
    test_result "Basic认证设置" "PASS"
    
    return 0
}

# 测试认证状态显示
test_auth_status() {
    print_info "测试: 认证状态显示"
    
    if ! init_auth; then
        test_result "认证状态显示" "FAIL"
        return 1
    fi
    
    # 显示认证状态
    show_auth_status
    test_result "认证状态显示" "PASS"
    
    return 0
}

# 测试登出功能
test_logout() {
    print_info "测试: 登出功能"
    
    if ! init_auth; then
        test_result "登出功能" "FAIL"
        return 1
    fi
    
    # 先登录
    local username="${DEV_USERNAME:-admin}"
    local password="${DEV_PASSWORD:-admin123}"
    
    if login_with_password "$username" "$password"; then
        # 执行登出
        if logout; then
            test_result "登出功能" "PASS"
            
            # 验证token是否已清除
            if [[ -z "$JWT_TOKEN" ]]; then
                test_result "Token清除" "PASS"
            else
                test_result "Token清除" "FAIL"
            fi
            
            return 0
        else
            test_result "登出功能" "FAIL"
            return 1
        fi
    else
        test_result "登出功能" "FAIL"
        return 1
    fi
}

# 主测试函数
run_auth_tests() {
    echo "认证功能测试"
    echo "============"
    
    # 确保配置已加载
    ensure_config_loaded || {
        print_error "配置加载失败"
        exit 1
    }
    
    # 运行所有认证测试
    test_login_with_password
    test_login_with_wrong_credentials
    test_token_validation
    test_api_key_auth
    test_basic_auth
    test_auth_status
    test_logout
    
    # 显示测试结果
    echo ""
    echo "测试结果总结"
    echo "============"
    echo "总测试数: $TOTAL_TESTS"
    echo "通过: $PASSED_TESTS"
    echo "失败: $FAILED_TESTS"
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        print_success "所有认证测试都通过了！"
        exit 0
    else
        print_error "$FAILED_TESTS 个测试失败"
        exit 1
    fi
}

# 清理函数
cleanup() {
    cleanup_http
    clear_tokens
}

# 设置清理陷阱
trap cleanup EXIT

# 运行测试
run_auth_tests