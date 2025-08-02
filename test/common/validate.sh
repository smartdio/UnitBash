#!/bin/bash

# 响应验证模块
# ===================================

# 导入依赖
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/lib.sh"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/http.sh"

# 验证HTTP状态码
validate_status_code() {
    local expected_code="$1"
    local actual_code
    actual_code=$(get_status_code)
    
    if [[ "$actual_code" == "$expected_code" ]]; then
        print_success "状态码验证通过: $actual_code"
        return 0
    else
        print_error "状态码验证失败: 期望 $expected_code, 实际 $actual_code"
        return 1
    fi
}

# 验证状态码在允许范围内
validate_status_code_in() {
    local allowed_codes="$1"
    local actual_code
    actual_code=$(get_status_code)
    
    IFS=',' read -ra codes <<< "$allowed_codes"
    for code in "${codes[@]}"; do
        if [[ "$actual_code" == "$code" ]]; then
            print_success "状态码验证通过: $actual_code"
            return 0
        fi
    done
    
    print_error "状态码验证失败: $actual_code 不在允许范围 [$allowed_codes] 内"
    return 1
}

# 验证响应头存在
validate_header_exists() {
    local header_name="$1"
    local header_value
    header_value=$(get_response_header "$header_name")
    
    if [[ -n "$header_value" ]]; then
        print_success "响应头验证通过: $header_name 存在"
        return 0
    else
        print_error "响应头验证失败: $header_name 不存在"
        return 1
    fi
}

# 验证响应头值
validate_header_value() {
    local header_name="$1"
    local expected_value="$2"
    local header_value
    header_value=$(get_response_header "$header_name")
    
    if [[ "$header_value" == "$expected_value" ]]; then
        print_success "响应头验证通过: $header_name = $expected_value"
        return 0
    else
        print_error "响应头验证失败: $header_name 期望 '$expected_value', 实际 '$header_value'"
        return 1
    fi
}

# 验证响应头包含值
validate_header_contains() {
    local header_name="$1"
    local expected_substring="$2"
    local header_value
    header_value=$(get_response_header "$header_name")
    
    if [[ "$header_value" == *"$expected_substring"* ]]; then
        print_success "响应头验证通过: $header_name 包含 '$expected_substring'"
        return 0
    else
        print_error "响应头验证失败: $header_name '$header_value' 不包含 '$expected_substring'"
        return 1
    fi
}

# 验证JSON响应格式
validate_json_response() {
    local response_body
    response_body=$(get_response_body)
    
    if is_valid_json "$response_body"; then
        print_success "JSON格式验证通过"
        return 0
    else
        print_error "JSON格式验证失败: 响应不是有效的JSON"
        return 1
    fi
}

# 验证JSON字段存在
validate_json_field_exists() {
    local field_path="$1"
    local response_body
    response_body=$(get_response_body)
    
    if ! validate_json_response; then
        return 1
    fi
    
    local field_value
    field_value=$(json_extract "$response_body" "$field_path")
    
    if [[ -n "$field_value" && "$field_value" != "null" ]]; then
        print_success "JSON字段验证通过: $field_path 存在"
        return 0
    else
        print_error "JSON字段验证失败: $field_path 不存在或为null"
        return 1
    fi
}

# 验证JSON字段值
validate_json_field_value() {
    local field_path="$1"
    local expected_value="$2"
    local response_body
    response_body=$(get_response_body)
    
    if ! validate_json_response; then
        return 1
    fi
    
    local field_value
    field_value=$(json_extract "$response_body" "$field_path")
    
    if [[ "$field_value" == "$expected_value" ]]; then
        print_success "JSON字段值验证通过: $field_path = $expected_value"
        return 0
    else
        print_error "JSON字段值验证失败: $field_path 期望 '$expected_value', 实际 '$field_value'"
        return 1
    fi
}

# 验证JSON字段类型
validate_json_field_type() {
    local field_path="$1"
    local expected_type="$2"
    local response_body
    response_body=$(get_response_body)
    
    if ! validate_json_response; then
        return 1
    fi
    
    local field_type
    field_type=$(echo "$response_body" | jq -r "type($field_path)" 2>/dev/null)
    
    if [[ "$field_type" == "$expected_type" ]]; then
        print_success "JSON字段类型验证通过: $field_path 是 $expected_type"
        return 0
    else
        print_error "JSON字段类型验证失败: $field_path 期望 $expected_type, 实际 $field_type"
        return 1
    fi
}

# 验证JSON数组长度
validate_json_array_length() {
    local array_path="$1"
    local expected_length="$2"
    local response_body
    response_body=$(get_response_body)
    
    if ! validate_json_response; then
        return 1
    fi
    
    local array_length
    array_length=$(echo "$response_body" | jq -r "length($array_path)" 2>/dev/null)
    
    if [[ "$array_length" == "$expected_length" ]]; then
        print_success "JSON数组长度验证通过: $array_path 长度为 $expected_length"
        return 0
    else
        print_error "JSON数组长度验证失败: $array_path 期望长度 $expected_length, 实际 $array_length"
        return 1
    fi
}

# 验证JSON数组包含元素
validate_json_array_contains() {
    local array_path="$1"
    local expected_value="$2"
    local response_body
    response_body=$(get_response_body)
    
    if ! validate_json_response; then
        return 1
    fi
    
    local contains_check
    contains_check=$(echo "$response_body" | jq -r "any($array_path[]; . == \"$expected_value\")" 2>/dev/null)
    
    if [[ "$contains_check" == "true" ]]; then
        print_success "JSON数组元素验证通过: $array_path 包含 '$expected_value'"
        return 0
    else
        print_error "JSON数组元素验证失败: $array_path 不包含 '$expected_value'"
        return 1
    fi
}

# 验证响应体包含文本
validate_response_contains() {
    local expected_text="$1"
    local response_body
    response_body=$(get_response_body)
    
    if [[ "$response_body" == *"$expected_text"* ]]; then
        print_success "响应内容验证通过: 包含 '$expected_text'"
        return 0
    else
        print_error "响应内容验证失败: 不包含 '$expected_text'"
        return 1
    fi
}

# 验证响应体不包含文本
validate_response_not_contains() {
    local unexpected_text="$1"
    local response_body
    response_body=$(get_response_body)
    
    if [[ "$response_body" != *"$unexpected_text"* ]]; then
        print_success "响应内容验证通过: 不包含 '$unexpected_text'"
        return 0
    else
        print_error "响应内容验证失败: 包含了不应该存在的文本 '$unexpected_text'"
        return 1
    fi
}

# 验证响应体匹配正则表达式
validate_response_matches() {
    local regex_pattern="$1"
    local response_body
    response_body=$(get_response_body)
    
    if [[ "$response_body" =~ $regex_pattern ]]; then
        print_success "响应内容验证通过: 匹配正则表达式"
        return 0
    else
        print_error "响应内容验证失败: 不匹配正则表达式 '$regex_pattern'"
        return 1
    fi
}

# 验证响应体为空
validate_response_empty() {
    local response_body
    response_body=$(get_response_body)
    
    if [[ -z "$response_body" ]]; then
        print_success "响应体验证通过: 为空"
        return 0
    else
        print_error "响应体验证失败: 不为空"
        return 1
    fi
}

# 验证响应体非空
validate_response_not_empty() {
    local response_body
    response_body=$(get_response_body)
    
    if [[ -n "$response_body" ]]; then
        print_success "响应体验证通过: 非空"
        return 0
    else
        print_error "响应体验证失败: 为空"
        return 1
    fi
}

# 验证响应时间
validate_response_time() {
    local max_time="$1"
    local actual_time
    
    # 从curl的输出中获取响应时间
    actual_time=$(get_response_header "X-Response-Time" || echo "0")
    
    if [[ -z "$actual_time" || "$actual_time" == "0" ]]; then
        print_warning "无法获取响应时间信息"
        return 0
    fi
    
    if (( $(echo "$actual_time <= $max_time" | bc -l) )); then
        print_success "响应时间验证通过: ${actual_time}s <= ${max_time}s"
        return 0
    else
        print_error "响应时间验证失败: ${actual_time}s > ${max_time}s"
        return 1
    fi
}

# 验证标准成功响应
validate_success_response() {
    local success_field="${SUCCESS_RESPONSE_FIELD:-success}"
    local data_field="${DATA_FIELD:-data}"
    
    # 验证状态码
    if ! validate_status_code_in "$SUCCESS_STATUS_CODES"; then
        return 1
    fi
    
    # 验证JSON格式
    if ! validate_json_response; then
        return 1
    fi
    
    # 验证成功标识字段
    if [[ -n "$success_field" ]]; then
        if ! validate_json_field_value ".$success_field" "true"; then
            return 1
        fi
    fi
    
    print_success "标准成功响应验证通过"
    return 0
}

# 验证标准错误响应
validate_error_response() {
    local error_field="${ERROR_MESSAGE_FIELD:-message}"
    
    # 验证状态码不在成功范围内
    local status_code
    status_code=$(get_status_code)
    
    IFS=',' read -ra success_codes <<< "$SUCCESS_STATUS_CODES"
    for code in "${success_codes[@]}"; do
        if [[ "$status_code" == "$code" ]]; then
            print_error "错误响应验证失败: 状态码 $status_code 在成功范围内"
            return 1
        fi
    done
    
    # 验证JSON格式
    if ! validate_json_response; then
        return 1
    fi
    
    # 验证错误信息字段存在
    if [[ -n "$error_field" ]]; then
        if ! validate_json_field_exists ".$error_field"; then
            return 1
        fi
    fi
    
    print_success "标准错误响应验证通过"
    return 0
}

# 组合验证器
run_validations() {
    local validations=("$@")
    local failed_count=0
    local total_count=${#validations[@]}
    
    echo "开始执行 $total_count 个验证..."
    
    for validation in "${validations[@]}"; do
        if eval "$validation"; then
            log_debug "验证通过: $validation"
        else
            log_error "验证失败: $validation"
            ((failed_count++))
        fi
    done
    
    echo "验证结果: $((total_count - failed_count))/$total_count 通过"
    
    if [[ $failed_count -eq 0 ]]; then
        print_success "所有验证都通过了"
        return 0
    else
        print_error "$failed_count 个验证失败"
        return 1
    fi
}