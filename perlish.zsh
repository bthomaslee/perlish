#!/bin/zsh

# This script will translate perlish expressions passed as arguments into elements in an array of perl-compatible regular expressions.
# Currently, alas, there's only support for ASCII characters 0 to 127; also, I abandoned the struggle to figure out how to support escaping the escape character.

### FUNCTIONS AND VARIABLES ###

# Set initial variables.
use_macos_popup_dialogue="n"
match_whole_words_only="y"
d=20 # Set the number of children for each node in the d-ary heap. Must be an even number (i.e., divisible into two equal sets of lb's and la's).
if ! [[ "$(($d%2))" -eq 0 ]]; then echo "\n❌ The number of children for each node must be divisible into two equal sets.\n"; exit; fi
h=5 # Set the maximum height of the d-ary heap (as a cap on the longest, possible processing time).
g=0 # Infer the maximum number of nodes in the d-ary heap from the maximum height.
until [[ "$n" -eq "$h" ]]; do
    g="$(($(($g*$d))+$d))"
    let n++
done
unset n
if ! [[ -z "$1" ]]
    then
    query="$1"
fi

# Set initial arrays.
declare -A pchars
pcres=()
exps=()

# Set functions.
set_perlish_metacharacters(){
    if [[ "$match_whole_words_only" = "y" ]]
        then
        pchars[a]='(?<=\A|\W)'
        pchars[z]='(?=\Z|\W)'
        else
        pchars[a]=''
        pchars[z]=''
    fi
    pchars[d]="\`" # Delimits strings in perl substitutions.
    pchars[esc]="\\" # When prepended to any other metacharacter, beginning with pchars[1], it interprets that metacharacter literally.
    pchars[1]="[" # Opens a required-context string.
    pchars[2]="]" # When paired with pchars[1], closes a required-context string.
    pchars[3]="{" # When appended to pchars[2], opens a word-range for distance from context string.
    pchars[4]="}" # When paired with pchars[3], closes a word-range for distance from context string.
    pchars[5]="(" # Open an optional string. Note that internal spaces will be interpreted literally.
    pchars[6]=")" # Close an optional string. Note that internal spaces will be interpreted literally.
    pchars[7]="~" # When prepended to pchars[1], makes pchars[1] open an unacceptable-context string.
    pchars[8]="*" # One or more of any of the following word characters: a-z, A-Z, 0-9, _ ("\w+" in perl).
    pchars[9]="/" # Boolean "or" operator ("|" in perl).
    pchars[10]="/" # When used as first and last character of a match or context string, causes string to be interpreted as a pcre.
    for key in "${(@k)pchars}"; do
        let k++
    done
    num_nonnumbered_pchars=4
    num_pchars="$(($k-$num_nonnumbered_pchars))"; pchars_num=1
    any_pchar="[$(until [[ $pchars_num -gt $num_pchars ]]; do if [[ "${pchars[$pchars_num]}" = ']' || "${pchars[$pchars_num]}" = '[' || "${pchars[$pchars_num]}" = '^' || "${pchars[$pchars_num]}" = '\' || "${pchars[$pchars_num]}" = '/' ]]; then printf '\%s' "${pchars[$pchars_num]}"; else printf '%s' "${pchars[$pchars_num]}"; fi; let pchars_num++; done)]" # Create a character class string that contains each perlish metacharacter, escaping all possible metacharacters inside character classes.
}
syntax_error(){
    mark_position(){
        until [[ "$k" -eq "$j" ]]; do
            printf '%s' " "
            let k++
        done
        print "^"
    }
    unset k
    j="${j:=$p}"
    echo "\n❌ Syntax error: $1\n$s"
    mark_position
    exit 2
}
parse_query_into_expressions(){
    c="$(print -r -- "$query" | wc -c | bc)"
    # Confirm the pairing of all unescaped, double quotation marks.
    p=0
    q=0
    if [[ "${query:$p:1}" = '"' && ( ! "${query:$(($p-1)):1}" = "${pchars[esc]}" || "$p" -eq 0 ) ]]
        then
        j="$p"; let q++
        until [[ "$p" -ge "$c" ]]; do
            let p++
            if [[ "${query:$p:1}" = '"' && ! "${query:$(($p-1)):1}" = "${pchars[esc]}" ]]
                then let q++
            fi
        done
        if ! [[ "$(($q%2))" -eq 0 ]]
            then s="$query"; syntax_error "unmatched \""
        fi
    fi
    # Add expression(s) to array.
    p=0
    while true; do
        unset e
        until [[ ( "${query:$p:1}" = '"' && ! "${query:$(($p-1)):1}" = "${pchars[esc]}" ) || "$p" -ge "$c" ]]; do
            e+="${query:$p:1}"
            let p++
        done
        if ! [[ $(print "$e" | grep -c -P "^\s+$") -gt 0 || -z "$e" ]]
            then exps+="$e"
        fi
        let p++
        if [[ "$p" -ge "$c" ]]; then break; fi
    done
}
parse_perlish_expression(){

    local n="$1" # Set the node number for the current statement.
    local v=1 # Set the minor variable for calculating child node numbers.

    s="$2" # Store the current statement in a variable.
    c="$(print -r -- "$s" | wc -c | bc)" # Get the length of the current statement.

    p=0 # Reset current character position to the first character.
    t="lb" # Set initial lookaround type.

    if [[ "$n" -gt "$x" ]] # If the current node number is the greatest so far.
        then
        x="$n" # Store the node number in a variable.
        if [[ "$x" -gt "$g" ]] # Confirm permissibility of the node number.
            then
            j=0
            syntax_error "too many layers of lookarounds."
        fi
    fi

    until [[ "$p" -ge "$c" ]]; do

        if ! [[ ( "${s:$p:1}" = "${pchars[1]}" && ! "${s:$(($p-1)):1}" = "${pchars[esc]}" ) || ( "${s:$p:1}" = "${pchars[7]}" && "${s:$(($p+1)):1}" = "${pchars[1]}" ) || $(print "${s:$p:1}" | grep -c -P "\s") -eq 1 || "${s:$p:1}" = "" ]] # If the current character is anything other than (1) an unescaped pchars[1], (2) pchars[7] followed, immediately, by pchars[1], (3) a space, or (4) an empty string.
        #if [[ $(print "${s:$p:1}" | grep -c -P "\w") -eq 1 || ( $(print "${s:$p:1}" | grep -c -P "\W") -eq 1 && "${s:$(($p-1)):1}" = "${pchars[esc]}" ) || "${s:$p:1}" = "${pchars[10]}" ]] # If the current character is a word character or pchars[10].

            then
            if [[ "$v" -gt $(($d/2)) ]]
                then
                j="$p"
                if [[ "$m_pcre" = "y" ]]
                    then syntax_error "found content after ${pchars[10]}-enclosed pcre"
                    else syntax_error "found content after lookahead(s)"
                fi
            fi
            unset m; unset m_pcre
            if [[ "${s:$p:1}" = "${pchars[10]}" && ! "${s:$(($p-1)):1}" = "${pchars[esc]}" ]]
                
                then
                m_pcre="y"
                let p++
                until [[ ( "${s:$p:1}" = "${pchars[10]}" && ! "${s:$(($p-1)):1}" = "${pchars[esc]}" ) || "$p" -ge "$c" ]]; do
                    m="$m${s:$p:1}"
                    let p++
                done
                if [[ "$p" -ge "$c" && ! ( "${s:$p:1}" = "${pchars[10]}" && ! "${s:$(($p-1)):1}" = "${pchars[esc]}" ) ]]
                    then j=0; syntax_error "unmatched ${pchars[10]}"
                fi
                let p++

                else
                if [[ $(print "${s:$p:1}" | grep -c -P "\W") -eq 1 && "${s:$(($p-1)):1}" = "${pchars[esc]}" ]]
                    then m="$m${s:$(($p-1)):1}"
                fi
                until [[ ( "${s:$p:1}" = "${pchars[1]}" && ! "${s:$(($p-1)):1}" = "${pchars[esc]}" ) || "$p" -ge "$c" ]]; do # Until the current character is either an unescaped open-lookaround character or the current position is greater than the statement length.
                    if [[ "${s:$p:1}" = "${pchars[7]}" && ! "${s:$(($p-1)):1}" = "${pchars[esc]}" && "${s:$(($p+1)):1}" = "${pchars[1]}" ]] # If the current character is an unescaped lookaround-negation character and the next character is an unescaped open-lookaround character.
                        then let p++; continue # Don't add that unescaped lookaround-negation character to the match string. Skip it. Let the loop terminate at the unescaped open-lookaround character.
                    elif [[ "${s:$p:1}" = "${pchars[esc]}" && $(print "${s:$(($p+1)):1}" | grep -c -P "\w") -eq 1 && ! $(print "${s:$p:1}" | grep -c -P "$any_pchar") -gt 0 ]] # If the current character is an escape character followed by any word character (one that isn't a perlish metacharacter).
                        then let p++; continue # Un-escape that word character by refraining from adding the escape character to the match string. It's liable to be interpreted by perl as a perl metacharacter.
                    elif [[ $(print "${s:$p:1}" | grep -c -P "\W") -eq 1 && ! $(print "${s:$p:1}" | grep -c -P "$any_pchar") -gt 0 && ! "${s:$p:1}" = " " && ! "${s:$(($p-1)):1}" = "${pchars[esc]}" ]] # If the current character is an unescaped, non-word character (unless it's a space or a perlish metacharacter).
                        then m="$m$(printf '\%s' "${pchars[esc]}")" # Insert an escape before adding that non-word character to the match string. It's liable to be interpreted by perl as a perl metacharacter.
                    fi
                    m="$m${s:$p:1}" # Add the current character to the match string.
                    let p++ # Proceed to the next character.
                done
            fi
            m=$(print -r -- "$m" | rev); m=$(print -r -- "$m" | perl -p -e "s${pchars[d]}^\s+(.*)${pchars[d]}\1${pchars[d]}"); m=$(print -r -- "$m" | rev) # Remove space(s) from end of string.
            if ! [[ "$m_pcre" = "y" ]]
                then # Confirm the proper pairing of all unescaped instances of pchars[5] and pchars[6]. And confirm that at least one character isn't enclosed between unescaped instances of pchars[5] and pchars[6].
                l="$(print -r -- "$m" | wc -c | bc)"
                p2=0; u=0
                unset c1; unset c2
                until [[ "$p2" -eq "$(($l-1))" ]]; do
                    if [[ "${m:$p2:1}" = "${pchars[5]}" && ! "${m:$(($p2-1)):1}" = "${pchars[esc]}" ]] # If the current character is an unescaped instance of pchars[5].
                        then
                        echo "("
                        let c1++; o="$p2"
                        until [[ "$c1" -eq "$c2" || "$p2" -ge "$l" ]]; do
                            let p2++
                            if [[ "${m:$p2:1}" = "${pchars[5]}" && ! "${m:$(($p2-1)):1}" = "${pchars[esc]}" ]]
                                then let c1++
                            elif [[ "${m:$p2:1}" = "${pchars[6]}" && ! "${m:$(($p2-1)):1}" = "${pchars[esc]}" ]]
                                then let c2++
                            fi
                        done
                        if [[ "$p2" -ge "$l" && ! "$c1" -eq "$c2" ]]
                            then s="$m"; j="$o"; syntax_error "unmatched ${pchars[5]}"
                        fi
                        let p2++
                    elif [[ "${m:$p2:1}" = "${pchars[6]}" && ! "${m:$(($p2-1)):1}" = "${pchars[esc]}" ]] # If there's an unescaped instance of pchars[6] in the match string that isn't preceded by an unescaped instance of pchars[5].
                        then s="$m"; j="$p2"; syntax_error "unmatched ${pchars[6]}"
                        else let u++; let p2++
                    fi
                done
                if [[ "$u" -eq 0 ]]
                    then j="$(($l-2))"; syntax_error "some character(s) must be a required match"
                fi
                # Append question mark quantifier to all unescaped instances of pchars[6].
                if ! [[ -z ${pchars[6]} ]]; then m=$(printf "$m" | perl -p -e "s${pchars[d]}(?<!$(printf '\%s' "${pchars[esc]}"))$(printf '\%s' "${pchars[6]}")${pchars[d]}$(printf '\%s' "${pchars[6]}")?${pchars[d]}g"); fi
                # Replace all unescaped instances of pchars[7] with \w+.
                if ! [[ -z ${pchars[8]} ]]; then m=$(printf "$m" | perl -p -e "s${pchars[d]}(?<!$(printf '\%s' "${pchars[esc]}"))$(printf '\%s' "${pchars[8]}")${pchars[d]}\\\w+${pchars[d]}g"); fi
                # Transform all interior, unescaped instances of pchars[9] into the boolean "or" operator ("|").
                if ! [[ -z ${pchars[9]} ]]; then m=$(printf "$m" | perl -p -e "s${pchars[d]}(?<!\A)(?<!$(printf '\%s' "${pchars[esc]}"))$(printf '\%s' "${pchars[9]}")(?!\Z)${pchars[d]}|${pchars[d]}g"); fi
                # To avoid separating the entire string into two sides of an "or" expression, arbitrarily, enclose in parentheses all words surrounding unescaped instances of the "|" character (or enclose in parentheses a string of words separated by "|" characters), where a "word" is delimited by space-separation or by the beginning/end of the string.
                # Perl is telling me that the following substitution involves a variable-length lookbehind. I don't see it. And it doesn't seem to be causing an error. So I'm ignoring the error message.
                if ! [[ -z ${pchars[9]} ]]; then m=$(printf "$m" | perl -p -e "s${pchars[d]}((?<=\s|\A)\w+\|(\w+|\|)+(?=\s|\Z))${pchars[d]}\(\1\)${pchars[d]}g"); fi
            fi
            # Assign the match string to a position in the heap.
            e[${n}match]="$m"
            # Flip post-match switches.
            v=$(($(($d/2))+1))
            t="la"

        elif [[ "${s:$p:1}" = "${pchars[1]}" && ! "${s:$(($p-1)):1}" = "${pchars[esc]}" ]]

            # If current character opens a lookaround.
            then
            o="$p"; j="$p"; unset l; unset c1; unset c2; let c1++
            if [[ ( "$v" -gt $(($d/2)) && ! "$t" = "la" ) || "$v" -gt "$d" ]]
                then
                if [[ "$t" = "lb" ]]
                    then syntax_error "too many lookbehinds."
                    else syntax_error "too many lookaheads."
                fi
            fi
            if [[ "${s:$(($p-1)):1}" = "${pchars[7]}" ]] 
                # If the lookaround is negative.
                then e[$(($(($d*$n))+$v))negated]="y"
            fi
            # Capture characters until open- and close-character counts match.
            until [[ "$c1" -eq "$c2" || "$p" -ge "$c" ]]; do
                let p++; let l++
                if [[ "${s:$p:1}" = "${pchars[1]}" && ! "${s:$(($p-1)):1}" = "${pchars[esc]}" ]]
                    then let c1++; j="$p"
                elif [[ "${s:$p:1}" = "${pchars[2]}" && ! "${s:$(($p-1)):1}" = "${pchars[esc]}" ]]
                    then let c2++
                fi
            done
            if [[ "$p" -ge "$c" && ! "$c1" -eq "$c2" ]]
                then syntax_error "unmatched ${pchars[1]}"
            fi
            let l++
            #if ! [[ $(print "${s:$o:$l}" | grep -c -P "\w") -gt 0 ]]
                #then let j++; syntax_error "invalid content in ${pchars[1]} ${pchars[2]}"
            #fi
            e[$(($(($d*$n))+$v))match]="${${${${s:$o:$l}/#\[}%\]}}"
            if [[ "$v" -le $(($d/2)) ]]
                then e[$(($(($d*$n))+$v))etype]="lb"
                else e[$(($(($d*$n))+$v))etype]="la"
            fi
            let p++
            until ! [[ "${s:$p:1}" = " " ]]; do
                let p++
            done

            if [[ "${s:$p:1}" = "${pchars[3]}" ]]
                # If the current character opens a word range.
                then
                unset r # Unset lookaround word range.
                j="$p"
                let p++
                # Go until current character is a close-character.
                until [[ "${s:$p:1}" = "${pchars[4]}" || "$p" -ge "$c" ]]; do
                    if ! [[ "${s:$p:1}" = " " ]]
                        then
                        r="$r${s:$p:1}"
                    fi
                    let p++
                done
                if [[ "$p" -ge "$c" && ! "${s:$p:1}" = "${pchars[4]}" ]]
                    then
                    syntax_error "unmatched ${pchars[3]}"
                fi
                # Analyze the word range.
                if [[ $(print "$r" | grep -c -P "^\d+$") -eq 1 ]]
                    then r="$r"
                elif [[ $(print "$r" | grep -c -P "^=\d+$") -eq 1 ]]
                    then r="${r//=/}"
                elif [[ $(print "$r" | grep -c -P "^\d+-\d+$") -eq 1 ]]
                    then
                    rd1="${r%-*}"; rd2="${r#*-}"
                    if [[ "$rd1" -gt "$rd2" ]]
                        then rd_cache="$rd1"; rd1="$rd2"; rd2="$rd_cache"
                    elif [[ "$rd1" -eq "$rd2" ]]
                        then r="$rd1"
                        else r="${r//-/,}"
                    fi
                    if [[ "$rd1" -eq 0 ]]; then e[$(($(($d*$n))+$v))rtype]="{0,"; fi
                elif [[ $(print "$r" | grep -c -P "^\d+\+$") -eq 1 ]]
                    then r="${r//+/,}"; if [[ "$r" = "0," ]]; then e[$(($(($d*$n))+$v))rtype]="{0,"; fi
                elif [[ $(print "$r" | grep -c -P "^\d+-$") -eq 1 ]]
                    then rd2="${r%-}"; if [[ "$rd2" -eq 0 ]]; then r="$rd2"; else r="0,$rd2"; e[$(($(($d*$n))+$v))rtype]="{0,"; fi
                elif [[ $(print "$r" | grep -c -P "^\<\d+$") -eq 1 ]]
                    then rd1="${r//</}"; r="0,$(($rd1-1))"; e[$(($(($d*$n))+$v))rtype]="{0,"
                elif [[ $(print "$r" | grep -c -P "^\>\d+$") -eq 1 ]]
                    then rd1="${r//>/}"; r="$(($rd1+1)),"
                    else syntax_error "invalid content in ${pchars[3]} ${pchars[4]}"
                fi
                e[$(($(($d*$n))+$v))range]="{$r}"
                let p++
                else
                e[$(($(($d*$n))+$v))rtype]="none"
            fi
            let v++  

            # If the current character is anything else.
            else
            let p++

        fi

    done

    if ! [[ "$t" = "la" ]]
        then
        syntax_error "missing match word/phrase"
    fi

    # Create a function for the current node.
    # Child node number: $(($(($d*$x))+$v)).
    # Parent node number: $(($(($x-1))/$d)).
    f${n}(){
        # Write main statement for the current node.
        if ! [[ "${e[${x}etype]}" = "la" ]]
            then e[$x]+="($(print -r -- ${pchars[a]})${e[${x}match]}$(print -r -- ${pchars[z]}))"
        fi
        if [[ "${e[${x}etype]}" = "lb" ]]
            then e[$x]+="(?="
        fi
        if [[ "${e[${x}etype]}" = "la" && ! -z "${e[${x}rtype]}" ]]
            then e[$x]+="\s*($(print -r -- ${pchars[a]})${e[${x}match]}$(print -r -- ${pchars[z]}))|"
        elif [[ "${e[${x}etype]}" = "lb" && ! -z "${e[${x}rtype]}" ]]
            then e[$x]+="\s*($(print -r -- ${pchars[a]})${e[$(($(($x-1))/$d))match]}$(print -r -- ${pchars[z]}))|"
        fi
        if [[ "${e[${x}etype]}" = "la" || "${e[${x}etype]}" = "lb" ]]
            then e[$x]+=$(printf '%s' "(\s*\S+\W+)")
            if [[ "${e[${x}rtype]}" = "{0," ]]
                then e[$x]+="${e[${x}range]}?"
                else e[$x]+="${e[${x}range]:-"{0,}"}?"
            fi
        fi
        if [[ "${e[${x}etype]}" = "la" ]]
            then e[$x]+="($(print -r -- ${pchars[a]})${e[${x}match]}$(print -r -- ${pchars[z]}))"
        elif [[ "${e[${x}etype]}" = "lb" ]]
            then e[$x]+="($(print -r -- ${pchars[a]})${e[$(($(($x-1))/$d))match]}$(print -r -- ${pchars[z]})))"
        fi
        local v=1
        until [[ "$v" -gt "$d" ]]; do
            # Incorporate lookbehind child node statements.
            if [[ "$v" -le $(($d/2)) && ! -z "${e[$(($(($d*$x))+$v))]}" ]]
                then
                if [[ "${e[$(($(($d*$x))+$v))negated]}" = "y" ]]
                    then e[$x]+="(?!"
                fi
                let i++
                b1="(?'s$i'"
                b2="(?=[\s\S])|(?<=(?=[\s\S]^|(?&s$i))[\s\S]))"
                e[$x]+="($b1(${e[$(($(($d*$x))+$v))]})$b2)"
                if [[ "${e[$(($(($d*$x))+$v))negated]}" = "y" ]]
                    then e[$x]+=")"
                fi
            fi
            # Incorporate lookahead child node statements.
            if [[ "$v" -gt $(($d/2)) && ! -z "${e[$(($(($d*$x))+$v))]}" ]]
                then
                if [[ "${e[$(($(($d*$x))+$v))negated]}" = "y" ]]
                    then e[$x]+="(?!"
                fi
                e[$x]+="(?=${e[$(($(($d*$x))+$v))]})"
                if [[ "${e[$(($(($d*$x))+$v))negated]}" = "y" ]]
                    then e[$x]+=")"
                fi
            fi
            let v++
        done
    }

    # Parse all lookarounds (each child of the current node).
    local v=1
    until [[ "$v" -gt "$d" ]]; do
        if ! [[ -z "${e[$(($(($d*$n))+$v))match]}" ]]
            then parse_perlish_expression "$(($(($d*$n))+$v))" "${e[$(($(($d*$n))+$v))match]}"
        fi
        let v++
    done

}

### MAIN SCRIPT ###

# Set query.
if [[ $use_macos_popup_dialogue = "y" ]]
    then

    if [[ -z "$1" && -z "$query" ]]
        then
        prompt="Please enter a set of one or more perlish expressions.\nEnclose separate expressions, if any, in double quotes.\n"
        default_answer=""
        input="$(osascript -e 'display dialog "'${prompt}'" with title "Perlish Interpreter" default answer "'${default_answer}'" buttons ("Cancel", "Enter")')" &>/dev/null
        button_returned="$(printf "$input" | cut -d ":" -f2 | cut -d "," -f1 )"
        text_returned="$(printf "$input" | cut -d ":" -f3 )"
        if [[ "$text_returned" = "" || "$button_returned" = "Cancel" ]]
            then exit
        elif [[ "$button_returned" = "Enter" ]]
            then query="$text_returned"
        fi
        else query="${query:=$1}"
    fi

    else

    if [[ -z "$1" && -z "$query" ]]
        then
        prompt="Please enter a set of one or more perlish expressions.\nEnclose separate expressions, if any, in double quotes.\n"
        printf "$prompt\n"
        read query
        if [[ "$query" = "" ]]
            then exit
        fi
        else query="${query:=$1}"
    fi
fi


# Parse query into expressions.
set_perlish_metacharacters
parse_query_into_expressions

# Translate perlish expressions.
exp_num=1; num_exps="${#exps[@]}"
until [[ "$exp_num" -gt "$num_exps" ]]; do
    exp="${exps[$exp_num]}"
    # Reset expression-wide variables.
    unset e; declare -A e; x=0
    # Confirm permissibility of all characters.
    c="$(print -r -- "$exp" | wc -c | bc)" # Get the length of the current expression.
    p=0
    until [[ "$p" -ge "$c" ]]; do
        if ! [[ $(print -r -- "${exp:$p:1}" | grep -c -P "^[[:ascii:]]+$") -eq 1 || "${exp:$p:1}" = "" ]]
            then s="$exp"; syntax_error "invalid character."
        fi
        let p++
    done
    # Parse expression into perlish, as needed.
        parse_perlish_expression "0" "${exps[$exp_num]}"
        ## Reverse call each node function.
        until [[ "$x" -lt 0 ]]; do
            if ! [[ -z "${e[${x}match]}" ]]
                then
                f$x
            fi
            let x--
        done
    # Add the final, translated expression to the set of pcres.
    pcres+="${e[0]}"
    let exp_num++
done

printf "${e[0]}" | pbcopy # Copy the last pcre to the clipboard.

# Print output.
loop_num=1; num_loops="${#pcres[@]}"
until [[ "$loop_num" -gt "$num_loops" ]]; do
    printf "\n\nExpression ${loop_num}\n${pcres[$loop_num]}"
    let loop_num++
done
print "\n\n"
exit