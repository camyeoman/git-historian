use ticket-codes.nu *
use metadata.nu *
use helpers *

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
  committer_date_r_f_c2822_style: "%cD"
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

export def get-author-email []: nothing -> string {
  ^git config --global --get user.email | str trim
}

def extract-ticket-code [body: string, ref: string]: nothing -> record {
  let ticket_regex = ($TICKET_FORMATS | str join "|" | $"\(?<ticket>($in)\)")
  let commit_regexes = [
    '^\s*(?<ticket>[A-Z]{2,}\-\d+)(\:| )\s*(?<message>.*)'
    $ticket_regex
  ]

  $body
    | find-first-match-of ...$commit_regexes
    | default ($ref | find-first-match-of $ticket_regex)
    | default ({ ticket: null })
    | upsert message { default $body }
}

def highlight-ticket-codes-in-message []: string -> string {
  $"(ansi grey)($in)(ansi reset)"
  | str replace -ar ($TICKET_FORMATS | str join "|") $'(ansi purple)$0(ansi grey)'
}

# implement functions to parse the git log

def list-git-logs-in-range [
  start_date: datetime
  end_date: datetime
  author: string
] {
  const LOG_FMT = [
    ["date", $FMT_TAG.author_date_strict_iso8601_format]
    ["hash", $FMT_TAG.commit_hash]
    ["ref", $FMT_TAG.ref_name]
    ["body", $FMT_TAG.raw_body_unwrapped_subject_and_body]
  ]

  let sdate = $start_date | start-of-day
  let edate = $end_date | end-of-day
  let fmt_string = ($LOG_FMT | each { get 1 } | str join "»¦«") + "¦»EOL«¦"

  (
    git log
      --format=$"($fmt_string)"
      --author=$"($author)"
      --after=$"($sdate | gdate)"
      --before=$"($edate | gdate)"
  ) | if ($in | is-empty) { [] } else {
    split row "¦»EOL«¦"
    | each { str trim }
    | where { is-not-empty }
    | each { str trim | split column "»¦«" ...($LOG_FMT | each { get 0 }) }
    | flatten
    | update date { into datetime -z LOCAL }
    | insert calendar-date { $in.date | format date '%a %d %B %Y' }
    | insert week { $in.date | get-week-number }
    | where date >= $sdate and date <= $edate
    | sort-by date
    | update body { |e| extract-ticket-code $e.body $e.ref }
    | flatten body
    | upsert message { default "" | str trim }
  }
}

def fmt-logs-for-display [
  author?: string
  --by-week
]: table -> any {
  # handle case where no commits are found
  if ($in | is-empty) {
    return ([
      "\n\n\n"
      ($"(ansi red)0 commits(ansi reset) found for user (ansi purple)($author | default '???')(ansi reset) in date range..."
        | fill -a c -w (term size | get columns))
      "\n\n\n"
    ] | str join "")
  }

  # handle case with valid input
  let twidth = (term size | get columns)
  $in
  | sort-by date
  | insert odate { $in.date | $"(ansi blue)($in | format date '%I:%M:%S %p')(ansi reset)" }
  | insert oticket { $in.ticket | default "???" | fill -w 17 -a c | $"(ansi purple)($in)(ansi reset)"  }
  | insert omessage { $in.message | truncate-string -c (ansi grey) -r 0.6 | highlight-ticket-codes-in-message }
  | insert output { $"($in.odate) ($in.oticket) ($in.omessage)" }
  | group-by week --to-table
  | sort-by week -r
  | each { ($in
    # get date range for the given week
    | insert sdate { get items.date | first | start-of-week | format date '%d %b' | $"(ansi green)($in)(ansi reset)" }
    | insert edate {
      [
        ($in | get items.date | first | end-of-week)
        ($in | get items.date | first | end-of-month)
      ] | math min | format date '%d %b' | $"(ansi green)($in)(ansi reset)"
    }

    # gets a list of subgroups where each subgroup contains all logs for each week
    | update items {
      # collect all the logs per day into a single string
      group-by calendar-date --to-table
      | sort-by { $in.calendar-date | into datetime }
      | update items {
        sort-by date
        | get output?
        | where { is-not-empty }
      }
      | insert header { $"## Worklogs for (ansi green)($in.calendar-date)(ansi reset)" }
      | each { [ $in.header, "", ...($in.items | each { " " + $in }), "" ] }
      | flatten
      | each { $in + (ansi reset) }
    }

    # if by week enabled then
    | if (not $by_week) { $in.items } else {
      insert header { $"# Worklogs for week of ($in.sdate) to ($in.edate)" }
      | each { [ $in.header, "", ...($in.items | each { " " + $in }) ] }
      | flatten
    }
  ) }
  | flatten
  | str join "\n"
  | $"\n($in | str trim)"
}
