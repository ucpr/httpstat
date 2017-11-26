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
