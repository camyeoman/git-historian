use ticket-codes.nu *
use metadata.nu *
use helpers *

def tap-table [map?: closure] {
  $in
  | if ($map != null) { do $map } else { $in }
  | print ($in | table -e)
  $in
}

const FMT_TAG = {
  commit_hash: "%H"
  abbreviated_commit_hash: "%h"
  tree_hash: "%T"
  abbreviated_tree_hash: "%t"
  parent_hashes: "%P"
  abbreviated_parent_hashes: "%p"
  author_name: "%an"
  author_name_respecting_mailmap_see_git_shortlog_1_or_git_blame_1: "%aN"
  author_email: "%ae"
  author_email_respecting_mailmap_see_git_shortlog_1_or_git_blame_1: "%aE"
  author_email_local_part_the_part_before_the_@_sign: "%al"
  author_local_part_see_al_respecting_mailmap_see_git_shortlog_1_or_git_blame_1: "%aL"
  author_date_format_respects_date_option: "%ad"
  author_date_rfc2822_style: "%aD"
  author_date_relative: "%ar"
  author_date_unix_timestamp: "%at"
  author_date_iso8601_like_format: "%ai"
  author_date_strict_iso8601_format: "%aI"
  author_date_short_format_yyyymmdd: "%as"
  author_date_human_style_like_the_date_human_option_of_git_rev_list_1: "%ah"
  committer_name: "%cn"
  committer_name_respecting_mailmap_see_git_shortlog_1_or_git_blame_1: "%cN"
  committer_email: "%ce"
  committer_email_respecting_mailmap_see_git_shortlog_1_or_git_blame_1: "%cE"
  committer_email_local_part_the_part_before_the_@_sign: "%cl"
  committer_local_part_see_cl_respecting_mailmap_see_git_shortlog_1_or_git_blame_1: "%cL"
  committer_date_format_respects_date_option: "%cd"
  committer_date_rfc2822_style: "%cD"
  committer_date_relative: "%cr"
  committer_date_unix_timestamp: "%ct"
  committer_date_iso8601_like_format: "%ci"
  committer_date_strict_iso8601_format: "%cI"
  committer_date_short_format_yyyymmdd: "%cs"
  committer_date_human_style_like_the_date_human_option_of_git_rev_list_1: "%ch"
  ref_names_like_the_decorate_option_of_git_log_1: "%d"
  ref_names_without_the_wrapping: "%D"
  ref_name: "%S"
  encoding: "%e"
  subject: "%s"
  sanitized_subject_line_suitable_for_a_filename: "%f"
  body: "%b"
  raw_body_unwrapped_subject_and_body: "%B"
  commit_notes: "%N"
  raw_verification_message_from_gpg_for_a_signed_commit: "%GG"
  show_the_name_of_the_signer_for_a_signed_commit: "%GS"
  show_the_key_used_to_sign_a_signed_commit: "%GK"
  show_the_fingerprint_of_the_key_used_to_sign_a_signed_commit: "%GF"
  show_the_fingerprint_of_the_primary_key_whose_subkey_was_used_to_sign_a_signed_commit: "%GP"
  show_the_trust_level_for_the_key_used_to_sign_a_signed_commit: "%GT"
  reflog_identity_name: "%gn"
  reflog_identity_name_respecting_mailmap_see_git_shortlog_1_or_git_blame_1: "%gN"
  reflog_identity_email: "%ge"
  reflog_identity_email_respecting_mailmap_see_git_shortlog_1_or_git_blame_1: "%gE"
  reflog_subject: "%gs"
}

# implement helper functions to parse the git log

let TICKET_REGEX = (get-jira-ticket-regex)

def format-output-message [repeated: bool = false]: string -> string {
  truncate-string -c (ansi grey) -r 0.5
  | highlight-ticket-codes-in-message $TICKET_REGEX
}

def format-output-date [repeated: bool = false]: datetime -> string {
  if ($repeated) { return $"(ansi blue)     |     (ansi reset)" }
  $in
  | format date '%I:%M:%S %p'
  | $"(ansi blue)($in)(ansi reset)"
}

def format-output-ticket [repeated: bool = false]: any -> string {
  let color = $in | get-ticket-color
  if ($repeated) { return ($color + ("|" | fill -w 21 -a c) + (ansi reset)) }
  $in
  | default $"(ansi red)???(ansi reset)"
  | fill -w 21 -a c
  | $"($color)($in)(ansi reset)"
}

def format-week-date []: datetime -> string {
  $in
  | format date '%d %b'
  | $"(ansi green)($in)(ansi reset)"
}

def format-calendar-date []: datetime -> string {
  $in
  | format date '%a %d %b'
  | $"(ansi cyan)($in)(ansi reset)"
}

def format-month-date []: datetime -> string {
  $in
  | format date '%B'
  | $"(ansi green)($in)(ansi reset)"
}

def save-to-cache [cache_path: string, key: string] {
  save -f ($cache_path | path join $key)
}

def get-from-cache [cache_path: string, key: string] {
  let content_path = $cache_path | path join $key
  if (not ($content_path | path exists)) { return null }
  open $content_path
}

def clear-cache [cache_path: string] {
  if ($cache_path | path exists) {
    rm -r $cache_path
  }
}

# implement functions to parse the git log

const LOG_FMT = [
  ["date", $FMT_TAG.author_date_unix_timestamp]
  ["hash", $FMT_TAG.commit_hash]
  ["ref", $FMT_TAG.ref_names_without_the_wrapping]
  ["body", $FMT_TAG.raw_body_unwrapped_subject_and_body]
]

def list-logs-for-branch [
  sdate: datetime
  edate: datetime
  author: string
  branch: string
] {
  let fmt_string = ($LOG_FMT | each { get 1 } | str join "»¦«") + "¦»EOL«¦"
  let output = (
    ^git log
      $branch
      --format=$"($fmt_string)"
      --author=$"($author)"
      --after=$"($sdate | $in - 5hr | gdate)"
      --before=$"($edate | $in + 5hr | gdate)"
      --
  )

  if ($output | is-empty) { return [] }
  return (
    $output
    | split row "¦»EOL«¦"
    | where { is-not-empty }
    | each { str trim }
    | where { is-not-empty }
    | each { str trim | split column "»¦«" ...($LOG_FMT | each { get 0 }) }
    | flatten
    | update date {
      into int
      | $in * 1000000000
      | into datetime -z LOCAL
    }
    | insert branch $branch
    | where date >= $sdate and date <= $edate
  )
}

def list-git-logs-in-range [
  start_date: datetime
  end_date: datetime
  author: string
] {
  let sdate = $start_date | start-of-day
  let edate = $end_date | end-of-day
  let fmt_string = ($LOG_FMT | each { get 1 } | str join "»¦«") + "¦»EOL«¦"

  (
    ^git log
      --all
      --format=$"($fmt_string)"
      --author=$"($author)"
      --after=$"($sdate | $in - 5hr | gdate)"
      --before=$"($edate | $in + 5hr | gdate)"
  ) | if ($in | is-empty) { [] } else {
    split row "¦»EOL«¦"
    | each { str trim }
    | where { is-not-empty }
    | each { str trim | split column "»¦«" ...($LOG_FMT | each { get 0 }) }
    | flatten
    | update date {
      into int
      | $in * 1000000000
      | into datetime -z LOCAL
    }
    | where date >= $sdate and date <= $edate
    | sort-by date
    | update body { |e| extract-ticket-code $e.hash $e.body $e.ref $TICKET_REGEX }
    | flatten body
    | upsert message { default "" | str trim }
  }
}

def repeat_str [s: string, n: int] {
  seq 0 $n | each { $s } | str join ""
}

def collect-section [
  header: string
  indent: int
  padding: int
]: list<string> -> string {
  if ($in | is-empty) { return "" }
  let padding_str = seq 0 $padding | skip 1 | each { "\n" } | str join ""
  let indent_str = seq 0 $indent | each { " " } | str join ""

  let header_str = if ($header | is-empty) { "" } else { $header + "\n\n" }
  $header_str + (
    $in
    | each { split row "\n" | each { $indent_str + $in } | str join "\n" }
    | str join ($padding_str)
  ) | str trim
}

def get-month-header []: table<month-date: datetime> -> string {
  $"> Worklogs for (ansi green)($in.month-date | format-month-date)(ansi reset)"
}

def get-week-num-for-month [] {
  let date = $in
  let month = $in | get-month
  let start_of_first_week = $date | start-of-month | start-of-week

  ($date | start-of-week) - $start_of_first_week
  | into record
  | ($in.week? | default 0) + 1
  | { no: $in, month: $month }
}

def get-full-week-header []: record<min-date: datetime> -> string {
  let sdate = $in.min-date | start-of-week
  let edate = $in.min-date | end-of-week
  let sdate_str = $sdate | format-week-date
  let edate_str = $edate | format-week-date
  return $"> Worklogs for week of ($sdate_str) to ($edate_str)"
}

def get-month-week-header []: record<min-date: datetime> -> string {
  let sdate = ([($in.min-date | start-of-week), ($in.min-date | start-of-month)] | math max)
  let edate = ([($in.min-date | end-of-week), ($in.min-date | end-of-month)] | math min)
  let sdate_str = $sdate | format-week-date
  let edate_str = $edate | format-week-date
  let week_no = $sdate | get-week-num-for-month
  return ([
    $"> Worklogs for week of ($sdate_str) to ($edate_str)"
    $"(ansi purple)\(Week ($week_no.no) of ($edate | format date '%B')\)(ansi reset)"
  ] | str join " ")
}


def get-date-header []: nothing -> string {
  $"> Worklogs for (ansi green)($in.day-date | format-calendar-date)(ansi reset)"
}

def safe-get [index: int]: list<any> -> any {
  let items = $in
  if ($index < 0 or $index >= ($items | length)) { return null }
  return ($items | get $index)
}

def get-log-output [index: int, items: list] {
  let ppitem = $items | safe-get ($index - 2)
  let pitem = $items | safe-get ($index - 1)
  let curr = $in
  let nitem = $items | safe-get ($index + 1)
  let nnitem = $items | safe-get ($index + 2)

  if (
    seq ($index - 3) ($index + 2) | all { |i|
      $items
      | safe-get $i
      | $in != null and $in.ticket == $curr.ticket
    }
  ) { return "" } # exclude from the output

  let repeated = (
    ($pitem != null and $curr.ticket == $pitem.ticket?)
    and ($nitem != null and $curr.ticket == $nitem.ticket?)
  )

  let is_last = $index == ($items | length | $in - 1)
  let odate = $curr.date | format-output-date $repeated
  let oticket = $curr.ticket | format-output-ticket $repeated
  let omessage = $curr.message | format-output-message $repeated

  $"($odate) ($oticket) ($omessage)(ansi reset)"
}

def aggregate-logs [
  date_path: cell-path
  get_header: closure
  get_content: closure
  group_by?: closure
  --indent (-i): int = 1
  --padding (-p): int = 0
]: table<date: datetime> -> table<date: datetime, log-string: string> {
  update $date_path { format date '%+' }
  | do ($group_by | default { group-by $date_path --to-table })
  | update $date_path { into datetime }
  | sort-by $date_path
  | insert min-date { get items.date | math min }
  | insert max-date { get items.date | math max }
  | update items { |row: record<items: table<date: datetime>>|
    $row.items
    | sort-by date
    | where { is-not-empty }
    | do {
      let items = $in
      $items
      | enumerate
      | each { |e| $e.item | do $get_content $e.index $items }
      | where { is-not-empty }
    }
    | collect-section ($row | do $get_header) $indent $padding
  }
  | select $date_path min-date max-date items
  | rename date min-date max-date log-string
}

def fmt-logs-for-display [
  sdate: datetime
  edate: datetime
  author?: string
  --group-weeks = false
  --split-week-on-month = true
]: table -> any {
  # handle case where no commits are found
  if ($in | is-empty) {
    let week_no = $edate | get-week-num-for-month
    return ([
      "\n\n\n"
      ([
        ($"
        (ansi red)0 commits(ansi reset) found for user
        (ansi purple)($author | default '???')(ansi reset)
        " | dedent -j " ")

        "\n",

        ($"
        For date range ($sdate | format-calendar-date) to ($edate | format-calendar-date)
        (ansi purple)\(Week ($week_no.no) of ($edate | format date '%B')\)(ansi reset)
        " | dedent -j " "),

      ] | each { fill -a c -w (term size | get columns) } | str join "\n")
      "\n\n\n"
    ] | str join "")
  }

  # handle case with valid input
  let twidth = (term size | get columns)
  return ($in
    # define strings for output of command
    | insert day-date { $in.date | start-of-day }
    | aggregate-logs -p 1 $.day-date { get-date-header } { |i, items| get-log-output $i $items }

    # if just grouping by week, don't split up weeks for months
    | if-then {$group_weeks and not $split_week_on_month} {
      insert week-date { $in.date | start-of-week }
      | aggregate-logs -p 2 $.week-date { get-full-week-header } { get log-string }
    }

    # optionally group by week
    | if-then {$group_weeks and $split_week_on_month} {
      insert week-date { $in.date | start-of-week }
      | insert month-no { $in.date | get-month }
      | aggregate-logs -p 2 $.week-date { get-month-week-header } { get log-string } { group-by week-date month-no --to-table }
    }

    # combine all the string into the final output
    | get log-string
    | str join "\n\n"
    | "\n" + $in + "\n"
  )
}

# expose cli methods for the script

def display-saved-projects [] {
  get-saved-projects
  | each { $"(ansi purple)($in)(ansi reset)"}
  | str join "\n"
  | print $in
  return null
}

def main [] {
  nu $env.CURRENT_FILE --help
}

# Lists the saved projects for this computer.
@example "list projects" { nu ~/.scripts/worklog/cli.nu projects list }
def 'main projects' [] {
  print $" > List of (ansi green)saved projects(ansi reset)"
  display-saved-projects
}

# Saves the current, or specified path as a saved project.
@example "save the path as git repository" { nu ~/.scripts/worklog/cli.nu projects save ~/Code/example-project }
@example "save the current git repository (while in said repository)" { nu ~/.scripts/worklog/cli.nu projects save }
def 'main projects save' [...paths: string] {
  $paths
  | if ($in | is-empty) { append (get-current-project) } else { $in }
  | save-projects

  print $" > (ansi blue)Updated(ansi reset) list of (ansi green)saved projects(ansi reset) to"
  display-saved-projects
}

# Select the projects to delete from a multi-select list
@example "delete saved projects" { nu ~/.scripts/worklog/cli.nu projects delete }
def 'main projects delete' [] {
  let to_delete = (get-saved-projects | input list -m)
  get-saved-projects
  | where { $in not-in $to_delete }
  | overwrite-saved-projects

  print $" > (ansi blue)Updated(ansi reset) list of (ansi green)saved projects(ansi reset) to"
  display-saved-projects
}

# Gets the worklogs for a specified date
@example "get worklogs for today" { nu ~/.scripts/worklog/cli.nu logs-for date }
@example "get worklogs for 12th of current month and year" { nu ~/.scripts/worklog/cli.nu logs-for date 12 }
@example "get worklogs for 12th of may for current year" { nu ~/.scripts/worklog/cli.nu logs-for date 12 5 }
@example "get worklogs for 12/05/2023" { nu ~/.scripts/worklog/cli.nu logs-for date 12 5 2023 }
@example "get worklogs for all saved projects for today" { nu ~/.scripts/worklog/cli.nu logs-for date --all-saved-projects }
@example "get worklogs for all saved projects for today" { nu ~/.scripts/worklog/cli.nu logs-for date -A }
@example "get worklogs for all saved projects for the 12th of current month and year" { nu ~/.scripts/worklog/cli.nu logs-for date 12 --all-saved-projects }
def 'main logs-for date' [
  day?: int
  month?: int
  year?: int
  --all-saved-projects (-A) # query logs from all saved projects instead of current project
  --author (-a): string
  --projects-file (-p): string # like --all-saved-projects, but specify path to file containing specific list of projects
] {
  clear -k
  let date = (datefrom $day $month $year)
  let author = $author | if ($in | is-empty) { get-author-email } else { $in }

  get-projects $projects_file --all $all_saved_projects
  | par-each { cd $in; list-git-logs-in-range $date $date $author }
  | flatten
  | fmt-logs-for-display $date $date $author
}

# Starts an interactive view of worklogs by week
#
# This gets all the worklogs over all saved projects automatically.
def 'main logs' [
  day?: int
  month?: int
  year?: int
  --author (-a): string
  --projects-file (-p): string  # like --all, but specify path to file containing specific list of projects
] {
  update-program # automatically retrieve latest updates

  let cache_path = mktemp -d
  let now = date now
  let initial_date = $now | start-of-week
  let author = $author | if ($in | is-empty) { get-author-email } else { $in }

  def offset-date [offset: int]: datetime -> datetime {
    let idate = $in
    let ndate = $idate + ($offset * 1wk)
    match ($offset) {
      -1 => ($idate
        | start-of-month-week
        | if (($idate | start-of-day) == $in) { $in - 1day | start-of-month-week } else { $ndate }
      )
      +1 => ($idate
        | end-of-month-week
        | if (($idate | end-of-day) == $in) { $in + 1day | start-of-month-week } else { $ndate }
      )
      _ => $ndate
    } | start-of-day
  }

  def listen-for-paging [] {
    while (true) {
      let cont = input listen -t [key] | match ($in) {
        { type: key, code: left } => (-1),
        { type: key, code: h } => (-1),
        { type: key, code: a } => (-1),

        # { type: key, code: left, modifiers: ["keymodifiers(shift)"] } => "last-month",
        # { type: key, code: H } => "last-month",
        # { type: key, code: A } => "last-month",

        # { type: key, code: right, modifiers: ["keymodifiers(shift)"] } => "next-month",
        # { type: key, code: L } => "next-month",
        # { type: key, code: D } => "next-month",

        { type: key, code: right } => (+1) ,
        { type: key, code: l } => (+1) ,
        { type: key, code: d } => (+1) ,

        { type: key, code: esc } => null,
        { type: key, code: q } => null,
        { type: key, code: c, modifiers: ["keymodifiers(control)"] } => null
        _ => "invalid"
      }

      if ($cont != "invalid") { return $cont }
    }
  }

  def get-result [ref_date: datetime, author: string] {
    let sdate = $ref_date | start-of-month-week
    let edate = $sdate | end-of-month-week
    let key = $"($sdate | format date '%F')_to_($edate | format date '%F')"
    let cached = get-from-cache $cache_path $key
    if ($cached != null) { return $cached }

    let output = get-projects $projects_file --all true
    | par-each { cd $in; list-git-logs-in-range $sdate $edate $author }
    | flatten
    | fmt-logs-for-display $sdate $edate $author --group-weeks true

    $output | save-to-cache $cache_path $key
    return $output
  }

  def show-controls-string [] {
    $"
    (ansi blue)q(ansi reset) (ansi purple)\(quit\)(ansi reset)
    (ansi blue)left(ansi reset) (ansi purple)\(-1 week\)(ansi reset)
    (ansi blue)right(ansi reset) (ansi purple)\(+1 week\)(ansi reset)
    "
    | dedent -j " | "
    | $"(ansi green)KEY-BINDINGS(ansi reset) > ($in)"
    | fill --width (term size).columns -a c
    | "\n" + $in + "\n"
  }

  def move-up [rows: int] {
    $"\e[($rows)A"
  }

  try {
    mut ref_date = $initial_date
    while (true) {
      # get and output the current result
      clear
      get-result $ref_date $author
      | (show-controls-string) + $in
      | print $in

      # cache the next/prev results
      get-result ($ref_date | offset-date -1) $author
      get-result ($ref_date | offset-date +1) $author

      # listen for user input, waiting again if trying to look at future
      mut offset = listen-for-paging
      while ($offset != null and (
        $offset == 0 or (
          ($offset | describe | $in == "int")
          and (($ref_date | offset-date $offset) > $now)
        )
      )) { $offset = listen-for-paging }

      $ref_date = match ($offset) {
        null => { break }
        invalid => $ref_date,
        next-month => ($ref_date | $in + 6wk | start-of-month | start-of-week),
        last-month => ($ref_date | $in - 6wk | start-of-month | start-of-week),
        _ => ($ref_date | offset-date $offset)
      }
    }
  } catch { |error|
    clear
    print "An error occured!" $error
  }

  clear-cache $cache_path # delete all cached files
}

# Gets the worklogs for the specified week
@example "get worklogs for the current week" { nu ~/.scripts/worklog/cli.nu logs-for week }
@example "get worklogs for the last week" { nu ~/.scripts/worklog/cli.nu logs-for week --offset -1 }
@example "get worklogs for the week before last" { nu ~/.scripts/worklog/cli.nu logs-for week --offset -2 }
@example "get worklogs for the week of the 12th of current month and year" { nu ~/.scripts/worklog/cli.nu logs-for week 12 }
@example "get worklogs for the week of the 12th of may for current year" { nu ~/.scripts/worklog/cli.nu logs-for week 12 5 }
@example "get worklogs for the week of 12/05/2023" { nu ~/.scripts/worklog/cli.nu logs-for week 12 5 2023 }
@example "get worklogs for all saved projects in the current week" { nu ~/.scripts/worklog/cli.nu logs-for week --all-saved-projects }
@example "get worklogs for all saved projects in the current week" { nu ~/.scripts/worklog/cli.nu logs-for week -A }
@example "get worklogs for all saved projects in the last week" { nu ~/.scripts/worklog/cli.nu logs-for week --offset -1 --all-saved-projects }
@example "get worklogs for all saved projects in the week before last" { nu ~/.scripts/worklog/cli.nu logs-for week --offset -2 --all-saved-projects }
def 'main logs-for week' [
  day?: int
  month?: int
  year?: int
  --all-saved-projects (-A) # query logs from all saved projects instead of current project
  --offset (-o): int = 0
  --author (-a): string
  --no-split-week-on-month
  --projects-file (-p): string  # like --all, but specify path to file containing specific list of projects
] {
  let author = $author | if ($in | is-empty) { get-author-email } else { $in }
  let sdate = (datefrom $day $month $year) | start-of-week | $in + ($offset * 1wk)
  let edate = $sdate | end-of-week

  get-projects $projects_file --all $all_saved_projects
  | par-each { cd $in; list-git-logs-in-range $sdate $edate $author }
  | flatten
  | (
    fmt-logs-for-display $sdate $edate $author
      --group-weeks true
      --split-week-on-month (not $no_split_week_on_month)
  )
}

# Gets the worklogs for the specified month
@example "get worklogs for the current project in the current month" { nu ~/.scripts/worklog/cli.nu logs-for month }
@example "get worklogs for the current project for may" { nu ~/.scripts/worklog/cli.nu logs-for month 5 }
@example "get worklogs for the current project for may in 2023" { nu ~/.scripts/worklog/cli.nu logs-for month 5 2023 }
@example "get worklogs for all saved projects in the current logs-for month" { nu ~/.scripts/worklog/cli.nu logs month --all-saved-projects }
@example "get worklogs for all saved projects in the current logs-for month" { nu ~/.scripts/worklog/cli.nu logs month -A }
@example "get worklogs for all saved projects in may" { nu ~/.scripts/worklog/cli.nu logs logs-for month 5 --all-saved-projects }
@example "get worklogs for all saved projects in may in 2023" { nu ~/.scripts/worklog/cli.nu logs logs-for month 5 2023 --all-saved-projects }
def 'main logs-for month' [
  month?: int
  year?: int
  --all-saved-projects (-A) # query logs from all saved projects instead of current project
  --author (-a): string
  --projects-file (-p): string # like --all-saved-projects, but specify path to file containing specific list of projects
] {
  clear -k
  let date = (datefrom 10 $month $year)
  let sdate = $date | start-of-month
  let edate = $sdate | end-of-month
  let author = $author | if ($in | is-empty) { get-author-email } else { $in }

  get-projects $projects_file --all $all_saved_projects
  | par-each { cd $in; list-git-logs-in-range $sdate $edate $author }
  | flatten
  | (
    fmt-logs-for-display $sdate $edate $author
      --group-weeks true
      --split-week-on-month true
  )
}

# Gets the worklogs for the specified specified date range
@example "logs for current project between 2025-1-1 and 2025-5-1" { nu ~/.scripts/worklog/cli.nu logs-for date-range 2025-1-1 2025-5-1 }
@example "logs for all saved projects between 2025-1-1 and 2025-5-1" { nu ~/.scripts/worklog/cli.nu logs-for date-range 2025-1-1 2025-5-1 --all-saved-projects }
@example "logs for all saved projects between 2025-1-1 and 2025-5-1" { nu ~/.scripts/worklog/cli.nu logs-for date-range 2025-1-1 2025-5-1 -A }
def 'main logs-for date-range' [
  start: string
  end: string
  --all-saved-projects (-A) # query logs from all saved projects instead of current project
  --group-weeks # display a new section for each week
  --no-split-week-on-month
  --author (-a): string
  --projects-file (-p): string  # like --all-saved-projects, but specify path to file containing specific list of projects
] {
  clear -k
  let sdate = ($start | into datetime | start-of-day)
  let edate = ($end | into datetime | end-of-day)
  let author = $author | if ($in | is-empty) { get-author-email } else { $in }

  get-projects $projects_file --all $all_saved_projects
  | par-each { cd $in; list-git-logs-in-range $sdate $edate $author }
  | flatten
  | (
    fmt-logs-for-display $sdate $edate $author
      --group-weeks $group_weeks
      --split-week-on-month (not $no_split_week_on_month)
  ) | print $in
}
