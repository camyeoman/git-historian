use helpers *

const JIRA_CODES = [
  AIQX
  ABC
  ALBINT
  ALCON
  AP3IP
  APD
  AN
  AF
  ATCOSS
  ATCMHR
  BRID
  BCC
  BH
  BANK
  CTS
  CGAM
  CCM
  CRS
  CCH
  CSR
  CSSD
  DF
  DEMAND
  DEVOPS
  DKSH
  ER2
  EM
  FEN
  FPH
  FBS
  GAZ
  GLEN
  GB
  HY
  IDEM
  IF
  IMAX
  IN
  CAPEX
  CPXPM
  IQXCONSULT
  IDM
  FRT
  FAB
  IQFM
  IIM
  IKT
  ILD
  IMS
  IQM
  IQMY
  OLAPSAP
  OLAPP
  OLOUT
  OLSER
  OLS
  OWA
  PS
  RWFAB
  IR
  IQXSAASOP
  IQ
  IQXDESK
  CPXONLINE
  SOCP
  IQXSAASVC
  IQXS4P
  I2
  IXM
  JBS
  KG
  KPMG
  MKS
  MAC
  MMGF
  MOLP
  MWA
  NCS
  NP
  OCT
  ONESUN
  PCOR
  PRATT
  PRDEMAND
  PT2
  PTC
  REM
  RES
  RDP
  RHEEM
  RG
  IQXVPIP
  SSP
  SSPA
  SANTOS
  SCM
  STT
  SMG
  SITAVM
  SOD
  SOL
  SCT
  AUSM
  STAP
  SC
  TKI
  TEST
  TP
  TSTS3
  TG01
  TCS
  TOL
  TAC
  TOYOT
  TCSP
  TSM
  TNSW
  SVP
  VISY
  VC
  WOM
  WEIR
  XEL
  YCL
  ZES
  AUSM
  STAP
  SC
  TKI
  TEST
  TP
  TSTS3
  TG01
  TCS
  TOL
  TAC
  TOYOT
  TCSP
  TSM
  TNSW
  SVP
  VISY
  VC
  WOM
  WEIR
  XEL
  YCL
  ZES
  ZOL
  ZPM
]

export def list-jira-codes [] {
  $JIRA_CODES
}

export def get-jira-ticket-regex [] {
  $JIRA_CODES
  | str join "|"
  | $"\(?:($in)\)-\\d+"
}

const TICKET_COLORS = [
  (ansi xterm_lightskyblue3b)
  (ansi xterm_orange4a)
  (ansi red)
  (ansi xterm_mediumpurple1)
  (ansi xterm_darkolivegreen1b)
  (ansi xterm_lightcoral)
  (ansi xterm_palevioletred1)
  (ansi xterm_lightgoldenrod1)
  (ansi cyan)
  (ansi xterm_orange4b)
  (ansi xterm_darkolivegreen3b)
  (ansi xterm_green)
  (ansi magenta)
  (ansi xterm_lightgoldenrod2b)
  (ansi xterm_cyan3)
  (ansi xterm_lightskyblue1)
  (ansi light_green)
  (ansi xterm_lightskyblue3a)
  (ansi xterm_springgreen4)
  (ansi xterm_teal)
  (ansi xterm_lightsteelblue)
  (ansi xterm_orange1)
  (ansi xterm_olive)
  (ansi yellow)
  (ansi light_magenta)
  (ansi xterm_orange3)
  (ansi xterm_lightsalmon1)
  (ansi xterm_honeydew2)
  (ansi yellow_dimmed)
  (ansi xterm_darkolivegreen3c)
  (ansi xterm_darkorange3b)
  (ansi red_dimmed)
  (ansi purple)
  (ansi xterm_orangered1)
  (ansi xterm_lightgoldenrod2a)
  (ansi xterm_darkorange)
  (ansi magenta_dimmed)
  (ansi xterm_purplea)
  (ansi xterm_lightsalmon3b)
  (ansi purple_dimmed)
  (ansi xterm_lightsalmon3a)
  (ansi light_yellow)
  (ansi xterm_darkolivegreen3a)
  (ansi light_blue)
  (ansi xterm_lightgoldenrod2)
  (ansi xterm_navy)
  (ansi xterm_cadetblueb)
  (ansi xterm_darkorange3a)
  (ansi xterm_lightgoldenrod3)
  (ansi cyan_dimmed)
  (ansi xterm_darkolivegreen1a)
  (ansi xterm_mediumspringgreen)
  (ansi xterm_cadetbluea)
  (ansi xterm_lightslateblue)
]

export def get-ticket-color []: any -> string {
  if ($in == null) { return (ansi red) }
  let ticket = $in
  let color_index = if ($ticket =~ '^[A-Z]{3,}-\d+$') {
    $ticket
    | split row '-'
    | last
    | into int
    | $in mod ($TICKET_COLORS | length | $in - 1)
  } else {
    $ticket
    | hash md5 -b
    | chunks 2
    | each { into int }
    | math sum
    | $in mod ($TICKET_COLORS | length | $in - 1)
  }

  $TICKET_COLORS | get $color_index
}

export def highlight-ticket-codes-in-message [ticket_regex: string]: string -> string {
  let ticket_format = $"\(?<ticket>($ticket_regex)\)"
  let ticket = $in
  | parse -r $ticket_format
  | get -i 0.ticket

  let message = $"(ansi grey)($in)(ansi reset)"
  if ($ticket == null) { return $message }

  $message
  | str replace -a $ticket $'($ticket | get-ticket-color)($ticket)(ansi grey)'
}

export def extract-ticket-code [
  hash: string
  body: string
  ref: string
  ticket_regex: string
]: nothing -> record {
  let ticket_format = $"\(?<ticket>($ticket_regex)\)"
  let commit_formats = [
    $"^\(?<ticket>($ticket_regex)\):\\s*\(?<message>.*\)"
    $ticket_format
    $"^\(?<ticket>[mM][eE][eE][tT][iI][nN][gG]\)"
  ]

  $body
  | find-first-match-of ...$commit_formats
  | if ($in != null) { $in } else {
    ^git name-rev --name-only $hash
    | lines
    | first 1
    | each { str replace -r '([\^\~]\d+)+$' '' }
    | get 0?
    | find-first-match-of $ticket_format
  }
  | default ({ ticket: null })
  | upsert message { default $body }
  | update ticket { if ($in != null) { str trim } else { $in } }
}
