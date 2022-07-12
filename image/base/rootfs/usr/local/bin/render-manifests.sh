#!/bin/bash
###
### render-manifests.sh - Render manifests for kubernetes deployments
###
### Usage:
###   render-manifests.sh [OPTIONS]
###
### Options:
###   -h | --help
###         This help
###   -a | --app NAME
###         The application to render manifests for
###   -t | --targets TARGET,TARGET,...
###         A target destination to render manifests for. If not set, renders for all destinations app is enabled in.
###   -y | --sync
###         Sync rendered manifests with manifests in repository
###   -A | --app-dir
###         Directory with application deployment configuration relative to project root. Defaults to `$project_root/apps/$app`
###   -O | --out-dir DIR
###         Directory to sync rendered manifests to relative to project root. Defaults to `$project_dir/apps/$app/deploy/releases`. Only used if `sync` is set.
###   --project-dir DIR
###         Root directory for the project. If not set will use git to determine.
###   --skip-deps
###         Skip updating helm dependencies (`helmfile deps`)
###   --skip-crds
###         Do not render CRDs
###   -d | --debug
###         Enable debug mode
source /usr/local/lib/script-utils.sh

script_name="render-manifests"
long_flags=(
  "app-dir:"
  "app:"
  "debug"
  "help"
  "out-dir:"
  "project-dir:"
  "skip-crds"
  "skip-deps"
  "sync"
  "targets:"
)
short_flags=(
  "a:"
  "A:"
  "d"
  "h"
  "n:"
  "O:"
  "t:"
  "y"
)

options=$(getopt -n "$script_name" \
  -o "$(join_by "" "${short_flags[@]}")" \
  --long "$(join_by "," "${long_flags[@]}")" \
  -- "$@")

if [[ $? != 0 ]]; then
  error_help "Failed parsing options."
fi

eval set -- "$options"

function get_targets_dir() {
  local -r app_dir="$1"
  realpath -qmsL "$app_dir/targets"
}

## Environment variables that will be set for helmfile tasks
function set_helmfile_environment() {
  local -r app="$1" target="$2" app_dir="$3"
  local targets_dir=""
  if [[ -n "$app_dir" ]]; then
    targets_dir="$(get_targets_dir "$app_dir")"
  fi

  HELMFILE_ENVIRONMENT=(
    PATH="$PATH"
    HOME="$HOME"
    USER="$USER"
    PWD="$PWD"
    APP_NAME="$app"
  )

  declare -a helm_env
  declare -a target_env

  mapfile -t helm_env < <(helm env 2>/dev/null | sed 's/"//g')
  HELMFILE_ENVIRONMENT+=("${helm_env[@]}")
  unset -v helm_env

  if [[ -n "$targets_dir" ]] && [[ -f "$targets_dir/$target.yaml" ]]; then
    mapfile -t target_env < <(yq e -o j <"$targets_dir/$target.yaml" \
    | jq -r '. as $in | reduce paths(scalars) as $path ({}; . + { ($path|join("#")|gsub("[^\\w]+";"_")|ascii_upcase): $in | getpath($path) }) | keys[] as $k | "\($k)=\(.[$k]|@text)"' 2>/dev/null)
    HELMFILE_ENVIRONMENT+=("${target_env[@]}")
  elif [[ -n "$targets_dir" ]] && [[ -f "$targets_dir/$target.json" ]]; then
    mapfile -t target_env < <(yq e -o j <"$targets_dir/$target.json" \
    | jq -r '. as $in | reduce paths(scalars) as $path ({}; . + { ($path|join("#")|gsub("[^\\w]+";"_")|ascii_upcase): $in | getpath($path) }) | keys[] as $k | "\($k)=\(.[$k]|@text)"' 2>/dev/null)
    HELMFILE_ENVIRONMENT+=("${target_env[@]}")
  fi
  unset -v target_env

  if [[ "$RENDER_MANIFEST_DEBUG" = "true" ]]; then
    echo "--> Environment for helmfile execution"
    env -i "${HELMFILE_ENVIRONMENT[@]}" sh -c \
      'printenv | sort \
        | sed "s/\(.*\)\(PASS\|PASSWORD\|TOKEN\|KEY\)=.*/\1\2=******/g"'
  fi
}

function build_helmfile_args() {
  local -n arr=$1
  shift
  [[ "$RENDER_MANIFEST_DEBUG" = "true" ]] && arr+=('--debug')
  arr+=("$@")
}

## Run helmfile repos and helmfile deps
function helm_dependency_update() {
  local -r app="$1" skip_deps="$2"
  shift 2
  local -a environment=("${@:-"${HELMFILE_ENVIRONMENT[@]}"}")

  echo "--> Updating helm repos for $app (helmfile repos)"
  helmfile_args=()
  build_helmfile_args helmfile_args 'repos'
  env -i "${environment[@]}" \
    helmfile "${helmfile_args[@]}" || true

  if [[ "$skip_deps" = "false" ]]; then
    echo "--> Updating helm dependencies for $app (helmfile deps)"
    helmfile_args=()
    build_helmfile_args helmfile_args 'deps' '--skip-repos'
    env -i "${environment[@]}" \
      helmfile "${helmfile_args[@]}" || true
  fi
}

function set_render_targets() {
  local -r app_dir="$1"
  local -r targets_dir="$(get_targets_dir "$app_dir")"

  RENDER_TARGETS=()
  shopt -s nullglob
  for t in "$targets_dir"/*.{yaml,json}; do
    local base
    base="$(basename "$t")"
    RENDER_TARGETS+=("${base%.*}")
  done
  shopt -u nullglob
}

function render_manifests() {
  local -r app="$1" target="$2" \
    app_dir="$3" out_dir="$4" \
    do_rsync_manifests="$5" skip_crds="$6"
  local tmpdir="${TMPDIR:-"/tmp"}/render-$app-$target.$GIT_HEAD_SHA"

  if [[ "$CI" = "true" ]]; then
    tmpdir="$(mktemp -q -d || echo "$tmpdir")"
    [[ -d "$tmpdir" ]] || mkdir -p "$tmpdir"
  else
    mkdir -p "$tmpdir" || true
  fi

  trap 'popd >/dev/null 2>&1; trap - RETURN' RETURN
  pushd "$app_dir" >/dev/null 2>&1 || return 1

  ## Environment variables that will be set for helmfile tasks
  set_helmfile_environment "$app" "$target" "$app_dir"

  ## Generate the manifests
  ## `--skip-deps` is required if `--include-crds` is set
  echo "--> Rendering manifests for $app@$target (helmfile template)"
  helmfile_args=()
  build_helmfile_args helmfile_args \
    'template' \
    '--concurrency=2' \
    '--skip-deps' \
    "--output-dir=$tmpdir" \
    '--output-dir-template={{ .OutputDir }}/deploy/{{ .Release.Name }}'
  [[ "$skip_crds" = "false" ]] && helmfile_args+=('--args=--include-crds')
  retry 3 \
    env -i "${HELMFILE_ENVIRONMENT[@]}" \
    helmfile "${helmfile_args[@]}"
  helmfile_template_status=$?

  if [[ $helmfile_template_status -eq 0 ]]; then

    find "$tmpdir/deploy" -type d -name tests -exec rm -rf '{}' +
    echo "--> Manifests rendered under directory $tmpdir"

    if [[ "$do_rsync_manifests" = "true" ]]; then
      echo "--> Copying manifests to $out_dir"
      mkdir -vp "$out_dir"
      rsync -h --progress --recursive --checksum --delete-during \
        "$tmpdir/deploy/" "$out_dir"
    fi
    true
  else
    false
  fi
}

do_rsync_manifests=false
skip_deps="false"
skip_crds="false"
unset app
unset -v RENDER_TARGETS

while true; do
  case "$1" in
  -a | --app)
    app="$2"
    shift 2
    ;;
  -y | --sync)
    do_rsync_manifests=true
    shift
    ;;
  -t | --targets)
    declare -a RENDER_TARGETS
    IFS="," read -r -a RENDER_TARGETS <<<"$2"
    shift 2
    ;;
  -d | --debug)
    export RENDER_MANIFEST_DEBUG=true
    shift
    ;;
  -A | --app-dir)
    app_dir="$2"
    shift 2
    ;;
  -O | --out-dir)
    out_dir="$2"
    shift 2
    ;;
  --project-dir)
    project_dir="$2"
    shift 2
    ;;
  --skip-deps)
    skip_deps="true"
    shift
    ;;
  --skip-crds)
    skip_crds="true"
    shift
    ;;

  -h | --help)
    help
    exit 0
    ;;
  --)
    shift
    break
    ;;
  "") break ;;
  *) error_help "Invalid option: $1" ;;
  esac
done

## Gets the absolute path for the root directory of the project
## When running in the github actions context, \$GITHUB_WORKSPACE will be set to the absolute path to the project root.
PROJECT_DIR="$(realpath -qsL "${project_dir:-"${GITHUB_WORKSPACE:-"$(git rev-parse --show-toplevel)"}"}")"
cd "$PROJECT_DIR" >/dev/null 2>&1 || exit 1

## Current commit
GIT_HEAD_SHA="$(git rev-parse --short=8 HEAD)"

export PROJECT_DIR GIT_HEAD_SHA

## Enable debug if in github CI and debug is enabled
if [[ "$CI" = "true" ]] && [ "$ACTIONS_RUNNER_DEBUG" = "true" ] || [ "$ACTIONS_STEP_DEBUG" = "true" ]; then
  export RENDER_MANIFEST_DEBUG="true"
fi

app_dir="$(realpath -qmsL "${app_dir:-"$PROJECT_DIR/apps/$app"}")"
[[ -d "$app_dir" ]] || error_help "Application directory not found: $app_dir"

pushd "$app_dir" &>/dev/null || exit 1

## Set initial helmfile environment
set_helmfile_environment "$app"

## Do helm repo and dependency setup once to avoid helm repository rate limiting
helm_dependency_update "$app" "$skip_deps" "${HELMFILE_ENVIRONMENT[@]}"

popd &>/dev/null || exit 1

## If a cluster has been passed in, render manifests for that cluster only, else
## loop through all clusters, if the app is enabled for that cluster, then render manifests
## optionally delete rendered manifests if app is disabled
[[ ${#RENDER_TARGETS[@]} -eq 0 ]] && set_render_targets "$app_dir"
declare -a rendered
for target in "${RENDER_TARGETS[@]}"; do
  echo
  echo "--> Running for ${app}@${target}"

  render_manifests "$app" "$target" \
    "$app_dir" \
    "$(realpath -qmsL "${out_dir:-"$app_dir/deploy/$target/releases"}")" \
    "$do_rsync_manifests" \
    "$skip_crds"
  render_manifest_status=$?

  if [[ $render_manifest_status -ne 0 ]]; then
    error_exit "helmfile template failed: error_code=$render_manifest_status" $render_manifest_status
  fi

  pushd "$app_dir" 2>/dev/null || exit
  releases="$(helmfile list --output json | jq -r '[ .[] | "\(.name)=\(.version)" ] | join(",")')"
  rendered+=("${app}@${target}/${releases}")
  popd 2>/dev/null || exit
  echo
done

# shellcheck disable=SC2068
echo "::set-output name=rendered::$(join_by ";" ${rendered[@]})"
