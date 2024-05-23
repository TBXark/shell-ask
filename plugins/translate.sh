#!/bin/bash

# echo "Location: $(pwd)"
# You can use same context of ask.sh

# Plugin scripts must include a gen_content function, which takes two parameters. The first parameter is the user's input and the second parameter is the pipeline input.
gen_content() {
    question=$1 # user's input： target language
    context=$2  # pipeline input：need translation text

    # You can only have one /dev/stdin output. If your other commands may also cause output, you need to redirect them elsewhere.
    echo "Translate the following text into $question: $context"
}


# You can add an "after_ask" function here to customize the processing of AI's return results. You can also choose not to implement it, in which case the default behavior is to output the result.
after_ask() {
    local result=$1 # AI's return results
    echo $result
}