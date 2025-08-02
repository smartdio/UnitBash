#!/bin/bash

# 配置管理模块
# ===================================

# 全局变量
CONFIG_DIR="$(dirname "${BASH_SOURCE[0]}")/../config"
CURRENT_ENV="${ENVIRONMENT:-dev}"
CONFIG_LOADED=false

# 加载配置文件
load_config() {
    local env="${1:-$CURRENT_ENV}"
    local config_file="$CONFIG_DIR/${env}.conf"
    
    if [[ ! -f "$config_file" ]]; then
        echo "错误: 配置文件不存在: $config_file" >&2
        return 1
    fi
    
    # 加载环境变量文件
    if [[ -f "$CONFIG_DIR/.env" ]]; then
        set -a  # 自动导出变量
        source "$CONFIG_DIR/.env"
        set +a
    fi
    
    # 加载配置文件
    source "$config_file"
    CONFIG_LOADED=true
    
    log_info "已加载配置环境: $env"
    return 0
}

# 验证配置完整性
validate_config() {
    local required_vars=(
        "API_BASE_URL"
        "AUTH_LOGIN_URL"
        "AUTH_USERNAME_FIELD"
        "AUTH_PASSWORD_FIELD"
        "JWT_TOKEN_FIELD"
        "SUCCESS_STATUS_CODES"
    )
    
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        echo "错误: 缺少必需的配置项:" >&2
        printf '  %s\n' "${missing_vars[@]}" >&2
        return 1
    fi
    
    # 验证URL格式
    if ! validate_url "$API_BASE_URL"; then
        echo "错误: API_BASE_URL 格式无效: $API_BASE_URL" >&2
        return 1
    fi
    
    log_info "配置验证通过"
    return 0
}

# 验证URL格式
validate_url() {
    local url="$1"
    if [[ "$url" =~ ^https?://[a-zA-Z0-9.-]+([:]?[0-9]+)?(/.*)?$ ]]; then
        return 0
    else
        return 1
    fi
}

# 获取完整API URL
get_api_url() {
    local endpoint="$1"
    local base_url="${API_BASE_URL%/}"  # 移除尾部斜杠
    local version_path=""
    
    if [[ -n "$API_VERSION" ]]; then
        version_path="/$API_VERSION"
    fi
    
    # 处理endpoint开头的斜杠
    if [[ "$endpoint" != /* ]]; then
        endpoint="/$endpoint"
    fi
    
    echo "${base_url}${version_path}${endpoint}"
}

# 获取认证URL
get_auth_url() {
    local auth_type="${1:-login}"
    local auth_url=""
    
    case "$auth_type" in
        "login")
            auth_url="$AUTH_LOGIN_URL"
            ;;
        "refresh")
            auth_url="$AUTH_REFRESH_URL"
            ;;
        "logout")
            auth_url="$AUTH_LOGOUT_URL"
            ;;
        *)
            echo "错误: 不支持的认证类型: $auth_type" >&2
            return 1
            ;;
    esac
    
    get_api_url "$auth_url"
}

# 检查是否需要加载配置
ensure_config_loaded() {
    if [[ "$CONFIG_LOADED" != true ]]; then
        load_config || return 1
        validate_config || return 1
    fi
}

# 获取配置值
get_config() {
    local key="$1"
    local default_value="$2"
    
    ensure_config_loaded || return 1
    
    local value="${!key}"
    echo "${value:-$default_value}"
}

# 设置当前环境
set_environment() {
    local env="$1"
    CURRENT_ENV="$env"
    CONFIG_LOADED=false
    
    load_config "$env"
}

# 显示当前配置
show_config() {
    ensure_config_loaded || return 1
    
    echo "当前配置环境: $CURRENT_ENV"
    echo "API基础URL: $API_BASE_URL"
    echo "API版本: ${API_VERSION:-无}"
    echo "登录URL: $(get_auth_url login)"
    echo "超时时间: ${API_TIMEOUT}秒"
    echo "重试次数: $API_RETRY_COUNT"
    echo "JWT Token字段: $JWT_TOKEN_FIELD"
    echo "Token类型: $JWT_TOKEN_TYPE"
}

# 日志函数（依赖lib.sh，这里提供基础版本）
log_info() {
    local message="$1"
    if [[ "${VERBOSE:-false}" == true ]] || [[ "${LOG_LEVEL:-INFO}" == "DEBUG" ]]; then
        echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $message" >&2
    fi
}