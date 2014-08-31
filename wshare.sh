#!/usr/local/bin/bash

set \
	-o errexit \
	-o pipefail \
	-o nounset

shopt -s \
	nullglob \
	expand_aliases

WSHARE_HOME="$HOME/.wshare"

ERR_UNSUPPORTED_OS=1
ERR_INVALID_USAGE=2
ERR_FILE_NOT_FOUND=3

die () {
	local message="$1"
	local -i exit_code="${2:-1}"

	echo "Error: $message" >&2

	exit $exit_code
}

#alias call="eval"

result () {
	declare -p $* | sed "s/^declare /local /"
}

upload () {
	local file="$1"

	[[ -r "$file" ]] || die "File $file does not exist or is not accessible" $ERR_FILE_NOT_FOUND

	local response="$(
		cat "$file" \
		| gzip \
		| curl -s \
			"http://0paste.com/pastes.txt" \
			-F "paste[is_private]=1" \
			-F "paste[paste_gzip]=<-" \
	)"

	local regex="\(http://0paste.com/\([[:digit:]]\{1,\}\(-[[:alnum:]]\{1,\}\)\{0,\}\)\)\( (key: \([[:alnum:]]\{1,\}\))\)\{0,\}"

	local upload_id="$(echo "$response" | sed -n "s%$regex%\2%p")"
	local upload_url="$(echo "$response" | sed -n "s%$regex%\1%p").txt"
	local upload_key="$(echo "$response" | sed -n "s%$regex%\5%p")"

	result upload_id upload_url upload_key
}

shorten () {
	local url="$1"
	local -i ttl="${2:-5}"

	local response="$(curl -s -d "url=$url" -d "ttl=$((ttl * 60))" "http://shoutkey.com/new")" || die "Cannot access the URL shortener service"

	local regex=".*<h1>\<a href=\"\(http://shoutkey.com/[[:alpha:]]\{1,\}\)\">\([[:alpha:]]\{1,\}\)</a></h1>.*"

	local shorturl_url="$(echo "$response" | sed -n "s%$regex%\1%p")"
	local shorturl_key="$(echo "$response" | sed -n "s%$regex%\2%p")"
	local shorturl_ttl=$ttl

	result shorturl_url shorturl_key shorturl_ttl
}

delete () {
	local file
	local upload_id
	local upload_key
	local shorturl_url
	local response
	for file; do
		[[ "$file" == "$WSHARE_HOME"* ]] || continue

		upload_id="$(basename "$file")"

		read -r upload_key shorturl_url < "$file"

		echo "Deleting $shorturl_url at http://0paste.com/$upload_id with key $upload_key"

		response="$(curl -sL "http://0paste.com/$upload_id" -F "_method=delete" -F "paste[key]=$upload_key")"

		rm "$file"
	done
}

cleanup () {
	[[ -d "$WSHARE_HOME" ]] || return

	local ttl_dir
	local upload_path
	local upload_id
	local upload_key
	local -a files
	local ttl
	local -i any=0
	for ttl_dir in "$WSHARE_HOME"/*; do
		if [[ -n "$ttl_dir" && -d "$ttl_dir" ]]; then
			files=("$ttl_dir"/*)
			if [[ "${#files[@]}" -gt 0 ]]; then
				ttl="$(basename "$ttl_dir")"
				find "$ttl_dir"/* -maxdepth 0 -type f -mmin +$ttl -exec $0 --delete {} \;
				any=1
			fi
		fi
	done

	if [[ $any -eq 0 ]]; then
		echo "No expired uploads found"
	fi
}

upload_and_shorten () {
	local file="$1"
	local ttl="${2:-5}"

	[[ $ttl -ge 5 ]] || die "TTL cannot be less than 5 minutes"

	eval "$(upload "$file")"

	eval "$(shorten "$upload_url" "$ttl")"

	if [[ -n "$upload_key" ]]; then
		local dir="$WSHARE_HOME/$shorturl_ttl"
		mkdir -p "$dir"
		echo "$upload_key $shorturl_url" > "$dir/$upload_id"
	fi

	echo "$shorturl_url"
	echo "$shorturl_url" | pbcopy
}

show_usage () {
	cat <<-EOF
		Usage: $(basename $0) COMMAND

		Commands:
		    -h|--help                Shows usage
		    -c|--clean|--cleanup     Deletes expired uploads
		    [-s|--share] FILE [TTL]  Shares a file with TTL in minutes (default: 5)
		    -d|--delete	FILE...      Deletes files under $WSHARE_HOME (used internally)
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

do_install () {
	local bin_dir="$HOME/bin"
	mkdir -p "$bin_dir"

	local bin_file="$bin_dir/wshare"
	rm -f "$bin_file"
	echo "$BASH_EXECUTION_STRING" > "$bin_file"
	chmod +x "$bin_file"
}

install () {
	local os="$(uname)"
	case "$os" in
		Linux|Darwin)
			[[ "$(whoami)" != "root" ]] || die "Don't install with sudo or as root"

			do_install

			if [[ "$(type -t wshare)" != "file" ]]; then
				cat <<-EOF
					In order to make wshare work, you need to add the following
					to your .bashrc/.bash_profile/.profile file:

					    export PATH="$HOME/bin:$PATH"

				EOF
			fi

			echo "Successfully installed wshare!"
			;;
		*)
			die "Unsupported OS: $os"
			;;
	esac
}

if [[ -z "${BASH_SOURCE[0]:-}" ]]; then
	install
else
	main "$@"
fi
