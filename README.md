[![Stories in Ready](https://badge.waffle.io/nikolay/wshare.png?label=ready&title=Ready)](https://waffle.io/nikolay/wshare)
# wshare

## About

[wshare](https://github.com/nikolay/wshare) wraps [Zeropaste](http://0paste.com) by [@edogawaconan](https://github.com/edogawaconan) with [ShoutKey](http://shoutkey.com/) by [@jazzychad](https://github.com/jazzychad) to allow uploading text files from the console and producing short and easy to remember URL that don't require clipboard access or great short-term memory. This also works around Zeropaste's limitation of not having a self-destruct option by recording the deletion keys locally and providing a command to delete the expired ones.

## Installation

    bash -c "$(curl -sL git.io/wshare || echo "echo Installation failed; exit 1")"

## Usage

    Usage: wshare COMMAND

    Commands:
        -h|--help                   Shows usage
        -c|--clean|--cleanup        Deletes expired uploads
       [-s|--share] FILE|URL [TTL]  Shares a file/URL; TTL in minutes (default: 5)
        -u|--upgrade|--update       Upgrades wshare to the latest version
        -d|--delete	FILE...         Deletes files under ~/.wshare (used internally)

## Supported Platforms

- [x] Linux
- [x] OS X
- [ ] Windows

## License

Licensed under [MIT](https://github.com/nikolay/wshare/blob/master/LICENSE).
Copyright by [Nikolay Kolev](https://github.com/nikolay).

[![Bitdeli Badge](https://d2weczhvl823v0.cloudfront.net/nikolay/wshare/trend.png)](https://bitdeli.com/free "Bitdeli Badge")

