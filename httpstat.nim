import tables, json
import std/random, sugar
import terminal, times
import std/os, osproc, posix
import strutils, re
import sequtils

randomize()

const
  Version = "0.1.2"

  httpsTemplate = """
    DNS Lookup   TCP Connection   TLS Handshake   Server Processing   Content Transfer
  [  $1   |    $2     |    $3    |      $4      |     $5     ]
               |                |               |                   |                 |
     namelookup:$6         |               |                   |                 |
                         connect:$7        |                   |                 |
                                     pretransfer:$8            |                 |
                                                       starttransfer:$9          |
                                                                                 total:$10
  """
  httpTemplate = """
    DNS Lookup   TCP Connection   Server Processing   Content Transfer
  [  $1   |   $2      |     $4       |     $5      ]
               |                |                   |                  |
     namelookup:$6         |                   |                  |
                         connect:$7            |                  |
                                       starttransfer:$9           |
                                                                  total:$10
  """

  curlFormat = """'{
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
  }'"""

proc showHelp(): int {. discardable .} =
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
  """
  echo help

proc getRandomStr(size: int): string =
  let words = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  result = ""  # return result
  for i in countup(0, size):
    result &= words[rand(61)]  # len(words) == 62

proc makeColor(code: string): proc =
  proc colorProc(s: string): string =
    if not isatty(stdout):  # https://nim-lang.org/docs/terminal.html
      return s
    var tpl: string = "\x1b[$1m$2\x1b[0m"

    return tpl % [code, s]
  return colorProc

proc grayScale(i: int, s: string): string =
  var code: int = 232 + i
  return  makeColor("38;5;" & $code)(s)

let
  red = makeColor("31")
  green = makeColor("32")
  yellow = makeColor("33")
  blue = makeColor("34")
  magenta = makeColor("35")
  cyan = makeColor("36")

  bold = makeColor("1")
  underline = makeColor("4")

proc parseOutput(s: string): string =
  let pattern = re"""\"\w*\":\s?\D?[0-9].*\D?\s?"""
  result = "{"
  for i in s.findAll(pattern):
    result &= i
  result &= "}"

proc main() =
  if paramCount() == 0:
    showHelp()
    quit(0)

  var argv: seq[string] = commandLineParams()

  let url = argv[0]
  if url in ["-h", "--help"]:
    showHelp()
    quit(0)
  elif url in ["-v", "--version"]:
    echo "httpstat $1" % [Version]
    quit(0)

  let
    showBody = if getEnv("HTTPSTAT_SHOW_BODY") == "": "false" else: getEnv("HTTPSTAT_SHOW_BODY")
    showIp = if getEnv("HTTPSTAT_SHOW_IP") == "": "true" else: getEnv("HTTPSTAT_SHOW_IP")
    showSpeed = if getEnv("HTTPSTAT_SHOW_SPEED") == "": "false" else: getEnv("HTTPSTAT_SHOW_SPEED")
    saveBody = if getEnv("HTTPSTAT_SAVE_BODY") == "": "true" else: getEnv("HTTPSTAT_SAVE_BODY")
    curlBin = if getEnv("HTTPSTAT_CURL_BIN") == "": "curl" else: getEnv("HTTPSTAT_CURL_BIN")

  let curlArgs = collect(newSeq):
    for i in 1..(paramCount()-1):
      argv[i]

  # check curl args
  var excludeOptions = @[
    "-w", "--write-out",
    "-D", "--dump-header",
    "-o", "--output",
    "-s", "--silent"
  ]
  for i in excludeOptions:
    if i in curlArgs:
      echo yellow("Error: $1 is not allowed in extra curl args" % [i])
      quit(1)

  let
    bodyf = "/tmp/httpstatbody-" & getDateStr() & getRandomStr(8) & getClockStr()
    headerf = "/tmp/httpstatheader-" & getDateStr() & getRandomStr(8) &  getClockStr()

  # https://www.tutorialspoint.com/c_standard_library/c_function_setlocale.htm
  # https://nim-lang.org/docs/posix.html
  discard setlocale(LC_ALL, "C")
  let
    cmdCore = @[curlBin, "-w", curlFormat, "-D", headerf, "-o", bodyf, "-s", "-S"]
    cmd = concat(cmdCore, @[curlArgs.join(" "), url])

  let p = execCmdEx(cmd.join(" "))  # tuple[output, exitCode]

  # print stderr
  if p.exitCode != 0:
    var msg = cmd
    msg[2] = "<output-format>"
    msg[4] = "<tempfile>"
    msg[6] = "<tempfile>"
    echo "> $1" % [msg.join(" ")]
    echo yellow("curl error: $1" % [p.output.split("\n")[0]])
    quit(p.exitCode)

  # parse output(json)
  let pJson: JsonNode = parseJson(parseOutput(p.output))

  var d = initTable[string, string]()
  for key, value in pJson:
    if startsWith(key, "time_"):
      d[key] = $int(pJson[key].getFloat() * 1000)
    else:
      d[key] = $value

  # calculate ranges
  d["range_dns"] = $d["time_namelookup"].parseInt()
  d["range_connection"] = $(d["time_connect"].parseInt() - d["time_namelookup"].parseInt())
  d["range_ssl"] = $(d["time_pretransfer"].parseInt() - d["time_connect"].parseInt())
  d["range_server"] = $(d["time_starttransfer"].parseInt() - d["time_pretransfer"].parseInt())
  d["range_transfer"] = $(d["time_total"].parseInt() - d["time_starttransfer"].parseInt())

  # ip
  if showIp == "true":
    let s = "Connected to $1:$2 from $3:$4" % [
      cyan(d["remote_ip"]), cyan(d["remote_port"]),
      cyan(d["local_ip"]), cyan(d["local_port"]),
    ]
    echo s, "\n"

  # print header & body summary
  block headerBlock:
    let f: File = open(headerf, FileMode.fmRead)
    defer:
      f.close()
      removeFile(headerf)  # remove header tmp file

    var loop: int = 0
    while f.endOfFile == false:
      if loop == 0:
        let header = f.readLine().split("/")
        echo green(header[0]) & grayScale(14, "/") & cyan(header[1])
        inc(loop)
      else:
        let
          header = f.readLine()
          pos = header.find(":")
        echo grayScale(14, header[0..pos]) & cyan(header[(pos + 1)..(len(header) - 1)])

  block bodyBlock:
    if showBody != "true":
      if saveBody == "true":
        echo "$1 stored in: $2" % [green("Body"), bodyf]
      break bodyBlock

    const bodyLimit = 1024
    let f: File = open(bodyf, FileMode.fmRead)
    defer:
      f.close()
      if saveBody != "true":
        removeFile(bodyf)  # remove body tmp file

    let
      body = f.readAll()
      bodyLength = len(body)
    if bodyLength > bodyLimit:
      echo body[0..(bodyLimit - 1)] & cyan("..."), "\n"
      var s = "$1 is truncated ($2 out of $3)" % [green("Body"), $bodyLimit, $bodyLength]
      if saveBody == "true":
        s.add(", stored in: {}" % [bodyf])
      echo s
    else:
      echo body

    echo httpTemplate.split("\n")

  # colorize template
  var tmp = (if url.startsWith("https://"): httpsTemplate else: httpTemplate)
  tmp = tmp[1..len(tmp)-1]

  var tplParts: seq[string] = tmp.split("\n")
  tplParts[0] = grayScale(16, tplParts[0])
  var templ: string = tplParts.join("\n")

  proc fmta(s: string): string =
    return cyan(center(s & "ms", 7))

  proc fmtb(s: string): string =
    return cyan(alignLeft(s & "ms", 7))

  let stat = templ % [
    fmta(d["range_dns"]), fmta(d["range_connection"]),
    fmta(d["range_ssl"]), fmta(d["range_server"]),
    fmta(d["range_transfer"]),

    fmtb(d["time_namelookup"]), fmtb(d["time_connect"]),
    fmtb(d["time_pretransfer"]), fmtb(d["time_starttransfer"]),
    fmtb(d["time_total"])
  ]

  echo "\n", stat

  if showSpeed == "true":
    echo "speed_download: $1 KiB/s, speed_upload: $2 KiB/s" % [d["speed_download"], d["speed_upload"]]

if isMainModule:
  main()
