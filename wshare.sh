#!/usr/local/bin/bash

set \
	-o errexit \
	-o pipefail \
	-o nounset

shopt \
	-s nullglob

WSHARE_HOME="$HOME/.wshare"

ERR_INVALID_USAGE=1
ERR_FILE_NOT_FOUND=2

die () {
	local message="$1"
	local -i exit_code="${2:-1}"

	echo "$message" >&2
	exit $exit_code
}

parse_response () {
	local variable="$1"
	local result="$2"

	echo "$result" | sed "s/declare \(-[aA]\) [^ =]\{1,\}=\(.\{1,\}\)/local \1 $variable=\2/"
}

upload () {
	local file="$1"

	[[ -r "$file" ]] || die "File '$file' does not exist or is not accessible" $ERR_FILE_NOT_FOUND

	local response="$(
		cat "$file" \
		| gzip \
		| curl -s \
			"http://0paste.com/pastes.txt" \
			-F "paste[is_private]=1" \
			-F "paste[paste_gzip]=<-" \
	)"

	local regex="\(http://0paste.com/\([[:digit:]]\{1,\}\(-[[:alnum:]]\{1,\}\)\{0,\}\)\)\( (key: \([[:alnum:]]\{1,\}\))\)\{0,\}"

	local -A result=(
		[id]="$(echo "$response" | sed -n "s%$regex%\2%p")"
		[url]="$(echo "$response" | sed -n "s%$regex%\1%p").txt"
		[key]="$(echo "$response" | sed -n "s%$regex%\5%p")"
	)
	declare -p result
}

shorten () {
	local url="$1"
	local -i ttl="${2:-5}"

	local response="$(curl -s -d "url=$url" -d "ttl=$((ttl * 60))" "http://shoutkey.com/new")" || die "Cannot access the URL shortener service"

	local regex=".*<h1>\<a href=\"\(http://shoutkey.com/[[:alpha:]]\{1,\}\)\">\([[:alpha:]]\{1,\}\)</a></h1>.*"
	local -A result=(
		[url]="$(echo "$response" | sed -n "s%$regex%\1%p")"
		[key]="$(echo "$response" | sed -n "s%$regex%\2%p")"
		[ttl]=$ttl
	)
	declare -p result
}

delete () {
	local file="$1"

	local upload_id="$(basename "$file")"
	local upload_key="$(<"$file")"

	local response="$(curl -sL "http://0paste.com/$upload_id" -F "_method=delete" -F "paste[key]=$upload_key")"

	rm "$file"
}

cleanup () {
	[[ -d "$WSHARE_HOME" ]] || return

	local ttl_dir
	local upload_path
	local upload_id
	local upload_key
	local -a files
	local ttl

	for ttl_dir in "$WSHARE_HOME"/*; do
		if [[ -n "$ttl_dir" && -d "$ttl_dir" ]]; then
			files=("$ttl_dir"/*)
			if [[ "${#files[@]}" -gt 0 ]]; then
				ttl="$(basename "$ttl_dir")"
				find "$ttl_dir"/* -maxdepth 0 -type f -mmin +$ttl -exec $0 --delete {} \;
			fi
		fi
	done
}

upload_and_shorten () {
	local file="$1"
	local ttl="${2:-}"

	local response
	response="$(upload "$file")"
	if [[ -n "$response" ]]; then
		eval "$(parse_response uploaded_file "$response")"
		response="$(shorten "${uploaded_file[url]}" "$ttl")"
		if [[ -n "$response" ]]; then
			eval "$(parse_response short_url "$response")"

			if [[ -n "${uploaded_file[key]}" ]]; then
				local dir="$WSHARE_HOME/${short_url[ttl]}"
				mkdir -p "$dir"
				echo "${uploaded_file[key]}" > "$dir/${uploaded_file[id]}"
			fi

			echo "${short_url[url]}"
			echo "${short_url[url]}" | pbcopy
		fi
	fi
}

show_usage () {
	cat <<-EOF
		Usage: $(basename $0) COMMAND

		Commands:
		    -h|--help               Shows usage
		    -c|--clean|--cleanup    Deletes expired uploads
		    [-s|--share] FILE [TTL] Shares a file with TTL in minutes (default = 5)
		    -d|--delete	FILE        Deletes a file (must be under $WSHARE_HOME)
	EOF
}

usage () {
	show_usage
	exit $ERR_INVALID_USAGE
}

main () {
	[[ $# -gt 0 ]] || usage

	local command="${1:-}"
	case "$command" in
		"-h"|"--help")
			shift
			show_usage
			;;
		"-c"|"--clean"|"--cleanup")
			shift
			cleanup
			;;
		"-d"|"--delete")
			shift
			delete "$@"
			;;
		*)
			upload_and_shorten "$@"
			;;
	esac
}

main "$@"
