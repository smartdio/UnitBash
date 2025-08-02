#!/bin/bash

# 用户管理测试
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
            print_error "登录失败，无法进行用户管理测试"
            return 1
        fi
    fi
    
    ensure_authenticated
}

# 测试获取用户列表
test_get_users() {
    print_info "测试: 获取用户列表"
    
    local users_url
    users_url=$(get_api_url "/users")
    
    if http_get "$users_url"; then
        if validate_success_response; then
            test_result "获取用户列表" "PASS"
            
            # 验证响应包含用户数据
            if validate_json_field_exists ".data"; then
                test_result "用户数据字段存在" "PASS"
            else
                test_result "用户数据字段存在" "FAIL"
            fi
            
            return 0
        else
            test_result "获取用户列表" "FAIL"
            return 1
        fi
    else
        test_result "获取用户列表" "FAIL"
        return 1
    fi
}

# 测试创建用户
test_create_user() {
    print_info "测试: 创建用户"
    
    # 生成测试用户数据
    local user_data
    user_data=$(generate_user_data "testuser")
    
    local users_url
    users_url=$(get_api_url "/users")
    
    if http_post "$users_url" "$user_data" "Content-Type: application/json"; then
        if validate_success_response; then
            test_result "创建用户" "PASS"
            
            # 保存创建的用户ID用于后续测试
            local response_body
            response_body=$(get_response_body)
            CREATED_USER_ID=$(json_extract "$response_body" ".data.id")
            
            # 验证返回的用户信息
            if validate_json_field_exists ".data.id"; then
                test_result "用户ID返回" "PASS"
            else
                test_result "用户ID返回" "FAIL"
            fi
            
            return 0
        else
            test_result "创建用户" "FAIL"
            return 1
        fi
    else
        test_result "创建用户" "FAIL"
        return 1
    fi
}

# 测试获取单个用户
test_get_user() {
    print_info "测试: 获取单个用户"
    
    if [[ -z "$CREATED_USER_ID" ]]; then
        print_warning "跳过测试: 没有可用的用户ID"
        return 0
    fi
    
    local user_url
    user_url=$(get_api_url "/users/$CREATED_USER_ID")
    
    if http_get "$user_url"; then
        if validate_success_response; then
            test_result "获取单个用户" "PASS"
            
            # 验证用户ID匹配
            if validate_json_field_value ".data.id" "$CREATED_USER_ID"; then
                test_result "用户ID匹配" "PASS"
            else
                test_result "用户ID匹配" "FAIL"
            fi
            
            return 0
        else
            test_result "获取单个用户" "FAIL"
            return 1
        fi
    else
        test_result "获取单个用户" "FAIL"
        return 1
    fi
}

# 测试更新用户
test_update_user() {
    print_info "测试: 更新用户"
    
    if [[ -z "$CREATED_USER_ID" ]]; then
        print_warning "跳过测试: 没有可用的用户ID"
        return 0
    fi
    
    # 生成更新数据
    local update_data
    update_data=$(jq -n \
        --arg firstName "更新的" \
        --arg lastName "用户名" \
        '{
            firstName: $firstName,
            lastName: $lastName
        }')
    
    local user_url
    user_url=$(get_api_url "/users/$CREATED_USER_ID")
    
    if http_put "$user_url" "$update_data" "Content-Type: application/json"; then
        if validate_success_response; then
            test_result "更新用户" "PASS"
            
            # 验证更新后的数据
            if validate_json_field_value ".data.firstName" "更新的"; then
                test_result "用户数据更新" "PASS"
            else
                test_result "用户数据更新" "FAIL"
            fi
            
            return 0
        else
            test_result "更新用户" "FAIL"
            return 1
        fi
    else
        test_result "更新用户" "FAIL"
        return 1
    fi
}

# 测试用户搜索
test_search_users() {
    print_info "测试: 用户搜索"
    
    local search_url
    search_url=$(get_api_url "/users/search")
    local search_params="q=test&limit=10"
    
    if http_get "$search_url" "$search_params"; then
        if validate_success_response; then
            test_result "用户搜索" "PASS"
            
            # 验证搜索结果格式
            if validate_json_field_exists ".data"; then
                test_result "搜索结果格式" "PASS"
            else
                test_result "搜索结果格式" "FAIL"
            fi
            
            return 0
        else
            test_result "用户搜索" "FAIL"
            return 1
        fi
    else
        test_result "用户搜索" "FAIL"
        return 1
    fi
}

# 测试分页获取用户
test_paginated_users() {
    print_info "测试: 分页获取用户"
    
    local users_url
    users_url=$(get_api_url "/users")
    local page_params="page=1&limit=5"
    
    if http_get "$users_url" "$page_params"; then
        if validate_success_response; then
            test_result "分页获取用户" "PASS"
            
            # 验证分页信息
            if validate_json_field_exists ".pagination"; then
                test_result "分页信息存在" "PASS"
                
                # 验证分页字段
                if validate_json_field_exists ".pagination.page" && \
                   validate_json_field_exists ".pagination.totalCount"; then
                    test_result "分页字段完整" "PASS"
                else
                    test_result "分页字段完整" "FAIL"
                fi
            else
                test_result "分页信息存在" "FAIL"
            fi
            
            return 0
        else
            test_result "分页获取用户" "FAIL"
            return 1
        fi
    else
        test_result "分页获取用户" "FAIL"
        return 1
    fi
}

# 测试删除用户
test_delete_user() {
    print_info "测试: 删除用户"
    
    if [[ -z "$CREATED_USER_ID" ]]; then
        print_warning "跳过测试: 没有可用的用户ID"
        return 0
    fi
    
    local user_url
    user_url=$(get_api_url "/users/$CREATED_USER_ID")
    
    if http_delete "$user_url"; then
        if validate_status_code_in "200,204"; then
            test_result "删除用户" "PASS"
            
            # 验证用户已被删除（获取应该返回404）
            sleep 1  # 等待删除生效
            if http_get "$user_url"; then
                local status_code
                status_code=$(get_status_code)
                if [[ "$status_code" == "404" ]]; then
                    test_result "用户删除确认" "PASS"
                else
                    test_result "用户删除确认" "FAIL"
                fi
            else
                test_result "用户删除确认" "PASS"
            fi
            
            return 0
        else
            test_result "删除用户" "FAIL"
            return 1
        fi
    else
        test_result "删除用户" "FAIL"
        return 1
    fi
}

# 测试无效的用户操作
test_invalid_operations() {
    print_info "测试: 无效的用户操作"
    
    # 测试获取不存在的用户
    local invalid_user_url
    invalid_user_url=$(get_api_url "/users/99999")
    
    if http_get "$invalid_user_url"; then
        local status_code
        status_code=$(get_status_code)
        if [[ "$status_code" == "404" ]]; then
            test_result "获取不存在用户返回404" "PASS"
        else
            test_result "获取不存在用户返回404" "FAIL"
        fi
    else
        test_result "获取不存在用户返回404" "PASS"
    fi
    
    # 测试创建无效用户数据
    local invalid_data='{"username": ""}'
    local users_url
    users_url=$(get_api_url "/users")
    
    if http_post "$users_url" "$invalid_data" "Content-Type: application/json"; then
        local status_code
        status_code=$(get_status_code)
        if [[ "$status_code" == "400" ]]; then
            test_result "无效数据返回400" "PASS"
        else
            test_result "无效数据返回400" "FAIL"
        fi
    else
        test_result "无效数据返回400" "PASS"
    fi
}

# 主测试函数
run_user_tests() {
    echo "用户管理测试"
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
    
    # 运行所有用户管理测试
    test_get_users
    test_create_user
    test_get_user
    test_update_user
    test_search_users
    test_paginated_users
    test_delete_user
    test_invalid_operations
    
    # 显示测试结果
    echo ""
    echo "测试结果总结"
    echo "============"
    echo "总测试数: $TOTAL_TESTS"
    echo "通过: $PASSED_TESTS"
    echo "失败: $FAILED_TESTS"
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        print_success "所有用户管理测试都通过了！"
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
run_user_tests