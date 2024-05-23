#!/bin/bash

set -o pipefail

api_key=${SHELL_ASK_API_KEY:-""}
api_model=${SHELL_ASK_API_MODEL:-"gpt-3.5-turbo"}
api_endpoint=${SHELL_ASK_API_ENDPOINT:-"https://api.openai.com/v1/chat/completions"}
answer_language=${SHELL_ASK_ANSWER_LANGUAGE:-"english"}
config_dir=${SHELL_ASK_CONFIG_DIR:-"$HOME/.config/ask.sh"}
config_file=${SHELL_ASK_CONFIG_FILE:-"$config_dir/config.json"}


send_request() {
    local content=$1

    local body=$(jq -n --arg content "$content" --arg model "$api_model" '{
        model: "\($model)",
        messages: [{"role": "user", "content": "\($content)"}],
        temperature: 0.3
    }')

    local response=$(curl -s $api_endpoint \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $api_key" \
        -d "$body")
    
    local error=$(echo $response | jq -r '.error.message')

    if [ "$error" != "null" ]; then
        echo $error
    else
        echo $response | jq -r '.choices[0].message.content'
    fi
}

ask() {
    local input=""
    local content=""
    local prompt="$1"
    local content=""

    if [ -p /dev/stdin ]; then
        input=$(cat -)
    fi
    
    if [ ! -z "$input" ]; then
        content="According to the following shell output, using $answer_language to answer the question below: $prompt, here is the shell output: $input"
    else
        local shell_name=$(basename $SHELL)
        local os_name=$(uname)
        content="Return commands suitable for copy/pasting into $shell_name on $os_name. Do NOT include commentary NOR Markdown triple-backtick code blocks as your whole response will be copied into my terminal automatically.\n\nThe script should do this: $prompt"
    fi

    send_request "$content"
}

ask_with_plugin() {
    local input=""
    local plugin=$1
    local prompt=$2

    if [ -p /dev/stdin ]; then
        input=$(cat -)
    fi

    if [ -f "$plugin" ]; then
        source $plugin
        local content=$(gen_content $prompt $input)
        send_request "$content"
    else
        echo "Plugin not found: $plugin"
    fi
}

load_config() {
    if [ -f "$config_file" ]; then
        api_key=$(jq -r '.api_key' $config_file)
        api_model=$(jq -r '.api_model' $config_file)
        api_endpoint=$(jq -r '.api_endpoint' $config_file)
        answer_language=$(jq -r '.answer_language' $config_file)     
    fi
}

get_config() {
    local key=$1
    if [ -f "$config_file" ]; then
        jq -r --arg key "$key" '.[$key]' $config_file
    else
        case $key in
            api_key)
                echo $api_key
                ;;
            api_model)
                echo $api_model
                ;;
            api_endpoint)
                echo $api_endpoint
                ;;
            answer_language)
                echo $answer_language
                ;;
            *)
                echo "Key not found: $key"
                ;;
        esac
    fi
}

set_config() {
    if [ ! -d "$config_dir" ]; then
        mkdir -p $config_dir
    fi

    if [ ! -f "$config_file" ]; then
        jq -n --arg api_key "$api_key" --arg api_model "$api_model" --arg api_endpoint "$api_endpoint" --arg answer_language "$answer_language" '{
            api_key: $api_key,
            api_model: $api_model,
            api_endpoint: $api_endpoint,
            answer_language: $answer_language
        }' > $config_file
    fi

    local key=$1
    local value=$2
    
    jq -r --arg key "$key" --arg value "$value" '.[$key] = $value' $config_file > tmp.$$.json && mv tmp.$$.json $config_file
}

install_plugin() {
    local url=$1
    local name=$(basename $url)

    if [ ! -d "$config_dir/plugins" ]; then
        mkdir -p $config_dir/plugins
    fi
    
    curl -s $url > $config_dir/plugins/$name
}

case $1 in
    set-config)
        set_config $2 $3
        ;;
    get-config)
        get_config $2
        ;;
    install-plugin)
        install_plugin $2
        ;;
    -p|--plugin)
        load_config
        plugin=$config_dir/plugins/$2.sh
        prompt=${@:3}
        if [ -f "$plugin" ]; then
            ask_with_plugin $plugin $prompt
        else
            echo "Plugin not found: $plugin"
        fi
        ;;
    *)
        load_config
        ask "$*"
        ;;
esac
