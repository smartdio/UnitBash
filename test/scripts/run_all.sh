#!/bin/bash

# 批量执行测试脚本
# ===================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_ROOT="$(dirname "$SCRIPT_DIR")"

# 导入公共库
source "$TEST_ROOT/common/lib.sh"
source "$TEST_ROOT/common/config.sh"

# 默认参数
ENVIRONMENT="${ENVIRONMENT:-dev}"
TEST_PATTERN="${TEST_PATTERN:-test_*.sh}"
PARALLEL="${PARALLEL:-false}"
REPORT_FILE=""
VERBOSE="${VERBOSE:-false}"

# 显示帮助信息
show_help() {
    cat << EOF
UnitBash 批量测试执行器

用法: $0 [选项] [测试目录...]

选项:
  -e, --env ENV         指定环境 (dev/test/prod)
  -p, --pattern PATTERN 测试文件匹配模式 (默认: test_*.sh)
  -j, --parallel        并行执行测试
  -r, --report FILE     生成测试报告到指定文件
  -v, --verbose         详细输出
  -h, --help            显示帮助信息

示例:
  $0                              # 运行所有测试
  $0 system                       # 只运行system目录的测试
  $0 -e test -p "test_user*.sh"   # 在test环境运行用户相关测试
  $0 -j -r report.json            # 并行执行并生成报告

EOF
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--env)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -p|--pattern)
                TEST_PATTERN="$2"
                shift 2
                ;;
            -j|--parallel)
                PARALLEL=true
                shift
                ;;
            -r|--report)
                REPORT_FILE="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                print_error "未知选项: $1"
                show_help
                exit 1
                ;;
            *)
                TEST_DIRS+=("$1")
                shift
                ;;
        esac
    done
}

# 查找测试文件
find_test_files() {
    local search_dirs=("${TEST_DIRS[@]}")
    
    if [[ ${#search_dirs[@]} -eq 0 ]]; then
        search_dirs=("system" "modules")
    fi
    
    local test_files=()
    
    for dir in "${search_dirs[@]}"; do
        local test_dir="$TEST_ROOT/$dir"
        if [[ -d "$test_dir" ]]; then
            while IFS= read -r -d '' file; do
                test_files+=("$file")
            done < <(find "$test_dir" -name "$TEST_PATTERN" -type f -print0 2>/dev/null || true)
        else
            print_warning "测试目录不存在: $dir"
        fi
    done
    
    printf '%s\n' "${test_files[@]}"
}

# 执行单个测试文件
run_test_file() {
    local test_file="$1"
    local test_name
    test_name=$(basename "$test_file" .sh)
    
    print_info "执行测试: $test_name"
    
    local start_time
    start_time=$(date +%s)
    
    local output_file
    output_file=$(mktemp)
    
    local exit_code=0
    
    # 设置环境变量
    export ENVIRONMENT="$ENVIRONMENT"
    export VERBOSE="$VERBOSE"
    
    # 执行测试
    if bash "$test_file" > "$output_file" 2>&1; then
        exit_code=0
        print_success "测试通过: $test_name"
    else
        exit_code=$?
        print_error "测试失败: $test_name (退出码: $exit_code)"
    fi
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # 输出详细信息
    if [[ "$VERBOSE" == true ]] || [[ $exit_code -ne 0 ]]; then
        echo "--- 测试输出 ($test_name) ---"
        cat "$output_file"
        echo "--- 测试结束 ---"
    fi
    
    # 清理临时文件
    rm -f "$output_file"
    
    # 返回测试结果
    echo "$test_name,$exit_code,$duration"
    return $exit_code
}

# 并行执行测试
run_tests_parallel() {
    local test_files=("$@")
    local temp_dir
    temp_dir=$(mktemp -d)
    
    print_info "并行执行 ${#test_files[@]} 个测试..."
    
    # 启动所有测试
    local pids=()
    for test_file in "${test_files[@]}"; do
        local result_file="$temp_dir/$(basename "$test_file").result"
        (run_test_file "$test_file" > "$result_file") &
        pids+=($!)
    done
    
    # 等待所有测试完成
    local failed_count=0
    for pid in "${pids[@]}"; do
        if ! wait $pid; then
            ((failed_count++))
        fi
    done
    
    # 收集结果
    local results=()
    for test_file in "${test_files[@]}"; do
        local result_file="$temp_dir/$(basename "$test_file").result"
        if [[ -f "$result_file" ]]; then
            results+=("$(cat "$result_file")")
        fi
    done
    
    # 清理临时目录
    rm -rf "$temp_dir"
    
    printf '%s\n' "${results[@]}"
    return $failed_count
}

# 串行执行测试
run_tests_serial() {
    local test_files=("$@")
    local results=()
    local failed_count=0
    
    print_info "串行执行 ${#test_files[@]} 个测试..."
    
    for test_file in "${test_files[@]}"; do
        local result
        if result=$(run_test_file "$test_file"); then
            results+=("$result")
        else
            results+=("$result")
            ((failed_count++))
        fi
    done
    
    printf '%s\n' "${results[@]}"
    return $failed_count
}

# 生成测试报告
generate_report() {
    local results=("$@")
    local report_data="[]"
    local total_tests=0
    local passed_tests=0
    local failed_tests=0
    local total_duration=0
    
    for result in "${results[@]}"; do
        IFS=',' read -r name exit_code duration <<< "$result"
        
        ((total_tests++))
        ((total_duration+=duration))
        
        local status="passed"
        if [[ $exit_code -ne 0 ]]; then
            status="failed"
            ((failed_tests++))
        else
            ((passed_tests++))
        fi
        
        local test_result
        test_result=$(jq -n \
            --arg name "$name" \
            --arg status "$status" \
            --arg exitCode "$exit_code" \
            --arg duration "$duration" \
            '{
                name: $name,
                status: $status,
                exitCode: ($exitCode | tonumber),
                duration: ($duration | tonumber)
            }')
        
        report_data=$(echo "$report_data" | jq ". + [$test_result]")
    done
    
    # 生成完整报告
    local report
    report=$(jq -n \
        --argjson tests "$report_data" \
        --arg environment "$ENVIRONMENT" \
        --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        --arg totalTests "$total_tests" \
        --arg passedTests "$passed_tests" \
        --arg failedTests "$failed_tests" \
        --arg totalDuration "$total_duration" \
        '{
            environment: $environment,
            timestamp: $timestamp,
            summary: {
                total: ($totalTests | tonumber),
                passed: ($passedTests | tonumber),
                failed: ($failedTests | tonumber),
                duration: ($totalDuration | tonumber)
            },
            tests: $tests
        }')
    
    if [[ -n "$REPORT_FILE" ]]; then
        echo "$report" > "$REPORT_FILE"
        print_info "测试报告已保存到: $REPORT_FILE"
    fi
    
    echo "$report"
}

# 显示测试总结
show_summary() {
    local report="$1"
    
    local total
    total=$(echo "$report" | jq -r '.summary.total')
    local passed
    passed=$(echo "$report" | jq -r '.summary.passed')
    local failed
    failed=$(echo "$report" | jq -r '.summary.failed')
    local duration
    duration=$(echo "$report" | jq -r '.summary.duration')
    
    echo ""
    echo "测试执行总结"
    echo "============"
    echo "环境: $ENVIRONMENT"
    echo "总测试数: $total"
    echo "通过: $passed"
    echo "失败: $failed"
    echo "总耗时: ${duration}秒"
    echo "成功率: $(( passed * 100 / total ))%"
    
    if [[ $failed -eq 0 ]]; then
        print_success "所有测试都通过了！"
    else
        print_error "$failed 个测试失败"
        
        echo ""
        echo "失败的测试:"
        echo "$report" | jq -r '.tests[] | select(.status == "failed") | "  - \(.name) (退出码: \(.exitCode))"'
    fi
}

# 主函数
main() {
    local TEST_DIRS=()
    
    parse_args "$@"
    
    echo "UnitBash 测试执行器"
    echo "==================="
    
    # 初始化环境
    if ! load_config "$ENVIRONMENT"; then
        print_error "环境配置加载失败: $ENVIRONMENT"
        exit 1
    fi
    
    if ! validate_config; then
        print_error "配置验证失败"
        exit 1
    fi
    
    print_info "当前环境: $ENVIRONMENT"
    print_info "测试模式: $TEST_PATTERN"
    
    # 查找测试文件
    local test_files
    readarray -t test_files < <(find_test_files)
    
    if [[ ${#test_files[@]} -eq 0 ]]; then
        print_warning "未找到匹配的测试文件"
        exit 0
    fi
    
    print_info "找到 ${#test_files[@]} 个测试文件"
    
    # 执行测试
    local results
    local failed_count
    
    if [[ "$PARALLEL" == true ]]; then
        readarray -t results < <(run_tests_parallel "${test_files[@]}")
        failed_count=$?
    else
        readarray -t results < <(run_tests_serial "${test_files[@]}")
        failed_count=$?
    fi
    
    # 生成报告
    local report
    report=$(generate_report "${results[@]}")
    
    # 显示总结
    show_summary "$report"
    
    # 返回失败数量作为退出码
    exit $failed_count
}

# 执行主函数
main "$@"