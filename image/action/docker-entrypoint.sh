#!/bin/bash
declare -a render_manifest_args
render_manifest_args=("--app" "$INPUT_APP")

if [[ -n "${INPUT_PROJECT_DIR}" ]]; then
  render_manifest_args+=("--project-dir" "${INPUT_PROJECT_DIR}")
else
  render_manifest_args+=("--project-dir" "$GITHUB_WORKSPACE")
fi

if [[ -n "${INPUT_APP_DIR}" ]]; then
  render_manifest_args+=("--app-dir" "${INPUT_APP_DIR}")
fi

if [[ -n "${INPUT_OUT_DIR}" ]]; then
  render_manifest_args+=("--out-dir" "${INPUT_OUT_DIR}")
fi

if [[ -n "${INPUT_TARGETS}" ]]; then
  render_manifest_args+=("--targets" "${INPUT_TARGETS}")
fi

if [[ "${INPUT_DEBUG:-${ACTIONS_STEP_DEBUG:-${ACTIONS_RUNNER_DEBUG}}}" = "true" ]]; then
  render_manifest_args+=("--debug")
fi

if [[ "${INPUT_SKIP_DEPS}" = "true" ]]; then
  render_manifest_args+=("--skip-deps")
fi

if [[ "${INPUT_SKIP_CRDS}" = "true" ]]; then
  render_manifest_args+=("--skip-crds")
fi

if [[ "${INPUT_SYNC}" = "true" ]]; then
  render_manifest_args+=("--sync")
fi

exec /usr/local/bin/render-manifests.sh "${render_manifest_args[@]}"
