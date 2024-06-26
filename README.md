# **shell-ask** (shell ver)

Ask LLM directly from your terminal, and let the AI answer your terminal's output without leaving the terminal. Or generate shell commands you're not familiar with. A bash script will do the trick. You can even manually write plugins to let AI help you do more things.

![](./preview.png)

## Install

This script is written in bash, Simply download the script and add execution permissions, this script relies on `curl` and `jq`, make sure they are installed on your system!

```bash
curl https://raw.githubusercontent.com/TBXark/shell-ask/master/ask.sh > /usr/local/bin/ask
chmod +x /usr/local/bin/ask
```


## Supported LLMs
- All OpenAI Compatible LLMs API

## Configuration

### Config File
```bash
ask set-config answer_language chinese
ask set-config api_key sk-xxxx
ask set-config api_model deepseek-chat
ask set-config api_endpoint https://api.deepseek.com/chat/completions
```

You can also edit `~/.config/ask.sh/config.json` directly

### Environment Variables
If you don't want to use a configuration file, you can set the configuration via environment variables.
```bash
export SHELL_ASK_API_KEY=xxx
export SHELL_ASK_API_MODEL=xxx
export SHELL_ASK_API_ENDPOINT=xxx
export SHELL_ASK_ANSWER_LANGUAGE=xxx
```

Or you can change configuration file path by setting `SHELL_ASK_CONFIG_FILE` environment variable

```bash
export SHELL_ASK_CONFIG_FILE=/path/to/config.json
```


## Usage
Generate Shell commands based on questions:
```bash
ask "What was my last git commit message?"
# Output:
# git log -1 --pretty=%B
```

Using command output as context:
```bash
ifconfig -a | ask "My local IP"
# Output:
# Your local IP address is `192.168.31.200`
```

## Plugins

### Install Plugin
```bash
ask install-plugin https://raw.githubusercontent.com/TBXark/shell-ask/master/plugins/translate.sh
```
Or you can install the plugin manually in the `~/.config/ask.sh/plugins` directory

### Use Plugin
Usage: `ask -p PLUGIN_NAME [ARGS]` or `pipe | ask -p PLUGIN_NAME [ARGS]`
```bash
echo "你好，世界" | ask -p translate english
# Output:
# Hello, World
```

### Create Plugin
The plugin is a script file that implements the `gen_content` (required) and `after_ask` (optional) functions. The `gen_content` function is used to generate the context of the question, and the `after_ask` function is used to process AI's response.

In `after_ask`, you can do many things, such as writing the result to a file or directly executing the command returned by AI.

For details, please refer to [example](./plugins)


## Thanks
This project was inspired by the [egoist/shell-ask](https://github.com/egoist/shell-ask) project, but since it has a dependency on nodejs, I decided to rewrite it in bash

## License
**shell-ask** is released under the MIT license. See LICENSE for details.
