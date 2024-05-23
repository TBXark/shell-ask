#!/bin/bash

# echo "Location: $(pwd)"
# You can use same context of ask.sh

# Plugin scripts must include a gen_content function, which takes two parameters. The first parameter is the user's input and the second parameter is the pipeline input.
gen_content() {
    question=$1 # target language
    context=$2 # need translation text

    # You can only have one /dev/stdin output. If your other commands may also cause output, you need to redirect them elsewhere.
    echo "Translate the following text into $question: $context"
}
