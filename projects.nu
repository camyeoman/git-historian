use helpers.nu *

const SAVED_PROJECTS_FILE = "saved-projects.yml"

def get-saved-projects-path [] {
  $env.FILE_PWD | path join $SAVED_PROJECTS_FILE
}

export def get-author-email []: nothing -> string {
  ^git config --global --get user.email | str trim
}

def path-is-repository []: string -> bool {
  ($in | path join ".git" | path type) == "dir"
}

def process-project-paths []: list<string> -> list<string> {
  each { str trim | path expand }
  | where { path-is-repository }
  | sort
  | uniq
}

export def overwrite-saved-projects []: list<string> -> nothing {
  process-project-paths
  | to yaml
  | save -f (get-saved-projects-path)
}

export def save-projects []: list<string> -> nothing {
  let paths = $in
  get-saved-projects
  | append $paths
  | overwrite-saved-projects
}

export def get-saved-projects [] {
  (get-saved-projects-path)
  | if ($in | path exists) { open $in } else { [] }
  | process-project-paths
}

export def get-projects [
  filepath?: string
  --all = false
  --choose = false
]: nothing -> list<string> {
  if ($all) {
    get-saved-projects
  } else if ($filepath == null or not ($filepath | path exists)) {
    ["./"]
  } else if ($filepath | str ends-with ".txt") {
    open -r $filepath | lines
  } else {
    open $filepath
  }
  | if ($in | is-empty) { ["./"] } else { $in }
  | process-project-paths
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
