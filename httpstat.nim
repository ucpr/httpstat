import terminal
import strutils, pegs, unicode

const
  HTTPS_TEMPLATE = """
    DNS Lookup   TCP Connection   TLS Handshake   Server Processing   Content Transfer
  [  $1  |    $2    |   $3    |     $4      |     $5     ]
               |                |               |                   |                  |
      namelookup:$6        |               |                   |                  |
                          connect:$7       |                   |                  |
                                      pretransfer:$8           |                  |
                                                        starttransfer:$9          |
                                                                                  total:$10
  """
  HTTP_TEMPLATE = """
    DNS Lookup   TCP Connection   Server Processing   Content Transfer
  [  $1  |    $2    |     $3      |     $4     ]
               |                |                   |                  |
      namelookup:$5        |                   |                  |
                          connect:$6           |                  |
                                        starttransfer:$7          |
                                                                   total:$8
  """


proc make_color(code: int): proc =
  proc color_func(s: string): string =
    if not isatty(stdout):  # https://nim-lang.org/docs/terminal.html
      return s
    var tpl: string = "\x1b[$1m$2\x1b[0m"

    return tpl % [$code, s]
  return color_func


if isMainModule:
  echo make_color(32)("okinawa")
