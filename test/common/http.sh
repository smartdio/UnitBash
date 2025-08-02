#!/bin/bash

# HTTP请求封装模块
# ===================================

# 导入依赖
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/lib.sh"
source "$SCRIPT_DIR/config.sh"

# 全局变量
HTTP_RESPONSE_FILE=""
HTTP_STATUS_CODE=""
HTTP_HEADERS_FILE=""
CURL_OPTS=()

# 初始化HTTP模块
init_http() {
    ensure_config_loaded || return 1
    
    # 创建临时文件
    HTTP_RESPONSE_FILE=$(mktemp)
    HTTP_HEADERS_FILE=$(mktemp)
    
    # 设置基础CURL选项
    CURL_OPTS=(
        --silent
        --show-error
        --location
        --max-time "${API_TIMEOUT:-30}"
        --retry "${API_RETRY_COUNT:-3}"
        --user-agent "${USER_AGENT:-UnitBash/1.0}"
        --dump-header "$HTTP_HEADERS_FILE"
        --output "$HTTP_RESPONSE_FILE"
    )
    
    # 添加默认头部
    if [[ -n "${DEFAULT_HEADERS:-}" ]]; then
        IFS=',' read -ra headers <<< "$DEFAULT_HEADERS"
        for header in "${headers[@]}"; do
            CURL_OPTS+=(--header "$header")
        done
    fi
    
    log_debug "HTTP模块初始化完成"
}

# 清理HTTP模块
cleanup_http() {
    [[ -f "$HTTP_RESPONSE_FILE" ]] && rm -f "$HTTP_RESPONSE_FILE"
    [[ -f "$HTTP_HEADERS_FILE" ]] && rm -f "$HTTP_HEADERS_FILE"
    log_debug "HTTP模块清理完成"
}

# 发送HTTP请求
send_request() {
    local method="$1"
    local url="$2"
    local data="$3"
    local extra_headers=("${@:4}")
    
    init_http || return 1
    
    local curl_cmd=("curl" "${CURL_OPTS[@]}")
    
    # 添加请求方法
    curl_cmd+=(--request "$method")
    
    # 添加额外头部
    for header in "${extra_headers[@]}"; do
        curl_cmd+=(--header "$header")
    done
    
    # 添加请求体数据
    if [[ -n "$data" ]]; then
        if [[ "$method" == "GET" || "$method" == "HEAD" ]]; then
            # GET请求将数据作为查询参数
            if [[ "$url" == *"?"* ]]; then
                url="${url}&${data}"
            else
                url="${url}?${data}"
            fi
        else
            curl_cmd+=(--data "$data")
        fi
    fi
    
    # 添加URL
    curl_cmd+=("$url")
    
    log_debug "发送HTTP请求: $method $url"
    [[ "${VERBOSE:-false}" == true ]] && log_debug "CURL命令: ${curl_cmd[*]}"
    
    # 执行请求
    if "${curl_cmd[@]}"; then
        # 提取状态码
        HTTP_STATUS_CODE=$(grep -E "^HTTP/[0-9.]+ [0-9]+" "$HTTP_HEADERS_FILE" | tail -n1 | awk '{print $2}')
        log_debug "HTTP状态码: $HTTP_STATUS_CODE"
        return 0
    else
        local exit_code=$?
        log_error "HTTP请求失败: $method $url"
        return $exit_code
    fi
}

# GET请求
http_get() {
    local url="$1"
    local query_params="$2"
    local headers=("${@:3}")
    
    send_request "GET" "$url" "$query_params" "${headers[@]}"
}

# POST请求
http_post() {
    local url="$1"
    local data="$2"
    local headers=("${@:3}")
    
    send_request "POST" "$url" "$data" "${headers[@]}"
}

# PUT请求
http_put() {
    local url="$1"
    local data="$2"
    local headers=("${@:3}")
    
    send_request "PUT" "$url" "$data" "${headers[@]}"
}

# DELETE请求
http_delete() {
    local url="$1"
    local data="$2"
    local headers=("${@:3}")
    
    send_request "DELETE" "$url" "$data" "${headers[@]}"
}

# PATCH请求
http_patch() {
    local url="$1"
    local data="$2"
    local headers=("${@:3}")
    
    send_request "PATCH" "$url" "$data" "${headers[@]}"
}

# 文件上传
http_upload() {
    local url="$1"
    local file_path="$2"
    local field_name="${3:-file}"
    local headers=("${@:4}")
    
    if [[ ! -f "$file_path" ]]; then
        log_error "文件不存在: $file_path"
        return 1
    fi
    
    init_http || return 1
    
    local curl_cmd=("curl" "${CURL_OPTS[@]}")
    curl_cmd+=(--request "POST")
    curl_cmd+=(--form "${field_name}=@${file_path}")
    
    # 添加额外头部
    for header in "${headers[@]}"; do
        curl_cmd+=(--header "$header")
    done
    
    curl_cmd+=("$url")
    
    log_debug "上传文件: $file_path 到 $url"
    
    if "${curl_cmd[@]}"; then
        HTTP_STATUS_CODE=$(grep -E "^HTTP/[0-9.]+ [0-9]+" "$HTTP_HEADERS_FILE" | tail -n1 | awk '{print $2}')
        log_debug "文件上传完成，状态码: $HTTP_STATUS_CODE"
        return 0
    else
        log_error "文件上传失败: $file_path"
        return 1
    fi
}

# 多文件上传
http_upload_multiple() {
    local url="$1"
    local field_name="${2:-files}"
    shift 2
    local files=("$@")
    
    if [[ ${#files[@]} -eq 0 ]]; then
        log_error "未指定上传文件"
        return 1
    fi
    
    # 检查所有文件是否存在
    for file in "${files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "文件不存在: $file"
            return 1
        fi
    done
    
    init_http || return 1
    
    local curl_cmd=("curl" "${CURL_OPTS[@]}")
    curl_cmd+=(--request "POST")
    
    # 添加所有文件
    for file in "${files[@]}"; do
        curl_cmd+=(--form "${field_name}=@${file}")
    done
    
    curl_cmd+=("$url")
    
    log_debug "批量上传文件到: $url"
    
    if "${curl_cmd[@]}"; then
        HTTP_STATUS_CODE=$(grep -E "^HTTP/[0-9.]+ [0-9]+" "$HTTP_HEADERS_FILE" | tail -n1 | awk '{print $2}')
        log_debug "批量文件上传完成，状态码: $HTTP_STATUS_CODE"
        return 0
    else
        log_error "批量文件上传失败"
        return 1
    fi
}

# 获取响应体
get_response_body() {
    if [[ -f "$HTTP_RESPONSE_FILE" ]]; then
        cat "$HTTP_RESPONSE_FILE"
    fi
}

# 获取响应头
get_response_headers() {
    if [[ -f "$HTTP_HEADERS_FILE" ]]; then
        cat "$HTTP_HEADERS_FILE"
    fi
}

# 获取状态码
get_status_code() {
    echo "$HTTP_STATUS_CODE"
}

# 获取特定响应头
get_response_header() {
    local header_name="$1"
    if [[ -f "$HTTP_HEADERS_FILE" ]]; then
        grep -i "^${header_name}:" "$HTTP_HEADERS_FILE" | cut -d':' -f2- | sed 's/^ *//' | tr -d '\r'
    fi
}

# 设置认证头部
set_auth_header() {
    local token="$1"
    local token_type="${2:-Bearer}"
    
    if [[ -n "$token" ]]; then
        CURL_OPTS+=(--header "Authorization: $token_type $token")
        log_debug "设置认证头部: $token_type ***"
    fi
}

# 设置自定义头部
set_custom_header() {
    local header="$1"
    CURL_OPTS+=(--header "$header")
    log_debug "添加自定义头部: $header"
}

# 清除认证头部
clear_auth_header() {
    local new_opts=()
    for opt in "${CURL_OPTS[@]}"; do
        if [[ "$opt" != *"Authorization:"* ]]; then
            new_opts+=("$opt")
        fi
    done
    CURL_OPTS=("${new_opts[@]}")
    log_debug "清除认证头部"
}

# 下载文件
http_download() {
    local url="$1"
    local output_file="$2"
    local headers=("${@:3}")
    
    local curl_cmd=("curl" --silent --show-error --location)
    curl_cmd+=(--max-time "${API_TIMEOUT:-30}")
    curl_cmd+=(--retry "${API_RETRY_COUNT:-3}")
    curl_cmd+=(--output "$output_file")
    
    # 添加认证头部
    for opt in "${CURL_OPTS[@]}"; do
        if [[ "$opt" == *"Authorization:"* ]]; then
            curl_cmd+=(--header "$opt")
        fi
    done
    
    # 添加额外头部
    for header in "${headers[@]}"; do
        curl_cmd+=(--header "$header")
    done
    
    curl_cmd+=("$url")
    
    log_debug "下载文件: $url -> $output_file"
    
    if "${curl_cmd[@]}"; then
        log_debug "文件下载完成: $output_file"
        return 0
    else
        log_error "文件下载失败: $url"
        return 1
    fi
}