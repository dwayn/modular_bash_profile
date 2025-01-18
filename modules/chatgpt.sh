

# cats all the files in a directory and copies them to the paste buffer with some markdown 
# allowing you to paste them into chatgpt for doing things like code reviews and refactors
function dir_pattern_to_md_clipboard() {
    # Usage: dir_pattern_to_md_clipboard /path/to/dir "*.md" node_modules .git build
    #
    # This function descends into /path/to/dir, excludes directories like node_modules, .git, and build,
    # finds files named "*.md" (for example), and copies their content in a Markdown code block to your clipboard.

    local target_directory="${1?Must provide a directory}"
    shift

    local search_pattern="$1"
    shift

    # All remaining arguments are directories to exclude
    local directories_to_exclude=("$@")

    pushd "$target_directory" >/dev/null || return 1

    # Start building the find command as an array
    local find_command=( find . )

    # Build a prune expression if there are directories to exclude
    if [ ${#directories_to_exclude[@]} -gt 0 ]; then
        find_command+=( "(" )
        local is_first_exclude=1

        for exclude_dir in "${directories_to_exclude[@]}"; do
            if [ $is_first_exclude -eq 1 ]; then
                find_command+=( -name "$exclude_dir" )
                is_first_exclude=0
            else
                find_command+=( -o -name "$exclude_dir" )
            fi
        done

        # Close parentheses, prune, then OR with the next expression
        find_command+=( ")" -prune -o )
    fi

    # Add the actual search pattern for files (you could add `-type f` if needed)
    find_command+=( -name "$search_pattern" -print )

    # Feed the results into a while-read loop
    while IFS= read -r file; do
        echo "${file}:"
        echo "------"
        echo '```'
        cat "$file"
        echo '```'
        echo "------"
    done < <("${find_command[@]}") | pbcopy

    popd >/dev/null || return 2
}


