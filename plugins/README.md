# Plugins



#### 1. [Translate](translate.sh) - Translate text to another language

This example explains how to use `gen_content` to customize the prompt.

```bash
echo "你好，世界" | ask -p translate english
```



#### 2. [Commit](commit.sh) - Generate git commit message

This example explains how you can share the context of the current command in the plugin, which allows you to get more input, such as reading and writing files or executing other commands.

```bash
ask -p commit # No need to pass any arguments or pipe
```

As a plugin for [lazygit](https://github.com/jesseduffield/lazygit/blob/master/docs/Custom_Command_Keybindings.md)
```yaml
customCommands:
  - key: "<c-a>"
    command: "ask -p commit | tr -d '\n' | tee >(pbcopy)"
    context: "files"
    loadingText: "Generating commit message..."
    description: "Generated commit message by AI"
    stream: false
    subprocess: false
    showOutput: true
    outputTitle: "Commit Message (Copied)"
    background: true
```


#### 3. [Speak](speak.sh) - Speak the text with TTS

This example mainly explains how to use `after_ask` to handle the AI's response. In this example, we used the `say` command to read out the AI's response.

```bash
ask -p speak "中国最高的楼是什么"
```
