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

export def --env if-then-else [predicate: closure, if_true: closure, if_false: any]: any -> any {
  let input = $in
  match ($input | do $predicate) {
     true => ($input | do $if_true)
    false => (match ($if_false | describe) {
      "closure" => ($input | do $if_false)
              _ => $if_false
    })
  }
}

export def --env nullable [predicate: closure, ...args: any]: any -> bool {
  ($in == null) or ($in | do $predicate ...($args))
}

export def --env fn-any [...predicates: closure]: any -> bool {
  let input = $in
  $predicates | reduce -f false { |predicate, truth|
    $truth or ($input | do $predicate)
  }
}

export def --env fn-all [...predicates: closure]: any -> bool {
  let input = $in
  $predicates | reduce -f true { |predicate, truth|
    $truth and ($input | do $predicate)
  }
}

export def --env fn-none [...predicates: closure]: any -> bool {
  let input = $in
  $predicates | reduce -f true { |predicate, truth|
    $truth and ($input | do $predicate | not $in)
  }
}

export def --env map-values [mapping: closure]: record -> record {
  transpose key value
    | update value $mapping
    | transpose -ird
}

export def --env map-keys [mapping: closure]: record -> record {
  transpose key value
    | update key $mapping
    | transpose -ird
}

export def --env filter-values [predicate: closure]: record -> record {
  transpose key value
    | where { get value | do $predicate }
    | transpose -ird
}

export def --env filter-keys [predicate: closure]: record -> record {
  transpose key value
    | where { get key | do $predicate }
    | transpose -ird
}

export def --env is-record-of [conditions: record]: any -> bool {
  let cond_keys = $conditions | columns
  let input = $in
  let input_keys = $in | columns
  if ($cond_keys | any { $in not-in $input_keys }) { return false }

  $conditions
    | transpose key predicate
    | where key in $cond_keys
    | all { |item| $input | get $item.key | do $item.predicate }
}

export def safe-get [index: int, mapIfNotNull?: closure] {
  if ($index < 0 or $index >= ($in | length)) { return null }
  $in
  | get $index
  | match ($mapIfNotNull) { null => { $in }, _ => $mapIfNotNull }
}

def cmp [a: any, b: any]: nothing -> int {
  if ($a == $b) { return 0 }
  if ($a > $b) { return 1 }
  return (-1)
}

export def --env binary-search [
  pk: any          # T
  get_pk?: closure # { ||: T -> string | number }
]: list<any> -> int {
  def recurse [items: list<any>, lower: int, upper: int] {
    # handle base case when recursion is invalid
    if ($lower > $upper) { return (-1) }

    # get current middle index of array
    let mid = match ($lower == $upper) {
      true => $lower,
      false => ((($upper - $lower) / 2 | math floor) + $lower)
    }

    # handle base case where item being searched for is found
    let item_at_mid = $items | get $mid
    let pk_at_mid = $item_at_mid | do ($get_pk | default { $in })
    if ($pk_at_mid == $pk) { return $mid }

    # if no match at current, element not in array
    if ($lower == $upper) { return (-1) }

    # handle recursion
    # lll rrr | lll rrrr
    # L  M  U | L  M   U
    # 0123456 | 01234567
    # ------- | --------
    match (cmp $pk $pk_at_mid) {
      -1 => (recurse $items $lower ($mid - 1))
       0 => (-1)
       1 => (recurse $items ($mid + 1) $upper)
    }
  }

  let items = $in
  let num_of_items = $items | length
  return (recurse $items 0 ($num_of_items - 1))
}

def sort-helper [should_sort: bool, sort_using?: closure]: nothing -> closure {
  match ($should_sort) {
    false => {|| $in}
    true => (match ($sort_using) {
      null => {|| sort}
       _   => {|| sort-by $sort_using}
    })
  }
}

export def --env bsearch [
  key: any,
  get_key?: closure
  --already-sorted (-A)
] {
  # do regular search for small inputs
  if (($in | length) < 25) {
    skip until {
      match ($get_key) {
        null => ($in == $key)
        _ => (($in | do $get_key) == $key)
      }
    } | first 1 | get 0?
  }

  # use binary search for larger inputs
  $in
  | do (sort-helper (not $already_sorted) $get_key)
  | safe-get ($in | binary-search $key $get_key)
}

export def --env into-lookup-fn [
  get_key?: closure
  --already-sorted (-A)
]: list -> closure {
  let items = $in | do (sort-helper (not $already_sorted) $get_key)
  return { ||
    let key = $in
    $items | bsearch $key $get_key -A
  }
}

export def --env contains [
  key: any
  get_key: closure
  --already-sorted (-A)
]: list -> any {
  # do regular search for small inputs
  if (($in | length) < 25) {
    match ($get_key) {
      null => { $in }
       _   => { $in | each $get_key }
    } | any { $in == $key }
  }

  # use binary search for larger inputs
  $in
  | do (sort-helper (not $already_sorted) $get_key)
  | binary-search $key $get_key
  | $in >= 0
}

export def --env into-contains-fn [
  get_key?: closure
  --already-sorted (-A)
]: list -> closure {
  let items = $in | do (sort-helper (not $already_sorted) $get_key)
  return { ||
    let key = $in
    $items | contains -A $key $get_key
  }
}

export def --env into-not-contains-fn [
  get_key?: closure
  --already-sorted (-A)
]: list -> closure {
  let items = $in | do (sort-helper (not $already_sorted) $get_key)
  return { ||
    let key = $in
    $items | contains -A $key $get_key | not $in
  }
}

def wrap-diff-lists [
  by: any
  collections: list
  already_sorted: bool
  action: closure
] {
  match ($already_sorted) {
    false => { diff-lists --by $by ($in) ($collections | flatten) $action }
    true => { diff-lists -A --by $by ($in) ($collections | flatten) $action }
  }
}

export def --env difference [
  ...collections: any
  --by: closure
  --already-sorted (-A)
]: list -> list {
  wrap-diff-lists $by $collections $already_sorted { |a, b|
    if ($a != null and $b == null) { return $a }
    return null
  }
}

export def --env intersection [
  ...collections: any
  --by: closure
  --already-sorted (-A)
]: list -> list {
  wrap-diff-lists $by $collections $already_sorted { |a, b|
    if ($a != null and $b != null) { return $a }
    return null
  }
}

export def --env union [
  ...collections: any
  --by: closure
  --already-sorted (-A)
]: list -> list {
  wrap-diff-lists $by $collections $already_sorted { |a, b|
    $a | default $b
  }
}

export def diff-lists [
  a: list
  b: list
  action?: closure
  --by: closure
  --already-sorted (-A)
]: nothing -> list {
  def get-index [index: int]: list -> any {
    if ($index < 0 or $index >= ($in | length)) { return null }
    let item = $in | get $index
    return {
      item: $item,
      key: (if ($by == null) { $item } else { $item | do $by })
    }
  }

  # sort the two lists by the specified key, filtering out nullish keys
  let iterate_action = $action | default { |a, b| { a: $a, b: $b } }
  let sort_items = sort-helper (not $already_sorted) ($by)
  let la = $a | where { $in != null } | do $sort_items
  let lb = $b | where { $in != null } | do $sort_items
  let la_length = $la | length
  let lb_length = $lb | length

  # define iteration of function
  def iterate [ia: int, ib: int] {
    if ($ia >= $la_length and $ib >= $lb_length) { return { next: null } }
    let item_a = $la | get-index $ia
    let item_b = $lb | get-index $ib

    let comparison = match ($ia < $la_length and $ib < $lb_length) {
      true => (cmp $item_a.key $item_b.key) # if items remaining in both la and lb
      false => (match ($ib >= $lb_length) {
        true => -1 # if no items left in b, take from a
        false => 1 # if no items left in b, take from b
      })
    }

    return {
      out: (match ($comparison) {
        -1 => (do $iterate_action $item_a.item     null    )
        0 =>  (do $iterate_action $item_a.item $item_b.item)
        +1 => (do $iterate_action     null     $item_b.item)
      }),
      next: (match ($comparison) {
        -1 => { a: ($ia + 1), b: ($ib + 0) },
         0 => { a: ($ia + 1), b: ($ib + 1) },
         1 => { a: ($ia + 0), b: ($ib + 1) },
      })
    }
  }

  let generator_fn = { |i| if ($i != null) { iterate $i.a $i.b } }
  generate $generator_fn { a: 0, b: 0 } | where { $in != null }
}
