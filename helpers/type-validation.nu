export def is-record []: any -> bool {
  $in | describe | str starts-with "record"
}

export def is-not-record []: any -> bool {
  $in | is-record | not $in
}

export def key-matches [key: string, predicate: closure]: any -> bool {
  if ($in | is-not-record) { return false }
  ($key in ($in | columns)) and ($in | get $key | do $predicate)
}

export def is-record-of [conditions: record]: any -> bool {
  let cond_keys = $conditions | columns
  let input = $in
  let input_keys = $in | columns
  if ($cond_keys | any { $in not-in $input_keys }) { return false }

  $conditions
    | transpose key predicate
    | where key in $cond_keys
    | all { |item| $input | get $item.key | do $item.predicate }
}

export def is-null []: any -> bool {
  $in == null
}

export def is-not-null []: any -> bool {
  $in != null
}

export def is-nullish-record []: any -> bool {
  $in == null or ($in | is-record)
}

export def is-closure []: any -> bool {
  $in | describe | $in == "closure"
}

export def is-nullish-closure []: any -> bool {
  $in == null or ($in | is-closure)
}

export def is-list-like []: any -> bool {
  let datatype = $in | describe
  return (
    ($datatype | str starts-with "list") or
    ($datatype | str starts-with "table")
  )
}

export def is-string []: any -> bool {
  ($in | describe) == 'string'
}

export def is-not-string []: any -> bool {
  $in | is-string | not $in
}

export def is-non-empty-string []: any -> bool {
  ($in | is-string) and ($in | is-not-empty)
}

export def is-bool []: any -> bool {
  ($in | describe) == 'bool'
}

export def is-int []: any -> bool {
  ($in | describe) == 'int'
}

export def is-positive-int []: any -> bool {
  ($in | is-int) and ($in > 0)
}

export def is-negative-int []: any -> bool {
  ($in | is-int) and ($in < 0)
}

export def is-non-negative-int []: any -> bool {
  ($in | is-int) and ($in >= 0)
}

export def is-non-positive-int []: any -> bool {
  ($in | is-int) and ($in <= 0)
}

export def is-float []: any -> bool {
  ($in | describe) == 'float'
}

export def is-positive-float []: any -> bool {
  ($in | is-float) and ($in > 0)
}

export def is-negative-float []: any -> bool {
  ($in | is-float) and ($in < 0)
}

export def is-non-negative-float []: any -> bool {
  ($in | is-float) and ($in >= 0)
}

export def is-non-positive-float []: any -> bool {
  ($in | is-float) and ($in <= 0)
}

export def is-number []: any -> bool {
  ($in | is-int) or ($in | is-float)
}

export def is-positive-number []: any -> bool {
  ($in | is-number) and ($in > 0)
}

export def is-negative-number []: any -> bool {
  ($in | is-number) and ($in < 0)
}

export def is-non-negative-number []: any -> bool {
  ($in | is-number) and ($in >= 0)
}

export def is-non-positive-number []: any -> bool {
  ($in | is-number) and ($in <= 0)
}

const V4_UUID_REGEX = ([
  '^'
  '([0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12})'
  '|'
  '([0-9A-F]{8}-[0-9A-F]{4}-4[0-9A-F]{3}-[89ab][0-9A-F]{3}-[0-9A-F]{12})'
  '$'
] | str join '')

export def is-uuid []: any -> bool {
  ($in | is-string) and ($in =~ $V4_UUID_REGEX)
}

export def is-datetime []: any -> bool {
  $in | describe | $in == "datetime"
}
