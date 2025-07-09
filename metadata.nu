use helpers *

# implement helpers to interact with project metadata

const METADATA_FILE = "metadata.yml"

def get-metadata-path [] {
  $env.FILE_PWD | path join $METADATA_FILE
}

def is-valid-saved-project-path []: any -> bool {
  ($in | is-string) and ($in | is-git-repository)
}

def format-saved-projects []: any -> list<string> {
  default []
  | where { is-valid-saved-project-path }
  | sort
  | uniq
}

def parse-date-if-not-null []: any -> list<string> {
  default null
  | if-then {is-not-null} {into datetime}
}

def format-metadata []: any -> record {
  $in
  | default {}
  | upsert last_pull { parse-date-if-not-null }
  | upsert saved_projects { format-saved-projects }
}

def get-metadata []: nothing -> record {
  let metapath = (get-metadata-path)
  if ($metapath | path exists | not $in) {
    return ({} | format-metadata)
  }

  open $metapath | format-metadata
}

def save-metadata []: record -> record {
  let new_metadata = $in | format-metadata
  $new_metadata
  | to yml
  | save -f (get-metadata-path)
  return $new_metadata
}

def update-metadata [update: closure]: nothing -> record {
  get-metadata
  | do $update
  | save-metadata
}

def get-saved-projects []: nothing -> list<string> {
  get-metadata
  | get saved_projects
}

def update-saved-projects [update: closure]: nothing -> list<string> {
  update-metadata { update save_projects $update }
  | get saved_projects
}

# implement methods to pull updates from the git repository

const PULL_INTERVAL = 1wk

export def update-program []: nothing -> bool {
  let meta = get-metadata
  if (
    ($meta.last_pull | is-datetime)
    and (date now) - $meta.last_pull < $PULL_INTERVAL
  ) { return false } # exit if already checked for updates

  cd $env.FILE_PWD # cd into correct directory

  clear -k; print (
    $"(ansi purple)Updating(ansi reset) program automatically..."
    | fill --width (term size).columns -a c
    | "\n" + $in + "\n"
  )

  # pull the latest changes, storing the date of the last pull
  let pulled = try {
    git pull | ignore
    update-metadata { upsert last_pull (date now) }
    true
  } catch { |error| false }

  print (
    $"(ansi green)Finished(ansi reset) updating program automatically!"
    | fill --width (term size).columns -a c
    | $in + "\n"
  )

  sleep 2sec; clear -k
  return $pulled
}

# implement methods to handle saved project paths

export def overwrite-saved-projects []: list<string> -> list<string> {
  let new_paths = $in
  update-saved-projects { $new_paths }
}

export def save-projects []: list<string> -> list<string> {
  let paths = $in
  update-saved-projects { append $paths }
}

export def get-projects [
  filepath?: string
  --all = false
  --choose = false
]: nothing -> list<string> {
  if ($all) {
    get-saved-projects
  } else if ($filepath == null or not ($filepath | path exists)) {
    [(get-current-project)]
  } else if ($filepath | str ends-with ".txt") {
    open -r $filepath | lines
  } else {
    open $filepath
  }
  | if ($in | is-empty) { ["./"] } else { $in }
  | where { is-git-repository }
}

def list-refs []: string -> table<refname: string, last_commit_at: datetime> {
  let refprefix = $in
  git for-each-ref --format="%(refname)»¦«%(creatordate)" $in
  | lines
  | split column "»¦«" refname last_commit_at
  | update refname { str replace -r $"^($refprefix)" "" }
  | flatten
  | update last_commit_at { into datetime }
}

export def list-all-branches [start_date: datetime] {
  ['refs/remotes/', "refs/heads/"]
  | par-each { list-refs }
  | flatten
  | where last_commit_at >= $start_date
  | get refname
}

export def get-author-email []: nothing -> string {
  ^git config --global --get user.email | str trim
}
