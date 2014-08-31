# wshare

## About

[wshare](https://github.com/nikolay/wshare) wraps [Zeropaste](http://0paste.com) by [@edogawaconan](https://github.com/edogawaconan) with [ShoutKey](http://shoutkey.com/) by [@jazzychad](https://github.com/jazzychad) to allow uploading text files from the console and producing short and easy to remember URL that don't require clipboard access or great short-term memory. This also works around Zeropaste's limitation of not having an autodestruct option by recording the deletion keys locally and providing a command to delete the expired ones.

## Installation

    bash -c "$(curl "https://raw.githubusercontent.com/nikolay/wshare/master/wshare.sh")"

## Usage

    Usage: wshare COMMAND

    Commands:
        -h|--help                Shows usage
        -c|--clean|--cleanup     Deletes expired uploads
        [-s|--share] FILE [TTL]  Shares a file with TTL in minutes (default: 5)
        -d|--delete	FILE...      Deletes files under ~/.wshare (used internally)

## Supported Platforms

- [x] Linux
- [x] OS X
- [ ] Windows

## License

The license of the project is the [MIT](https://github.com/limetext/lime/blob/master/LICENSE).