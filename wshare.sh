#!/bin/bash

set \
	-o errexit \
	-o pipefail \
	-o nounset

shopt -s \
	nullglob \
	expand_aliases

readonly WSHARE_VERSION=""

readonly WSHARE_HOME="$HOME/.wshare"
readonly WSHARE_BIN="$HOME/bin/wshare"

readonly ERR_UNSUPPORTED_OS=1
readonly ERR_INVALID_USAGE=2
readonly ERR_FILE_NOT_FOUND=3

die () {
	local message="$1"
	local -i exit_code="${2:-1}"

	echo "Error $exit_code: $message" >&2

	exit $exit_code
}

alias call="eval"

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

		{
			read -r upload_key
			while read -r shorturl_url; do
				echo "Deleting $shorturl_url at http://0paste.com/$upload_id with key $upload_key"
			done
		} < "$file"

		response="$(curl -sL "http://0paste.com/$upload_id" -F "_method=delete" -F "paste[key]=$upload_key")"

		rm "$file"
		rmdir "$(dirname "$file")" || true
	done
}

cleanup () {
	[[ -d "$WSHARE_HOME" ]] || return

	local ttl_dir
	local upload_path
	local upload_id
	local upload_key
	local ttl
	local -i any=0
	for ttl_dir in "$WSHARE_HOME"/*; do
		if [[ -n "$ttl_dir" && -d "$ttl_dir" ]]; then
			if [[ "$(ls -A "$ttl_dir")" ]]; then
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

share () {
	local uri="$1"
	local ttl="${2:-5}"

	[[ $ttl -ge 5 ]] || die "TTL cannot be less than 5 minutes"

	if [[ "$uri" =~ ^http?:// ]]; then
		local upload_url="$uri"
	else
		call "$(upload "$uri")"
	fi

	call "$(shorten "$upload_url" "$ttl")"

	if [[ -n "${upload_id:-}" ]]; then
		local db_dir="$WSHARE_HOME/$shorturl_ttl"
		mkdir -p "$db_dir"
		local db_file="$db_dir/$upload_id"
		if [[ -n "$upload_key" ]]; then
			cat <<-EOF > "$db_file"
				$upload_key
				$shorturl_url
			EOF
		elif [[ -w "$db_file" ]]; then
			echo "$shorturl_url" >> "$db_file"
		fi
	fi

	echo -n "$shorturl_url" | pbcopy

	echo "$shorturl_url"
}

get_latest_version () {
	basename "$(curl -s -o /dev/null -I -w "%{redirect_url}" https://github.com/nikolay/wshare/releases/latest)"
}

show_usage () {
	cat <<-EOF
		Usage: $(basename $0) COMMAND

		Commands:
		    -h|--help                    Shows usage
		    -c|--clean|--cleanup         Deletes expired uploads
		   [-s|--share] FILE|URL [TTL]  Shares a file or URL with TTL in minutes (default: 5)
		    -u|--upgrade                 Upgrades wshare to the latest version
		    -d|--delete	FILE...          Deletes files under $WSHARE_HOME (used internally)
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
		("-h" | "--help")
			shift
			show_usage
			;;
		("-c" | "--clean" | "--cleanup")
			shift
			cleanup
			;;
		("-d" | "--delete")
			shift
			delete "$@"
			;;
		("-u" | "--upgrade")
			shift
			install
			;;
		("-s" | "--share")
			shift
			share "$@"
			;;
		*)
			main --share "$@"
			;;
	esac
}

assignment () {
	local variable="${1:-}"
	local value="${2:-}"

	echo "$variable=\"$value\""
}

do_install () {
	mkdir -p "$(dirname "$WSHARE_BIN")"
	rm -f "$WSHARE_BIN"
	echo "${BASH_EXECUTION_STRING/$(assignment WSHARE_VERSION)/$(assignment WSHARE_VERSION "$(get_latest_version)")}" > "$WSHARE_BIN"
	chmod +x "$WSHARE_BIN"
}

check_install () {
	[[ "$(type -t wshare)" == "file" ]]
}

install () {
	local os="$(uname)"
	case "$os" in
		(Linux | Darwin)
			[[ "$(whoami)" != "root" ]] || die "Don't install with sudo or as root"

			local -i upgrade=0
			check_install && upgrade=1

			do_install

			if ! check_install; then
				cat <<-EOF
					In order to make wshare work, you need to add the following
					to your .bashrc/.bash_profile/.profile file:

					    export PATH="$HOME/bin:$PATH"

				EOF
			fi

			local version="$(get_latest_version)"
			if [[ $upgrade -eq 1 ]]; then
				echo "Successfully upgraded wshare to $version"
			else
				echo "Successfully installed wshare $version"
			fi

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
