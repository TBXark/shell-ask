#!/bin/bash

api_key=${SHELL_ASK_API_KEY:-""}
api_model=${SHELL_ASK_API_MODEL:-"gpt-3.5-turbo"}
api_endpoint=${SHELL_ASK_API_ENDPOINT:-"https://api.openai.com/v1/chat/completions"}
answer_language=${SHELL_ASK_ANSWER_LANGUAGE:-"english"}
config_dir=${SHELL_ASK_CONFIG_DIR:-"$HOME/.config/ask.sh"}
config_file=${SHELL_ASK_CONFIG_FILE:-"$config_dir/config.json"}


ask() {
    local input=""
    local content=""
    local prompt="$1"
    if [ -p /dev/stdin ]; then
        input=$(cat -)
    fi
    
    if [ ! -z "$input" ]; then
        content="According to the following shell output, using $answer_language to answer the question below: $prompt, here is the shell output: $input"
    else
        shell_name=$(basename $SHELL)
        os_name=$(uname)
        content="Return commands suitable for copy/pasting into $shell_name on $os_name. Do NOT include commentary NOR Markdown triple-backtick code blocks as your whole response will be copied into my terminal automatically.\n\nThe script should do this: $prompt"
    fi

    body=$(jq -n --arg content "$content" --arg model "$api_model" '{
        model: "\($model)",
        messages: [{"role": "user", "content": "\($content)"}],
        temperature: 0.3
    }')

    response=$(curl -s $api_endpoint \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $api_key" \
        -d "$body")
    
    error=$(echo $response | jq -r '.error.message')
    if [ "$error" != "null" ]; then
        echo $error
    else
        echo $response | jq -r '.choices[0].message.content'
    fi
}

load_config() {
    if [ -f "$config_file" ]; then
        api_key=$(jq -r '.api_key' $config_file)
        api_model=$(jq -r '.api_model' $config_file)
        api_endpoint=$(jq -r '.api_endpoint' $config_file)
        answer_language=$(jq -r '.answer_language' $config_file)
    else
        api_key=$SHELL_ASK_API_KEY       
    fi
}

get_config() {
    key=$1
    jq -r --arg key "$key" '.[$key]' $config_file
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

    key=$1
    value=$2
    jq -r --arg key "$key" --arg value "$value" '.[$key] = $value' $config_file > tmp.$$.json && mv tmp.$$.json $config_file
}

case $1 in
    set-config)
        set_config $2 $3
        ;;
    get-config)
        get_config $2
        ;;
    *)
        load_config
        ask "$*"
        ;;
esac
