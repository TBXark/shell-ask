# shell-ask (shell ver)

Ask LLM directly from your terminal

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
```bash
ask set-config api_key sk-xxxx
ask set-config model_name deepseek-chat
ask set-config api_endpoint https://api.deepseek.com/chat/completions
```

You can also edit ~/.config/ask.sh/config.json directly

## Usage
Ask a question:

```bash
ask "What was my last git commit message?"
```

Using command output as context:
```bash
ifconfig -a | ask My local IP
```

## Thanks
This project was inspired by the [ask](https://github.com/egoist/shell-ask) project, but since it has a dependency on nodejs, I decided to rewrite it in bash

## License
**shell-ask** is released under the MIT license. See LICENSE for details.
