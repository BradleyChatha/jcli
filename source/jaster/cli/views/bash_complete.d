module jaster.cli.views.bash_complete;

const BASH_COMPLETION_TEMPLATE = `
# [1][3][4] is non-spaced name of exe.
# [2] is full path to exe.
# I hate this btw.

__completion_for_%s() {
    words_as_string=$( IFS=$' '; echo "${COMP_WORDS[*]}" ) ;
    output=$( %s __jcli:complete $COMP_CWORD $words_as_string ) ;
    IFS=$' ' ;
    read -r -a COMPREPLY <<< "$output" ;
}

complete -F __completion_for_%s %s
`;