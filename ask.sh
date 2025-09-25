#!/bin/bash

set -o pipefail

VERSION="0.0.2"

api_key=${SHELL_ASK_API_KEY:-""}
api_model=${SHELL_ASK_API_MODEL:-"gpt-5-nano"}
api_endpoint=${SHELL_ASK_API_ENDPOINT:-"https://api.openai.com/v1/chat/completions"}
answer_language=${SHELL_ASK_ANSWER_LANGUAGE:-"english"}
config_dir=${SHELL_ASK_CONFIG_DIR:-"$HOME/.config/ask.sh"}
config_file=${SHELL_ASK_CONFIG_FILE:-"$config_dir/config.json"}
timeout=${SHELL_ASK_TIMEOUT:-60}
debug=${SHELL_ASK_DEBUG:-false}

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Log functions
log_error() {
    echo -e "${RED}Error: $1${NC}" >&2
}

log_warning() {
    echo -e "${YELLOW}Warning: $1${NC}" >&2
}

log_info() {
    echo -e "${GREEN}Info: $1${NC}" >&2
}

log_debug() {
    if [ "$debug" = "true" ]; then
        echo -e "Debug: $1" >&2
    fi
}

check_dependencies() {
    local missing_deps=()
    
    if ! command -v curl >/dev/null 2>&1; then
        missing_deps+=("curl")
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        missing_deps+=("jq")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_info "Please install them using your package manager."
        log_info "For example: brew install curl jq (macOS) or apt-get install curl jq (Ubuntu)"
        exit 1
    fi
}

validate_config() {
    if [ -z "$api_key" ]; then
        log_error "API key is not set. Please set it using:"
        echo "  ask set-config api_key YOUR_API_KEY"
        echo "  or set SHELL_ASK_API_KEY environment variable"
        exit 1
    fi
    
    if [ -z "$api_endpoint" ]; then
        log_error "API endpoint is not set"
        exit 1
    fi
    
    if [ -z "$api_model" ]; then
        log_error "API model is not set"
        exit 1
    fi
}

escape_json() {
    local input="$1"
    echo "$input" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed 's/$/\\n/' | tr -d '\n' | sed 's/\\n$//'
}

send_request() {
    local content="$1"
    
    log_debug "Sending request to: $api_endpoint"
    log_debug "Using model: $api_model"
    
    local escaped_content=$(escape_json "$content")
    
    local body=$(jq -n \
        --arg content "$escaped_content" \
        --arg model "$api_model" \
        '{
            model: $model,
            messages: [{"role": "user", "content": $content}],
            temperature: 0.3
        }')
    
    log_debug "Request body: $body"
    
    local response
    local http_code
    
    response=$(curl -s -w "\n%{http_code}" \
        --connect-timeout 10 \
        --max-time "$timeout" \
        "$api_endpoint" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $api_key" \
        -d "$body" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        log_error "Failed to connect to API endpoint. Please check your internet connection and endpoint URL."
        exit 1
    fi
    
    http_code=$(echo "$response" | tail -n1)
    response_body=$(echo "$response" | sed '$d')
    
    log_debug "HTTP status code: $http_code"
    log_debug "Response body: $response_body"
    
    if [ "$http_code" -ne 200 ]; then
        log_error "API request failed with HTTP status: $http_code"
        
        local error_message=$(echo "$response_body" | jq -r '.error.message // .message // "Unknown error"' 2>/dev/null)
        if [ "$error_message" != "null" ] && [ -n "$error_message" ]; then
            log_error "Error details: $error_message"
        fi
        exit 1
    fi
    
    local error=$(echo "$response_body" | jq -r '.error.message // empty' 2>/dev/null)
    
    if [ -n "$error" ]; then
        log_error "API error: $error"
        exit 1
    fi
    
    local result=$(echo "$response_body" | jq -r '.choices[0].message.content // empty' 2>/dev/null)
    
    if [ -z "$result" ]; then
        log_error "Invalid response format from API"
        exit 1
    fi
    
    if declare -f after_ask > /dev/null; then
        after_ask "$result"
    else
        echo "$result"
    fi
}

ask() {
    local input=""
    local prompt="$1"
    local content=""

    if [ -p /dev/stdin ]; then
        input=$(cat -)
        log_debug "Read input from pipe: ${#input} characters"
    fi
    
    if [ -z "$prompt" ]; then
        log_error "Please provide a question or prompt"
        show_help
        exit 1
    fi
    
    if [ -n "$input" ]; then
        content="According to the following shell output, using $answer_language to answer the question below: $prompt

Here is the shell output:
$input"
    else
        local shell_name=$(basename "$SHELL")
        local os_name=$(uname)
        content="Return commands suitable for copy/pasting into $shell_name on $os_name. Do NOT include commentary NOR Markdown triple-backtick code blocks as your whole response will be copied into my terminal automatically.

The script should do this: $prompt"
    fi

    log_debug "Generated content length: ${#content} characters"
    send_request "$content"
}

ask_with_plugin() {
    local plugin_file="$1"
    local prompt="$2"
    local input=""

    if [ -p /dev/stdin ]; then
        input=$(cat -)
        log_debug "Read input from pipe for plugin: ${#input} characters"
    fi

    if [ ! -f "$plugin_file" ]; then
        log_error "Plugin not found: $plugin_file"
        exit 1
    fi
    
    if [ ! -r "$plugin_file" ]; then
        log_error "Cannot read plugin file: $plugin_file"
        exit 1
    fi

    (
        source "$plugin_file"
        
        if ! declare -f gen_content > /dev/null; then
            log_error "Plugin '$plugin_file' must implement 'gen_content' function"
            exit 1
        fi
        
        local content
        content=$(gen_content "$prompt" "$input")
        
        if [ $? -ne 0 ] || [ -z "$content" ]; then
            log_error "Plugin failed to generate content"
            exit 1
        fi
        
        log_debug "Plugin generated content length: ${#content} characters"
        send_request "$content"
    )
}

load_config() {
    if [ -f "$config_file" ]; then
        log_debug "Loading config from: $config_file"
        
        if ! jq empty "$config_file" >/dev/null 2>&1; then
            log_error "Invalid JSON format in config file: $config_file"
            exit 1
        fi
        
        local file_api_key=$(jq -r '.api_key // empty' "$config_file" 2>/dev/null)
        local file_api_model=$(jq -r '.api_model // empty' "$config_file" 2>/dev/null)
        local file_api_endpoint=$(jq -r '.api_endpoint // empty' "$config_file" 2>/dev/null)
        local file_answer_language=$(jq -r '.answer_language // empty' "$config_file" 2>/dev/null)
        local file_timeout=$(jq -r '.timeout // empty' "$config_file" 2>/dev/null)
        local file_debug=$(jq -r '.debug // empty' "$config_file" 2>/dev/null)
        
        [ -n "$file_api_key" ] && api_key="$file_api_key"
        [ -n "$file_api_model" ] && api_model="$file_api_model"
        [ -n "$file_api_endpoint" ] && api_endpoint="$file_api_endpoint"
        [ -n "$file_answer_language" ] && answer_language="$file_answer_language"
        [ -n "$file_timeout" ] && timeout="$file_timeout"
        [ -n "$file_debug" ] && debug="$file_debug"
        
        log_debug "Configuration loaded successfully"
    else
        log_debug "No config file found, using environment variables and defaults"
    fi
}

get_config() {
    local key="$1"
    
    if [ -z "$key" ]; then
        log_error "Configuration key is required"
        echo "Available keys: api_key, api_model, api_endpoint, answer_language, timeout, debug"
        exit 1
    fi
    
    if [ -f "$config_file" ]; then
        if ! jq empty "$config_file" >/dev/null 2>&1; then
            log_error "Invalid JSON format in config file: $config_file"
            exit 1
        fi
        
        local value=$(jq -r --arg key "$key" '.[$key] // empty' "$config_file" 2>/dev/null)
        if [ -n "$value" ]; then
            echo "$value"
            return
        fi
    fi
    
    case "$key" in
        api_key)
            echo "$api_key"
            ;;
        api_model)
            echo "$api_model"
            ;;
        api_endpoint)
            echo "$api_endpoint"
            ;;
        answer_language)
            echo "$answer_language"
            ;;
        timeout)
            echo "$timeout"
            ;;
        debug)
            echo "$debug"
            ;;
        *)
            log_error "Unknown configuration key: $key"
            exit 1
            ;;
    esac
}

set_config() {
    local key="$1"
    local value="$2"
    
    if [ -z "$key" ] || [ -z "$value" ]; then
        log_error "Both key and value are required"
        echo "Usage: ask set-config <key> <value>"
        echo "Available keys: api_key, api_model, api_endpoint, answer_language, timeout, debug"
        exit 1
    fi
    
    case "$key" in
        api_key|api_model|api_endpoint|answer_language|timeout|debug)
            ;;
        *)
            log_error "Invalid configuration key: $key"
            echo "Available keys: api_key, api_model, api_endpoint, answer_language, timeout, debug"
            exit 1
            ;;
    esac
    
    if [ ! -d "$config_dir" ]; then
        if ! mkdir -p "$config_dir"; then
            log_error "Failed to create config directory: $config_dir"
            exit 1
        fi
        log_debug "Created config directory: $config_dir"
    fi

    if [ ! -f "$config_file" ]; then
        local initial_config=$(jq -n \
            --arg api_key "$api_key" \
            --arg api_model "$api_model" \
            --arg api_endpoint "$api_endpoint" \
            --arg answer_language "$answer_language" \
            --argjson timeout "$timeout" \
            --arg debug "$debug" \
            '{
                api_key: $api_key,
                api_model: $api_model,
                api_endpoint: $api_endpoint,
                answer_language: $answer_language,
                timeout: $timeout,
                debug: $debug
            }')
        
        if ! echo "$initial_config" > "$config_file"; then
            log_error "Failed to create config file: $config_file"
            exit 1
        fi
        log_debug "Created config file: $config_file"
    fi
    
    if ! jq empty "$config_file" >/dev/null 2>&1; then
        log_error "Invalid JSON format in config file: $config_file"
        exit 1
    fi
    
    local temp_file="${config_file}.tmp.$$"
    if jq --arg key "$key" --arg value "$value" '.[$key] = $value' "$config_file" > "$temp_file"; then
        if mv "$temp_file" "$config_file"; then
            log_info "Configuration updated: $key = $value"
        else
            log_error "Failed to update config file"
            rm -f "$temp_file"
            exit 1
        fi
    else
        log_error "Failed to update configuration"
        rm -f "$temp_file"
        exit 1
    fi
}

install_plugin() {
    local url="$1"
    
    if [ -z "$url" ]; then
        log_error "Plugin URL is required"
        echo "Usage: ask install-plugin <url>"
        exit 1
    fi
    
    local plugin_name=$(basename "$url")
    local plugin_dir="$config_dir/plugins"
    local plugin_path="$plugin_dir/$plugin_name"
    
    if [ ! -d "$plugin_dir" ]; then
        if ! mkdir -p "$plugin_dir"; then
            log_error "Failed to create plugins directory: $plugin_dir"
            exit 1
        fi
        log_debug "Created plugins directory: $plugin_dir"
    fi
    
    log_info "Downloading plugin from: $url"
    if curl -s -f --connect-timeout 10 --max-time 30 "$url" > "$plugin_path"; then
        chmod +x "$plugin_path"
        log_info "Plugin installed successfully: $plugin_name"
        log_info "Usage: ask -p ${plugin_name%.*} [args]"
    else
        log_error "Failed to download plugin from: $url"
        rm -f "$plugin_path"
        exit 1
    fi
}

list_plugins() {
    local plugin_dir="$config_dir/plugins"
    
    if [ ! -d "$plugin_dir" ]; then
        echo "No plugins directory found"
        return
    fi
    
    local plugins=$(find "$plugin_dir" -name "*.sh" -type f 2>/dev/null)
    
    if [ -z "$plugins" ]; then
        echo "No plugins installed"
        return
    fi
    
    echo "Installed plugins:"
    while IFS= read -r plugin; do
        local name=$(basename "$plugin" .sh)
        echo "  $name"
    done <<< "$plugins"
}

show_help() {
    cat << EOF
shell-ask v$VERSION - Ask LLM directly from your terminal

USAGE:
    ask [OPTIONS] "your question"
    command | ask "explain this output"

OPTIONS:
    -p, --plugin <name>     Use a plugin
    -h, --help             Show this help message
    -v, --version          Show version
    --debug               Enable debug mode

CONFIGURATION:
    ask set-config <key> <value>    Set configuration
    ask get-config <key>            Get configuration
    ask list-plugins               List installed plugins
    ask install-plugin <url>       Install plugin from URL

CONFIGURATION KEYS:
    api_key          API key for LLM service
    api_model        Model name (e.g., gpt-3.5-turbo)
    api_endpoint     API endpoint URL
    answer_language  Language for responses (e.g., english, chinese)
    timeout          Request timeout in seconds (default: 30)
    debug            Enable debug mode (true/false)

ENVIRONMENT VARIABLES:
    SHELL_ASK_API_KEY          Override api_key
    SHELL_ASK_API_MODEL        Override api_model  
    SHELL_ASK_API_ENDPOINT     Override api_endpoint
    SHELL_ASK_ANSWER_LANGUAGE  Override answer_language
    SHELL_ASK_TIMEOUT          Override timeout
    SHELL_ASK_DEBUG            Override debug mode
    SHELL_ASK_CONFIG_FILE      Override config file path

EXAMPLES:
    ask "How to find files larger than 1GB?"
    ls -la | ask "What's taking up the most space?"
    ask -p translate "Hello world" english
    ask set-config api_key sk-xxx
    ask install-plugin https://raw.githubusercontent.com/TBXark/shell-ask/master/plugins/translate.sh

For more information, visit: https://github.com/TBXark/shell-ask
EOF
}

# Main script logic
main() {
    check_dependencies
    
    case "$1" in
        -h|--help|help)
            show_help
            exit 0
            ;;
        -v|--version|version)
            echo "shell-ask v$VERSION"
            exit 0
            ;;
        --debug)
            debug=true
            shift
            ;;
        set-config)
            set_config "$2" "$3"
            exit 0
            ;;
        get-config)
            get_config "$2"
            exit 0
            ;;
        list-plugins)
            list_plugins
            exit 0
            ;;
        install-plugin)
            install_plugin "$2"
            exit 0
            ;;
        -p|--plugin)
            if [ -z "$2" ]; then
                log_error "Plugin name is required"
                show_help
                exit 1
            fi
            
            load_config
            validate_config
            
            local plugin_file="$config_dir/plugins/$2.sh"
            local prompt="${*:3}"
            
            ask_with_plugin "$plugin_file" "$prompt"
            exit 0
            ;;
        "")
            log_error "Please provide a question or command"
            show_help
            exit 1
            ;;
        *)
            local args=()
            while [ $# -gt 0 ]; do
                case "$1" in
                    --debug)
                        debug=true
                        ;;
                    *)
                        args+=("$1")
                        ;;
                esac
                shift
            done
            
            load_config
            validate_config
            
            ask "${args[*]}"
            exit 0
            ;;
    esac
}

main "$@"
