#!/bin/bash

# 通用工具函数库
# ===================================

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# 日志级别
readonly LOG_DEBUG=0
readonly LOG_INFO=1
readonly LOG_WARN=2
readonly LOG_ERROR=3

# 当前日志级别
CURRENT_LOG_LEVEL=$LOG_INFO

# 设置日志级别
set_log_level() {
    local level="$1"
    case "$level" in
        "DEBUG") CURRENT_LOG_LEVEL=$LOG_DEBUG ;;
        "INFO")  CURRENT_LOG_LEVEL=$LOG_INFO ;;
        "WARN")  CURRENT_LOG_LEVEL=$LOG_WARN ;;
        "ERROR") CURRENT_LOG_LEVEL=$LOG_ERROR ;;
        *) log_error "无效的日志级别: $level" ;;
    esac
}

# 日志函数
log_debug() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_DEBUG ]] && echo -e "${CYAN}[DEBUG]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_info() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_INFO ]] && echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_warn() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_WARN ]] && echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_error() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_ERROR ]] && echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

# 成功/失败提示
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# 检查命令是否存在
check_command() {
    local cmd="$1"
    if ! command -v "$cmd" &> /dev/null; then
        log_error "命令不存在: $cmd"
        return 1
    fi
    return 0
}

# 检查必需的命令
check_required_commands() {
    local commands=("curl" "jq" "grep" "sed" "awk")
    local missing_commands=()
    
    for cmd in "${commands[@]}"; do
        if ! check_command "$cmd"; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log_error "缺少必需的命令:"
        printf '  %s\n' "${missing_commands[@]}" >&2
        return 1
    fi
    
    return 0
}

# 创建目录
ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" || {
            log_error "无法创建目录: $dir"
            return 1
        }
        log_debug "创建目录: $dir"
    fi
}

# 生成时间戳
timestamp() {
    date '+%Y%m%d_%H%M%S'
}

# 生成随机字符串
random_string() {
    local length="${1:-8}"
    tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c "$length"
}

# URL编码
url_encode() {
    local string="$1"
    printf '%s' "$string" | jq -sRr @uri
}

# JSON解析辅助函数
json_extract() {
    local json="$1"
    local path="$2"
    local default="${3:-}"
    
    if [[ -z "$json" ]]; then
        echo "$default"
        return 1
    fi
    
    local result
    result=$(echo "$json" | jq -r "$path" 2>/dev/null)
    
    if [[ "$result" == "null" || -z "$result" ]]; then
        echo "$default"
        return 1
    else
        echo "$result"
        return 0
    fi
}

# 检查JSON格式
is_valid_json() {
    local json="$1"
    echo "$json" | jq . &>/dev/null
}

# 格式化JSON输出
format_json() {
    local json="$1"
    if is_valid_json "$json"; then
        echo "$json" | jq .
    else
        echo "$json"
    fi
}

# 文件存在检查
file_exists() {
    [[ -f "$1" ]]
}

# 目录存在检查
dir_exists() {
    [[ -d "$1" ]]
}

# 等待用户输入
wait_for_enter() {
    local message="${1:-按回车键继续...}"
    echo -n "$message"
    read -r
}

# 确认提示
confirm() {
    local message="$1"
    local default="${2:-n}"
    local prompt="[y/N]"
    
    if [[ "$default" == "y" || "$default" == "Y" ]]; then
        prompt="[Y/n]"
    fi
    
    while true; do
        echo -n "$message $prompt: "
        read -r response
        
        # 使用默认值
        if [[ -z "$response" ]]; then
            response="$default"
        fi
        
        case "$response" in
            [Yy]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo]) return 1 ;;
            *) echo "请输入 y 或 n" ;;
        esac
    done
}

# 计算文件MD5
file_md5() {
    local file="$1"
    if [[ -f "$file" ]]; then
        if command -v md5sum &>/dev/null; then
            md5sum "$file" | cut -d' ' -f1
        elif command -v md5 &>/dev/null; then
            md5 -q "$file"
        else
            log_error "MD5命令不可用"
            return 1
        fi
    else
        log_error "文件不存在: $file"
        return 1
    fi
}

# 重试执行命令
retry_command() {
    local max_attempts="$1"
    local delay="$2"
    shift 2
    local command=("$@")
    
    local attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        log_debug "执行命令 (尝试 $attempt/$max_attempts): ${command[*]}"
        
        if "${command[@]}"; then
            return 0
        else
            local exit_code=$?
            log_warn "命令执行失败 (尝试 $attempt/$max_attempts): ${command[*]}"
            
            if [[ $attempt -lt $max_attempts ]]; then
                log_info "等待 ${delay}秒后重试..."
                sleep "$delay"
            fi
            
            ((attempt++))
        fi
    done
    
    log_error "命令执行失败，已达到最大重试次数: ${command[*]}"
    return $exit_code
}

# 初始化日志级别
if [[ -n "${LOG_LEVEL:-}" ]]; then
    set_log_level "$LOG_LEVEL"
fi