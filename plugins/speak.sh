gen_content() {
    local question=$1 
    local context=$2  
    echo "$question: $context"
}

# Example: Customize the processing of AI return results.
after_ask() {
    local result=$1 
    echo $result
    # "say" is a tool that comes with Mac, so first check if the "say" command exists.
    if ! command -v say &> /dev/null
    then
        echo "Command 'say' could not be found"
        return
    fi
    say -v Meijia $result
}