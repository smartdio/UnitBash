#!/bin/bash

# 数据处理模块
# ===================================

# 导入依赖
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/lib.sh"
source "$SCRIPT_DIR/config.sh"

# 全局变量
MOCK_DATA_DIR="$(dirname "${BASH_SOURCE[0]}")/../mock"

# 生成随机用户数据
generate_user_data() {
    local username_prefix="${1:-user}"
    local domain="${2:-example.com}"
    
    local random_id
    random_id=$(random_string 8)
    local username="${username_prefix}_${random_id}"
    local email="${username}@${domain}"
    local phone="138$(random_string 8)"
    
    jq -n \
        --arg username "$username" \
        --arg email "$email" \
        --arg phone "$phone" \
        --arg password "password123" \
        --arg firstName "测试" \
        --arg lastName "用户${random_id}" \
        '{
            username: $username,
            email: $email,
            phone: $phone,
            password: $password,
            firstName: $firstName,
            lastName: $lastName,
            createdAt: now | strftime("%Y-%m-%dT%H:%M:%SZ")
        }'
}

# 生成随机产品数据
generate_product_data() {
    local name_prefix="${1:-产品}"
    local category="${2:-电子产品}"
    
    local random_id
    random_id=$(random_string 6)
    local product_name="${name_prefix}_${random_id}"
    local price=$(( RANDOM % 10000 + 100 ))
    local stock=$(( RANDOM % 1000 + 10 ))
    
    jq -n \
        --arg name "$product_name" \
        --arg category "$category" \
        --arg description "这是一个测试产品: $product_name" \
        --arg price "$price" \
        --arg stock "$stock" \
        --arg sku "SKU${random_id}" \
        '{
            name: $name,
            category: $category,
            description: $description,
            price: ($price | tonumber),
            stock: ($stock | tonumber),
            sku: $sku,
            status: "active",
            createdAt: now | strftime("%Y-%m-%dT%H:%M:%SZ")
        }'
}

# 生成随机订单数据
generate_order_data() {
    local user_id="${1:-1}"
    local product_count="${2:-3}"
    
    local order_id
    order_id=$(random_string 10)
    local total_amount=$(( RANDOM % 50000 + 1000 ))
    
    # 生成订单项
    local items_json="[]"
    for ((i=1; i<=product_count; i++)); do
        local item_id=$(( RANDOM % 1000 + 1 ))
        local quantity=$(( RANDOM % 5 + 1 ))
        local price=$(( RANDOM % 5000 + 100 ))
        
        local item
        item=$(jq -n \
            --arg productId "$item_id" \
            --arg quantity "$quantity" \
            --arg price "$price" \
            '{
                productId: ($productId | tonumber),
                quantity: ($quantity | tonumber),
                price: ($price | tonumber)
            }')
        
        items_json=$(echo "$items_json" | jq ". + [$item]")
    done
    
    jq -n \
        --arg orderId "$order_id" \
        --arg userId "$user_id" \
        --arg totalAmount "$total_amount" \
        --argjson items "$items_json" \
        '{
            orderId: $orderId,
            userId: ($userId | tonumber),
            items: $items,
            totalAmount: ($totalAmount | tonumber),
            status: "pending",
            paymentStatus: "unpaid",
            shippingAddress: {
                street: "测试街道123号",
                city: "测试城市",
                province: "测试省份",
                zipCode: "100000"
            },
            createdAt: now | strftime("%Y-%m-%dT%H:%M:%SZ")
        }'
}

# 从模板生成数据
generate_from_template() {
    local template_file="$1"
    local variables_json="${2:-{}}"
    
    if [[ ! -f "$template_file" ]]; then
        log_error "模板文件不存在: $template_file"
        return 1
    fi
    
    local template_content
    template_content=$(cat "$template_file")
    
    # 替换变量
    echo "$template_content" | jq --argjson vars "$variables_json" '
        . as $template |
        $vars |
        to_entries |
        reduce .[] as $item ($template;
            . | gsub("\\$\\{" + $item.key + "\\}"; $item.value | tostring)
        )
    '
}

# 加载模拟数据
load_mock_data() {
    local data_type="$1"
    local mock_file="$MOCK_DATA_DIR/${data_type}.json"
    
    if [[ ! -f "$mock_file" ]]; then
        log_error "模拟数据文件不存在: $mock_file"
        return 1
    fi
    
    cat "$mock_file"
}

# 获取随机模拟数据项
get_random_mock_item() {
    local data_type="$1"
    local mock_data
    mock_data=$(load_mock_data "$data_type") || return 1
    
    local count
    count=$(echo "$mock_data" | jq 'length')
    
    if [[ $count -eq 0 ]]; then
        log_error "模拟数据为空: $data_type"
        return 1
    fi
    
    local random_index=$(( RANDOM % count ))
    echo "$mock_data" | jq ".[$random_index]"
}

# 创建分页数据
create_paginated_data() {
    local data_array="$1"
    local page="${2:-1}"
    local page_size="${3:-10}"
    
    local total_count
    total_count=$(echo "$data_array" | jq 'length')
    
    local offset=$(( (page - 1) * page_size ))
    local total_pages=$(( (total_count + page_size - 1) / page_size ))
    
    local page_data
    page_data=$(echo "$data_array" | jq --arg offset "$offset" --arg limit "$page_size" '.[$offset | tonumber:($offset | tonumber) + ($limit | tonumber)]')
    
    jq -n \
        --argjson data "$page_data" \
        --arg page "$page" \
        --arg pageSize "$page_size" \
        --arg totalCount "$total_count" \
        --arg totalPages "$total_pages" \
        '{
            data: $data,
            pagination: {
                page: ($page | tonumber),
                pageSize: ($pageSize | tonumber),
                totalCount: ($totalCount | tonumber),
                totalPages: ($totalPages | tonumber),
                hasNext: (($page | tonumber) < ($totalPages | tonumber)),
                hasPrev: (($page | tonumber) > 1)
            }
        }'
}

# 数据验证函数
validate_email() {
    local email="$1"
    if [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}

validate_phone() {
    local phone="$1"
    if [[ "$phone" =~ ^[0-9]{11}$ ]]; then
        return 0
    else
        return 1
    fi
}

validate_required_fields() {
    local json_data="$1"
    local required_fields="$2"
    
    IFS=',' read -ra fields <<< "$required_fields"
    for field in "${fields[@]}"; do
        local value
        value=$(json_extract "$json_data" ".$field")
        
        if [[ -z "$value" || "$value" == "null" ]]; then
            log_error "必需字段缺失: $field"
            return 1
        fi
    done
    
    return 0
}

# 数据清理函数
clean_json_data() {
    local json_data="$1"
    local fields_to_remove="${2:-password,secret}"
    
    local cleaned_data="$json_data"
    
    IFS=',' read -ra fields <<< "$fields_to_remove"
    for field in "${fields[@]}"; do
        cleaned_data=$(echo "$cleaned_data" | jq "del(.$field)")
    done
    
    echo "$cleaned_data"
}

# 数据转换函数
json_to_form_data() {
    local json_data="$1"
    
    echo "$json_data" | jq -r 'to_entries | map("\(.key)=\(.value | @uri)") | join("&")'
}

form_data_to_json() {
    local form_data="$1"
    local json="{}"
    
    IFS='&' read -ra pairs <<< "$form_data"
    for pair in "${pairs[@]}"; do
        if [[ "$pair" == *"="* ]]; then
            local key="${pair%%=*}"
            local value="${pair#*=}"
            # URL解码
            value=$(printf '%b' "${value//%/\\x}")
            json=$(echo "$json" | jq --arg k "$key" --arg v "$value" '. + {($k): $v}')
        fi
    done
    
    echo "$json"
}

# 数据合并函数
merge_json_objects() {
    local base_json="$1"
    local overlay_json="$2"
    
    echo "$base_json" | jq --argjson overlay "$overlay_json" '. + $overlay'
}

# 数据过滤函数
filter_json_fields() {
    local json_data="$1"
    local fields="$2"
    
    local select_expr=""
    IFS=',' read -ra field_array <<< "$fields"
    for field in "${field_array[@]}"; do
        if [[ -n "$select_expr" ]]; then
            select_expr="${select_expr}, "
        fi
        select_expr="${select_expr}${field}: .${field}"
    done
    
    echo "$json_data" | jq "{$select_expr}"
}

# 批量数据生成
generate_batch_data() {
    local generator_function="$1"
    local count="$2"
    local args=("${@:3}")
    
    local batch_data="[]"
    
    for ((i=1; i<=count; i++)); do
        local item_data
        item_data=$("$generator_function" "${args[@]}")
        batch_data=$(echo "$batch_data" | jq ". + [$item_data]")
    done
    
    echo "$batch_data"
}

# 数据排序
sort_json_array() {
    local json_array="$1"
    local sort_field="$2"
    local sort_order="${3:-asc}"
    
    if [[ "$sort_order" == "desc" ]]; then
        echo "$json_array" | jq "sort_by(.$sort_field) | reverse"
    else
        echo "$json_array" | jq "sort_by(.$sort_field)"
    fi
}