#!/bin/bash
# check-trailers.sh: an example of the provenance check in rule V3 of agent-git-guidelines.md.
# It checks that the P1 trailers survive a squash merge (rule B2), so the P6 audit query sees them.
#
# Usage:
#   check-trailers.sh pr <base> <head> <title> <body-file>
#     For a PR that will be squash-merged with the PR title and description as the message.
#     Fails when a commit in <base>..<head> carries an Assisted-by trailer and the final trailer block
#     of "<title>, blank line, description" does not carry the same Assisted-by value.
#     A PR with no agent commits passes.
#   check-trailers.sh landed <commit | base..head>
#     For commits already on the default branch. Fails when a commit message has an Assisted-by line
#     that Git does not parse as a trailer (for example because text follows the trailer block).
# Exit status: 0 when the check passes, 1 when it fails, 2 on a usage error.
# Tested by tests/verify-git-commands.sh.

set -u

usage() { echo "usage: $0 pr <base> <head> <title> <body-file> | landed <commit|base..head>" >&2; exit 2; }

agent_values() { # Assisted-by values of the trailer block in the message on stdin
  git interpret-trailers --parse | sed -n 's/^Assisted-by: *//p' | sort -u
}

case "${1:-}" in
  pr)
    [ $# -eq 5 ] || usage
    base=$2; head=$3; title=$4; body_file=$5
    [ -r "$body_file" ] || { echo "check-trailers: cannot read $body_file" >&2; exit 2; }
    needed=$(git log --format='%(trailers:key=Assisted-by,valueonly)' "$base..$head" | sed '/^$/d' | sort -u)
    [ -z "$needed" ] && { echo "check-trailers: no agent commits in this PR"; exit 0; }
    # Descriptions edited in a browser can use CRLF line ends, which would leave a carriage return in each value.
    found=$(printf '%s\n\n%s\n' "$title" "$(tr -d '\r' < "$body_file")" | agent_values)
    missing=$(comm -23 <(printf '%s\n' "$needed") <(printf '%s\n' "$found"))
    if [ -n "$missing" ]; then
      echo "check-trailers: the squash message would lose these Assisted-by trailers:" >&2
      printf '%s\n' "$missing" | sed 's/^/  /' >&2
      echo "Put the trailer block (Assisted-by:, Agent-Session:) as the last lines of the PR description, with nothing after it." >&2
      exit 1
    fi
    echo "check-trailers: squash message keeps Assisted-by: $(printf '%s\n' "$found" | paste -sd, -)"
    ;;
  landed)
    [ $# -eq 2 ] || usage
    case "$2" in
      *..*) commits=$(git rev-list "$2") ;;
      *)    commits=$(git rev-parse --verify -q "$2^{commit}") || usage ;;
    esac
    rc=0
    for c in $commits; do
      if git log -1 --format=%B "$c" | grep -q '^Assisted-by:' &&
         [ -z "$(git log -1 --format='%(trailers:key=Assisted-by,valueonly)' "$c")" ]; then
        echo "check-trailers: $(git log -1 --format='%h %s' "$c"): Assisted-by is in the message but not a trailer" >&2
        rc=1
      fi
    done
    [ $rc -eq 0 ] && echo "check-trailers: landed commits keep their Assisted-by trailers"
    exit $rc
    ;;
  *) usage ;;
esac
