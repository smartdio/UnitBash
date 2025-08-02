#!/bin/bash

# 认证模块
# ===================================

# 导入依赖
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/lib.sh"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/http.sh"

# 全局变量
JWT_TOKEN=""
REFRESH_TOKEN=""
TOKEN_EXPIRES_AT=""
SESSION_FILE=""

# 初始化认证模块
init_auth() {
    ensure_config_loaded || return 1
    
    # 创建会话目录
    local session_dir="$(dirname "${BASH_SOURCE[0]}")/../.session"
    ensure_dir "$session_dir"
    
    SESSION_FILE="$session_dir/auth_${CURRENT_ENV}.json"
    
    # 尝试加载已保存的token
    load_saved_token
    
    log_debug "认证模块初始化完成"
}

# 用户名密码登录
login_with_password() {
    local username="$1"
    local password="$2"
    local additional_data="$3"
    
    if [[ -z "$username" || -z "$password" ]]; then
        log_error "用户名和密码不能为空"
        return 1
    fi
    
    local login_url
    login_url=$(get_auth_url "login") || return 1
    
    # 构建登录数据
    local login_data="{}"
    
    if [[ "$AUTH_CONTENT_TYPE" == "application/json" ]]; then
        # JSON格式
        login_data=$(jq -n \
            --arg username "$username" \
            --arg password "$password" \
            --arg username_field "$AUTH_USERNAME_FIELD" \
            --arg password_field "$AUTH_PASSWORD_FIELD" \
            '{($username_field): $username, ($password_field): $password}')
        
        # 添加额外字段
        if [[ -n "$additional_data" ]]; then
            login_data=$(echo "$login_data" | jq ". + $additional_data")
        fi
        
        # 添加其他配置的字段
        if [[ -n "$AUTH_ADDITIONAL_FIELDS" ]]; then
            IFS=',' read -ra fields <<< "$AUTH_ADDITIONAL_FIELDS"
            for field in "${fields[@]}"; do
                if [[ "$field" == *"="* ]]; then
                    local key="${field%%=*}"
                    local value="${field#*=}"
                    login_data=$(echo "$login_data" | jq --arg k "$key" --arg v "$value" '. + {($k): $v}')
                fi
            done
        fi
    else
        # Form格式
        login_data="${AUTH_USERNAME_FIELD}=${username}&${AUTH_PASSWORD_FIELD}=${password}"
        
        if [[ -n "$additional_data" ]]; then
            login_data="${login_data}&${additional_data}"
        fi
    fi
    
    log_info "正在登录用户: $username"
    
    # 发送登录请求
    local headers=()
    if [[ "$AUTH_CONTENT_TYPE" == "application/json" ]]; then
        headers+=("Content-Type: application/json")
    else
        headers+=("Content-Type: application/x-www-form-urlencoded")
    fi
    
    if http_post "$login_url" "$login_data" "${headers[@]}"; then
        local response_body
        response_body=$(get_response_body)
        
        if is_successful_response; then
            # 解析token
            if extract_tokens_from_response "$response_body"; then
                save_token
                print_success "登录成功"
                return 0
            else
                log_error "无法从响应中提取token"
                return 1
            fi
        else
            local error_msg
            error_msg=$(extract_error_message "$response_body")
            log_error "登录失败: $error_msg"
            return 1
        fi
    else
        log_error "登录请求失败"
        return 1
    fi
}

# API Key认证
set_api_key() {
    local api_key="$1"
    local header_name="${2:-X-API-Key}"
    
    if [[ -z "$api_key" ]]; then
        log_error "API Key不能为空"
        return 1
    fi
    
    set_custom_header "$header_name: $api_key"
    log_info "已设置API Key认证"
}

# Basic认证
set_basic_auth() {
    local username="$1"
    local password="$2"
    
    if [[ -z "$username" || -z "$password" ]]; then
        log_error "用户名和密码不能为空"
        return 1
    fi
    
    local credentials
    credentials=$(echo -n "$username:$password" | base64)
    set_custom_header "Authorization: Basic $credentials"
    log_info "已设置Basic认证"
}

# 刷新token
refresh_token() {
    if [[ -z "$REFRESH_TOKEN" ]]; then
        log_error "没有可用的refresh token"
        return 1
    fi
    
    local refresh_url
    refresh_url=$(get_auth_url "refresh") || return 1
    
    local refresh_data
    if [[ "$AUTH_CONTENT_TYPE" == "application/json" ]]; then
        refresh_data=$(jq -n --arg token "$REFRESH_TOKEN" '{refresh_token: $token}')
    else
        refresh_data="refresh_token=${REFRESH_TOKEN}"
    fi
    
    log_info "正在刷新token"
    
    local headers=()
    if [[ "$AUTH_CONTENT_TYPE" == "application/json" ]]; then
        headers+=("Content-Type: application/json")
    fi
    
    if http_post "$refresh_url" "$refresh_data" "${headers[@]}"; then
        local response_body
        response_body=$(get_response_body)
        
        if is_successful_response; then
            if extract_tokens_from_response "$response_body"; then
                save_token
                print_success "Token刷新成功"
                return 0
            else
                log_error "无法从响应中提取新token"
                return 1
            fi
        else
            local error_msg
            error_msg=$(extract_error_message "$response_body")
            log_error "Token刷新失败: $error_msg"
            return 1
        fi
    else
        log_error "Token刷新请求失败"
        return 1
    fi
}

# 登出
logout() {
    if [[ -z "$JWT_TOKEN" ]]; then
        log_warn "当前未登录"
        return 0
    fi
    
    local logout_url
    logout_url=$(get_auth_url "logout") || return 1
    
    log_info "正在登出"
    
    if http_post "$logout_url" ""; then
        if is_successful_response; then
            clear_tokens
            print_success "登出成功"
            return 0
        else
            log_warn "登出请求返回错误，但仍清除本地token"
            clear_tokens
            return 0
        fi
    else
        log_warn "登出请求失败，但仍清除本地token"
        clear_tokens
        return 0
    fi
}

# 检查token是否有效
is_token_valid() {
    if [[ -z "$JWT_TOKEN" ]]; then
        return 1
    fi
    
    # 检查过期时间
    if [[ -n "$TOKEN_EXPIRES_AT" ]]; then
        local current_time
        current_time=$(date +%s)
        if [[ $TOKEN_EXPIRES_AT -lt $current_time ]]; then
            log_debug "Token已过期"
            return 1
        fi
    fi
    
    return 0
}

# 确保已认证
ensure_authenticated() {
    if ! is_token_valid; then
        if [[ -n "$REFRESH_TOKEN" ]]; then
            log_info "Token已过期，尝试刷新"
            if refresh_token; then
                return 0
            fi
        fi
        
        log_error "未认证或token无效，请先登录"
        return 1
    fi
    
    # 设置认证头部
    set_auth_header "$JWT_TOKEN" "$JWT_TOKEN_TYPE"
    return 0
}

# 从响应中提取token
extract_tokens_from_response() {
    local response="$1"
    
    if ! is_valid_json "$response"; then
        log_error "响应不是有效的JSON格式"
        return 1
    fi
    
    # 提取access token
    local token_path=".$JWT_TOKEN_FIELD"
    JWT_TOKEN=$(json_extract "$response" "$token_path")
    
    if [[ -z "$JWT_TOKEN" || "$JWT_TOKEN" == "null" ]]; then
        log_error "无法从响应中提取access token (字段: $JWT_TOKEN_FIELD)"
        return 1
    fi
    
    # 提取refresh token（可选）
    if [[ -n "$JWT_REFRESH_FIELD" ]]; then
        local refresh_path=".$JWT_REFRESH_FIELD"
        REFRESH_TOKEN=$(json_extract "$response" "$refresh_path")
    fi
    
    # 提取过期时间（可选）
    if [[ -n "$JWT_EXPIRES_FIELD" ]]; then
        local expires_path=".$JWT_EXPIRES_FIELD"
        local expires_in
        expires_in=$(json_extract "$response" "$expires_path")
        
        if [[ -n "$expires_in" && "$expires_in" != "null" ]]; then
            TOKEN_EXPIRES_AT=$(($(date +%s) + expires_in))
        fi
    fi
    
    log_debug "成功提取token信息"
    return 0
}

# 保存token到文件
save_token() {
    local session_data
    session_data=$(jq -n \
        --arg access_token "$JWT_TOKEN" \
        --arg refresh_token "${REFRESH_TOKEN:-}" \
        --arg expires_at "${TOKEN_EXPIRES_AT:-}" \
        --arg timestamp "$(date +%s)" \
        '{
            access_token: $access_token,
            refresh_token: $refresh_token,
            expires_at: $expires_at,
            saved_at: $timestamp
        }')
    
    echo "$session_data" > "$SESSION_FILE"
    log_debug "Token已保存到: $SESSION_FILE"
}

# 加载保存的token
load_saved_token() {
    if [[ ! -f "$SESSION_FILE" ]]; then
        return 1
    fi
    
    local session_data
    session_data=$(cat "$SESSION_FILE")
    
    if ! is_valid_json "$session_data"; then
        log_warn "会话文件格式无效: $SESSION_FILE"
        return 1
    fi
    
    JWT_TOKEN=$(json_extract "$session_data" ".access_token")
    REFRESH_TOKEN=$(json_extract "$session_data" ".refresh_token")
    TOKEN_EXPIRES_AT=$(json_extract "$session_data" ".expires_at")
    
    if [[ -n "$JWT_TOKEN" && "$JWT_TOKEN" != "null" ]]; then
        log_debug "已加载保存的token"
        return 0
    fi
    
    return 1
}

# 清除tokens
clear_tokens() {
    JWT_TOKEN=""
    REFRESH_TOKEN=""
    TOKEN_EXPIRES_AT=""
    
    if [[ -f "$SESSION_FILE" ]]; then
        rm -f "$SESSION_FILE"
    fi
    
    clear_auth_header
    log_debug "已清除所有认证信息"
}

# 提取错误信息
extract_error_message() {
    local response="$1"
    local default_message="未知错误"
    
    if is_valid_json "$response"; then
        local error_path=".$ERROR_MESSAGE_FIELD"
        local error_msg
        error_msg=$(json_extract "$response" "$error_path" "$default_message")
        echo "$error_msg"
    else
        echo "$default_message"
    fi
}

# 检查响应是否成功
is_successful_response() {
    local status_code
    status_code=$(get_status_code)
    
    # 检查HTTP状态码
    IFS=',' read -ra success_codes <<< "$SUCCESS_STATUS_CODES"
    for code in "${success_codes[@]}"; do
        if [[ "$status_code" == "$code" ]]; then
            return 0
        fi
    done
    
    return 1
}

# 显示认证状态
show_auth_status() {
    echo "认证状态信息:"
    echo "  环境: $CURRENT_ENV"
    echo "  登录URL: $(get_auth_url login)"
    
    if [[ -n "$JWT_TOKEN" ]]; then
        echo "  状态: 已认证"
        echo "  Token类型: $JWT_TOKEN_TYPE"
        echo "  Token: ${JWT_TOKEN:0:20}..."
        
        if [[ -n "$TOKEN_EXPIRES_AT" ]]; then
            local expires_date
            expires_date=$(date -r "$TOKEN_EXPIRES_AT" 2>/dev/null || echo "无效")
            echo "  过期时间: $expires_date"
        fi
        
        if is_token_valid; then
            print_success "Token有效"
        else
            print_warning "Token已过期"
        fi
    else
        echo "  状态: 未认证"
    fi
}