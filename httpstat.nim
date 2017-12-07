import tables
import random, future
import terminal, times
import os, ospaths, posix
import strutils, pegs, unicode

randomize()

const VERSION = "0.0.1"
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

const curl_format = """{
  "time_namelookup": %{time_namelookup},
  "time_connect": %{time_connect},
  "time_appconnect": %{time_appconnect},
  "time_pretransfer": %{time_pretransfer},
  "time_redirect": %{time_redirect},
  "time_starttransfer": %{time_starttransfer},
  "time_total": %{time_total},
  "speed_download": %{speed_download},
  "speed_upload": %{speed_upload},
  "remote_ip": "%{remote_ip}",
  "remote_port": "%{remote_port}",
  "local_ip": "%{local_ip}",
  "local_port": "%{local_port}"
}"""


proc echo_help(): int {. discardable .} =
  var help: string = """
  Usage: httpstat URL [CURL_OPTIONS]
         httpstat -h | --help
         httpstat --version
  Arguments:
    URL     url to request, could be with or without `http(s)://` prefix
  Options:
    CURL_OPTIONS  any curl supported options, except for -w -D -o -S -s,
                  which are already used internally.
    -h --help     show this screen.
    -v --version     show version.
  Environments:
    HTTPSTAT_SHOW_BODY    Set to `true` to show response body in the output,
                          note that body length is limited to 1023 bytes, will be
                          truncated if exceeds. Default is `false`.
    HTTPSTAT_SHOW_IP      By default httpstat shows remote and local IP/port address.
                          Set to `false` to disable this feature. Default is `true`.
    HTTPSTAT_SHOW_SPEED   Set to `true` to show download and upload speed.
                          Default is `false`.
    HTTPSTAT_SAVE_BODY    By default httpstat stores body in a tmp file,
                          set to `false` to disable this feature. Default is `true`
    HTTPSTAT_CURL_BIN     Indicate the curl bin path to use. Default is `curl`
                          from current shell $PATH.
    HTTPSTAT_DEBUG        Set to `true` to see debugging logs. Default is `false`
  """
  echo help

proc random_str(size: int): string =
  let words = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  result = ""  # return result
  for i in countup(0, size):
    result &= words[random(61)]  # len(words) == 62

proc make_color(code: string): proc =
  proc color_func(s: string): string =
    if not isatty(stdout):  # https://nim-lang.org/docs/terminal.html
      return s
    var tpl: string = "\x1b[$1m$2\x1b[0m"

    return tpl % [code, s]
  return color_func

proc grayscale(i: int, s: string): string =
  var code: int = 232 + i
  return  make_color("38;5;" & $code)(s)

let
  red = make_color("31")
  green = make_color("32")
  yellow = make_color("33")
  blue = make_color("34")
  magenta = make_color("35")
  cyan = make_color("36")

  bold = make_color("1")
  underline = make_color("4")


proc main(): int =
  if paramCount() == 0:
    echo_help()
    quit(0)

  var argv: seq[string] = commandLineParams()

  var url: string = argv[0]
  if url in ["-h", "--help"]:
    echo_help()
    quit(0)
  elif url in ["-v", "--version"]:
    echo "httpstat $1" % [VERSION]
    quit(0)

  # https://nim-lang.org/docs/future.html
  # py: [argv[i] for i in range(1, paramCount())]
  var curl_args = lc[argv[x] | (x <- 1..(paramCount() - 1)), string]

  # check curl args
  var exclude_options = @[
    "-w", "--write-out",
    "-D", "--dump-header",
    "-o", "--output",
    "-s", "--silent"
  ]
  for i in exclude_options:
    if i in curl_args:
      echo yellow("Error: $1 is not allowed in extra curl args" % [i])
      quit(1)

  let
    bodyf = "/tmp/httpstatbody-" & getDateStr() & random_str(8) & getClockStr()
    headerf = "/tmp/httpstatheader-" & getDateStr() & random_str(8) &  getClockStr()

  # https://www.tutorialspoint.com/c_standard_library/c_function_setlocale.htm
  # https://nim-lang.org/docs/posix.html
  discard setlocale(LC_ALL, "C")

  
if isMainModule:
  #echo make_color(32)("okinawa")
  #echo_help()
  discard main()
  echo random_str(8)
