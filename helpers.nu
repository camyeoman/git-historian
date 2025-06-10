export def --env tap [
  inspect?: closure,
  ...args: any
  --prefix (-p): string
]: any -> any {
  let input = $in
  match ($inspect) {
    null => (print $"($prefix)($input)")
    _ => ($input | do $inspect ...($args))
  }

  return $input
}

export def --env if-then [predicate: closure, action: closure]: any -> any {
  let input = $in
  match ($input | do $predicate) {
    true => ($input | do $action)
    false => ($input)
  }
}

export def --env if-not [predicate: closure, action: closure]: any -> any {
  let input = $in
  match ($input | do $predicate) {
    true => ($input)
    false => ($input | do $action)
  }
}

export def --env if-then-else [predicate: closure, if_true: closure, if_false]: any -> any {
  let input = $in
  match ($input | do $predicate) {
    true => ($input | do $if_true)
    false => ($input | do $if_false)
  }
}

export def truncate-string [
  --max-width (-w): number
  --ratio (-r): number = 1
  --color (-c): string = ""
]: string -> string {
  let content = $in | split row "\n" | get 0?
  let width = term size | get columns
  let length = $content | ansi strip | str length
  let limit = $max_width | default (
    $width * $ratio
      | math round
      | [0, $in]
      | math max
  )

  # handle case where input is below limit
  if ($length < $limit) { return $content }

  # handle case where input is too long
  $content | str substring -g 0..($limit - 3) | $"($in)($color)...(ansi reset)"
}

export def get-month []: datetime -> int {
  into record | get month
}

export def get-year []: datetime -> int {
  into record | get year
}

export def gdate []: datetime -> string {
  format date "%-Y/%-m/%-d %H:%M:%S"
}

export def get-weekday []: datetime -> int {
  format date '%u' | into int
}

export def datefrom [day?: int, month?: int, year?: int, timezone?: string]: nothing -> datetime {
  let now = (date now | into record)
  let d = $day | default $now.day
  let y = $year | default $now.year
  let m = $month | default $now.month
  $"($y)-($m)-($d)" | into datetime -z ($timezone | default $now.timezone)
}

export def start-of-month []: datetime -> datetime {
  let idate = $in
  let rdate = ($idate | into record)
  return (
    $idate
      - (1day * ($rdate.day - 1))
      - (1hr * $rdate.hour)
      - (1min * $rdate.minute)
      - (1sec * $rdate.second)
      - (1ns * $rdate.nanosecond)
  )
}

export def start-of-day []: datetime -> datetime {
  let idate = $in
  let rdate = ($idate | into record)
  return (
    $idate
      - (1hr * $rdate.hour)
      - (1min * $rdate.minute)
      - (1sec * $rdate.second)
      - (1ns * $rdate.nanosecond)
  )
}

export def end-of-day []: datetime -> datetime {
  let idate = $in
  let rdate = ($idate | into record)
  return (($idate | start-of-day) + 1day - 1sec)
}

export def end-of-month []: datetime -> datetime {
  let idate = $in
  let rdate = ($idate | into record)
  return (
    $idate
      | $in + ((40 - $rdate.day) * 1day)
      | start-of-month
      | $in - 1sec
  )
}

export def start-of-week []: datetime -> datetime {
  start-of-day
    | $in + ((1 - ($in | get-weekday)) * 1day)
}

export def end-of-week []: datetime -> datetime {
  start-of-week | $in - 1sec + 1wk
}

export def start-of-month-week []: datetime -> datetime {
  let month_start = $in | start-of-month
  $in | start-of-week | [$month_start, $in] | math max
}

export def end-of-month-week []: datetime -> datetime {
  let month_end = $in | end-of-month
  $in | end-of-week | [$month_end, $in] | math min
}

export def start-of-year []: datetime -> datetime {
  let idate = $in
  let rdate = ($idate | into record)
  return (datefrom 1 1 $rdate.year | start-of-day)
}

export def end-of-year []: datetime -> datetime {
  let idate = $in
  let rdate = ($idate | into record)
  return (datefrom 31 12 $rdate.year | end-of-day)
}

export def find-first-match-of [...expressions: string]: string -> record {
  let content = $in
  $expressions | reduce -f null { |regex|
    match ($in) {
      null => ($content | parse -r $regex | get 0?)
      _ => $in
    }
  }
}

export def get-week-number []: datetime -> int {
  let date = $in
  (date now | end-of-week) - ($date)
  | into record
  | $in.week?
  | default 0
  | math abs
}

export def get-author-email []: nothing -> string {
  ^git config --global --get user.email | str trim
}

export def get-current-project []: nothing -> string {
  ^git rev-parse --show-toplevel
}
