#!/usr/bin/env bash
set -euo pipefail

# ---- Safe initializations for Bash 3.2 + `set -u` ----
COMMAND=""
declare -a CMD_ARGS=()
declare -a HELM_VALUES=()
declare -a HELM_SET=()
declare -a HELM_EXTRA=()

# Optional context flags as strings (empty if not set)
KCTX=""
HCTX=""

# ========================
# Defaults (env overridable)
# ========================
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-mdai}"
KIND_CONFIG="${KIND_CONFIG:-}"
NAMESPACE="${NAMESPACE:-mdai}"                  # app namespace for kubectl applies
CHART_NAMESPACE="${CHART_NAMESPACE:-}"          # helm namespace (defaults to NAMESPACE if empty)

HELM_REPO_URL="${HELM_REPO_URL:-https://charts.mydecisive.ai}"
HELM_CHART_NAME="${HELM_CHART_NAME:-mdai-hub}"
# Leave empty "" to omit --version; we’ll add --devel in that case
HELM_CHART_VERSION="${HELM_CHART_VERSION:-}"
HELM_CHART_REF="${HELM_CHART_REF:-oci://ghcr.io/decisiveai/mdai-hub}"
HELM_RELEASE_NAME="${HELM_RELEASE_NAME:-mdai}"  # helm release name

CERT_MANAGER_URL="${CERT_MANAGER_URL:-https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml}"
KUBECTL_WAIT_TIMEOUT="${KUBECTL_WAIT_TIMEOUT:-180s}"
KUBE_CONTEXT="${KUBE_CONTEXT:-}"               # --kube-context

# Paths (env overridable)
SYN_PATH="${SYN_PATH:-./synthetics}"
OTEL_PATH="${OTEL_PATH:-./otel}"
MDAI_PATH="${MDAI_PATH:-./mdai}"
USE_CASES_ROOT="${USE_CASES_ROOT:-.}"          # root that contains versioned /use_cases trees

# Usage variables
HELP_EXAMPLES_FILE="${HELP_EXAMPLES_FILE:-./cli/examples.md}"
HELP_EXAMPLES_LINES="${HELP_EXAMPLES_LINES:-40}"

# Behavior flags
DRY_RUN=false
VERBOSE=false
INSTALL_CERT_MANAGER=true

# ==============
# Log helpers
# ==============
log() { echo -e "$*"; }
info() { log "👉 $*"; }
ok()   { log "✅ $*"; }
warn() { log "⚠️  $*"; }
err()  { log "❌ $*" >&2; }

# ==============
# Helpers funcs
# ==============
run() {
  if "$DRY_RUN"; then
    echo "+ $*"
    return 0
  fi
  if "$VERBOSE"; then
    echo "+ $*"
    eval "$@"
    return $?
  fi
  # Quiet attempt; if it fails, rerun loudly so you can see the error
  if eval "$@" >/dev/null 2>&1; then
    return 0
  else
    echo "+ $*"
    eval "$@"
    return $?
  fi
}

ensure_cmd() { command -v "$1" >/dev/null 2>&1 || { err "Required command '$1' not found."; exit 1; }; }
ensure_file() { [[ -f "$1" ]] || { err "File not found: $1"; exit 1; }; }
add_values() { HELM_VALUES+=("--values" "$1"); }
add_set()    { HELM_SET+=("--set" "$1"); }
add_extra()  { HELM_EXTRA+=("$1"); }

# Resolve a default manifest path, using versioned directory if available.
# Usage: default_file <root_dir> <version> <relative_path_or_filename>
default_file() {
  local root="$1" version="$2" rel="$3"
  if [[ -n "$version" && -f "$root/$version/$rel" ]]; then
    printf "%s\n" "$root/$version/$rel"
  elif [[ -f "$root/$rel" ]]; then
    printf "%s\n" "$root/$rel"
  else
    # Return the versioned path (likely not found) so caller can decide what to do.
    printf "%s\n" "$root/${version:+$version/}$rel"
  fi
}

# Return the first file that exists; otherwise return the first candidate (caller decides what to do)
first_existing() {
  local cand
  for cand in "$@"; do
    if [[ -n "$cand" && -f "$cand" ]]; then
      printf "%s\n" "$cand"
      return 0
    fi
  done
  printf "%s\n" "${1:-}"   # nothing existed; return the first candidate
}

# Apply the Helm --set flags needed when cert-manager is not used
apply_no_cert_manager_sets() {
  add_set "opentelemetry-operator.admissionWebhooks.certManager.enabled=false"
  add_set "opentelemetry-operator.admissionWebhooks.autoGenerateCert.enabled=true"
  add_set "opentelemetry-operator.admissionWebhooks.autoGenerateCert.recreate=true"
  add_set "opentelemetry-operator.admissionWebhooks.autoGenerateCert.certPeriodDays=365"

  add_set "mdai-operator.admissionWebhooks.certManager.enabled=false"
  add_set "mdai-operator.admissionWebhooks.autoGenerateCert.enabled=true"
  add_set "mdai-operator.admissionWebhooks.autoGenerateCert.recreate=true"
  add_set "mdai-operator.admissionWebhooks.autoGenerateCert.certPeriodDays=365"

  # These are already added by act_install_mdai_stack, so you can omit them here.
  # Keeping them is harmless (duplicates of identical --set are OK).
  # add_set "mdai-operator.manager.env.otelSdkDisabled=true"
  # add_set "mdai-gateway.otelSdkDisabled=true"
  # add_set "mdai-s3-logs-reader.enabled=false"
}


# ==============
# Kubernetes helpers
# ==============
k_apply() {
  local f="$1"
  ensure_file "$f"
  if "$DRY_RUN"; then
    echo "+ kubectl $KCTX apply -f $f -n ${NAMESPACE}"
  else
    kubectl $KCTX apply -f "$f" -n "${NAMESPACE}"
  fi
}

k_delete() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    warn "Delete skipped; file not found: $f"
    return 0
  fi
  if "$DRY_RUN"; then
    echo "+ kubectl $KCTX delete -f $f -n ${NAMESPACE}"
  else
    kubectl $KCTX delete -f "$f" -n "${NAMESPACE}"
  fi
}

k_wait_label_ready() {
  local selector="$1" ns="${2:-$NAMESPACE}" timeout="${3:-$KUBECTL_WAIT_TIMEOUT}"
  if "$DRY_RUN"; then
    echo "+ kubectl $KCTX wait --for=condition=Ready pod -l $selector -n $ns --timeout=$timeout"
  else
    kubectl $KCTX wait --for=condition=Ready pod -l "$selector" -n "$ns" --timeout="$timeout"
  fi
}

ns_ensure() {
  if ! kubectl $KCTX get ns "${NAMESPACE}" >/dev/null 2>&1; then
    info "Creating namespace '${NAMESPACE}'..."
    run "kubectl $KCTX create namespace ${NAMESPACE}"
  fi
}

# ==============
# Helm helpers
# ==============
helm_ns() {
  if [[ -n "$CHART_NAMESPACE" ]]; then echo "$CHART_NAMESPACE"; else echo "$NAMESPACE"; fi
}

# Render a pretty multi-line Helm command for logs (not used at runtime, handy for copy/paste)
pretty_helm_cmd() {
  local rel="$1" chart="$2" ns="$3" version_flag="$4" devel_flag="$5"
  local repo_args="$6" vflags="$7" sflags="$8" xflags="$9"
  printf 'helm upgrade --install \\\n'
  printf '  %s %s \\\n' "$rel" "$chart"
  if [[ -n "$repo_args" ]]; then
    printf '  %s \\\n' "$repo_args"
  fi
  printf '  --namespace %s \\\n' "$ns"
  printf '  --create-namespace \\\n'
  if [[ -n "$version_flag" ]]; then
    printf '  %s \\\n' "$version_flag"
  fi
  if [[ -n "$vflags" ]]; then
    printf '  %s \\\n' "$vflags"
  fi
  if [[ -n "$sflags" ]]; then
    printf '  %s \\\n' "$sflags"
  fi
  if [[ -n "$xflags" ]]; then
    printf '  %s \\\n' "$xflags"
  fi
  printf '  --cleanup-on-fail'
  if [[ -n "$devel_flag" ]]; then
    printf ' \\\n  %s' "$devel_flag"
  fi
  printf '\n'
}

helm_install_or_upgrade_mdai() {
  local rel="${HELM_RELEASE_NAME}"
  local ns; ns="$(helm_ns)"

  # Decide chart source and optional repo flag (avoid arrays for Bash 3.2 + set -u)
  local chart_arg repo_part=""
  if [[ -n "$HELM_CHART_REF" ]]; then
    chart_arg="${HELM_CHART_REF}"            # e.g., oci://ghcr.io/decisiveai/mdai-hub
  else
    chart_arg="${HELM_CHART_NAME}"           # e.g., mdai-hub
    repo_part="--repo ${HELM_REPO_URL}"      # e.g., https://charts.mydecisive.ai
  fi

  # Optional flags (safe flatten)
  local vflags="${HELM_VALUES[*]:-}"
  local sflags="${HELM_SET[*]:-}"
  local xflags="${HELM_EXTRA[*]:-}"

  # Version/devel handling
  local version_part="" devel_part=""
  if [[ -n "${HELM_CHART_VERSION:-}" ]]; then
    version_part="--version ${HELM_CHART_VERSION}"
    devel_part=""   # don’t add --devel if version is pinned
  else
    version_part="" # omit --version entirely
    devel_part="--devel"
  fi

  # Build and show the exact Helm command
  local cmd="helm $HCTX upgrade --install \
${rel} ${chart_arg} ${repo_part} \
--namespace ${ns} \
--create-namespace \
${version_part} \
${vflags} ${sflags} ${xflags} \
--cleanup-on-fail ${devel_part}"

  info "Helm command:"
  echo "$(echo "$cmd" | tr -s ' ')"

  if ! run "$cmd"; then
    err "Helm install/upgrade failed for release '${rel}' in namespace '${ns}'."
    return 1
  fi

  run "helm $HCTX status ${rel} -n ${ns}"
}

helm_get_values_json() {
  local rel="${HELM_RELEASE_NAME}" ns
  ns="$(helm_ns)"
  helm $HCTX get values "$rel" -n "$ns" -o json 2>/dev/null || echo "{}"
}

# ========================
# Actions (small, task-oriented)
# ========================
act_check_tools() {
  ensure_cmd docker
  ensure_cmd kind
  ensure_cmd kubectl
  ensure_cmd helm
  docker info >/dev/null 2>&1 || { err "Docker is not running."; exit 1; }
  ok "Prerequisites OK"
}

act_create_or_reuse_kind() {
  if kind get clusters 2>/dev/null | grep -q "^${KIND_CLUSTER_NAME}\$"; then
    info "Kind cluster '${KIND_CLUSTER_NAME}' already exists."
  else
    info "Creating Kind cluster '${KIND_CLUSTER_NAME}'..."
    if [[ -n "$KIND_CONFIG" ]]; then
      ensure_file "$KIND_CONFIG"
      run "kind create cluster --name ${KIND_CLUSTER_NAME} --config ${KIND_CONFIG}"
    else
      run "kind create cluster -q --name ${KIND_CLUSTER_NAME}"
    fi
  fi
}

act_install_cert_manager() {
  info "Installing cert-manager..."
  if "$DRY_RUN"; then
    echo "+ kubectl $KCTX apply -f ${CERT_MANAGER_URL}"
  else
    kubectl $KCTX apply -f "${CERT_MANAGER_URL}" || warn "cert-manager: apply failed"
  fi

  info "Waiting for cert-manager CRDs..."
  run "kubectl $KCTX wait --for=condition=Established crd/certificates.cert-manager.io --timeout=60s" || warn "CRD not ready"

  info "Waiting for cert-manager Deployments..."
  run "kubectl $KCTX wait --for=condition=Available deploy -l app.kubernetes.io/name=cert-manager -n cert-manager --timeout=180s" || warn "deploy not available"

  info "Waiting for cert-manager Pods..."
  run "kubectl $KCTX wait --for=condition=Ready pod -l app.kubernetes.io/name=cert-manager -n cert-manager --timeout=180s" || warn "pods not ready"

  info "Waiting for cert-manager webhook..."
  run "kubectl $KCTX wait --for=condition=Ready pod -l app.kubernetes.io/name=webhook -n cert-manager --timeout=120s" || warn "webhook not ready"
  ok "cert-manager ready (or skipped warnings)."
}

act_wait_mdai_ready() {
  info "Waiting for mdai-operator..."

  # Only wait if there are any pods matching the selector; otherwise warn clearly.
  if kubectl $KCTX get pods -n "mdai" -l app.kubernetes.io/name=mdai-operator -o name 2>/dev/null | grep -q .; then
    k_wait_label_ready "app.kubernetes.io/name=mdai-operator" "mdai" "120s" || warn "mdai-operator not ready"
  else
    warn "No mdai-operator pods found in namespace 'mdai'. Did the Helm install succeed?"
  fi

  info "Waiting for all pods in '${NAMESPACE}'..."
  if kubectl $KCTX get pods -n "${NAMESPACE}" -o name 2>/dev/null | grep -q .; then
    kubectl $KCTX wait --for=condition=Ready pods --all -n "${NAMESPACE}" --timeout="${KUBECTL_WAIT_TIMEOUT}" || warn "Some pods not ready"
  else
    warn "No pods found in namespace '${NAMESPACE}' yet."
  fi
  ok "MDAI ready (or mostly)."
}

act_install_mdai_stack() {
  ns_ensure
  # Always-on defaults
  add_set "mdai-operator.manager.env.otelSdkDisabled=true"
  add_set "mdai-gateway.otelSdkDisabled=true"
  add_set "mdai-s3-logs-reader.enabled=false"
  helm_install_or_upgrade_mdai
}

act_install_hub()        { ns_ensure; k_apply "$1"; ok "Hub applied"; }
act_install_collector()  { ns_ensure; k_apply "$1"; ok "Collector applied"; }

act_deploy_logs() {
  ns_ensure
  info "Deploying synthetic log generators..."
  k_apply "${SYN_PATH}/loggen_service_xtra_noisy.yaml" || warn "xtra_noisy apply failed"
  k_apply "${SYN_PATH}/loggen_service_noisy.yaml"      || warn "noisy apply failed"
  k_apply "${SYN_PATH}/loggen_services.yaml"           || warn "services apply failed"
  ok "Log generators deployed"
}

act_forward_fluentd() {
  local values="$1"
  ensure_file "$values"
  info "Installing Fluentd (values: $values)..."
  run "helm $HCTX upgrade --install fluent fluentd --repo https://fluent.github.io/helm-charts -f ${values} -n default --create-namespace"
  ok "Fluentd configured"
}

act_apply_aws_secret() {
  local script="$1"
  ensure_file "$script"
  info "Applying AWS credentials secret via: ${script}"
  if "$DRY_RUN"; then
    echo "+ ${script}"
  else
    "${script}"
  fi
  ok "AWS secret applied"
}

act_apply_bundle() {
  ns_ensure
  local otel_f="$1" hub_f="$2"
  info "Applying bundle:"
  k_apply "$otel_f"
  k_apply "$hub_f"
  ok "Bundle applied"
}

act_delete_bundle() {
  ns_ensure
  local otel_f="$1" hub_f="$2"
  info "Delete bundle:"
  k_delete "$otel_f"
  k_delete "$hub_f"
  ok "Bundle deleted"
}

act_clean() {
  info "Deleting mdai..."
  run "helm $HCTX uninstall -n mdai mdai"
  ok "Resources removed (namespace left intact)."
}

act_delete_kind() {
  info "Deleting Kind cluster '${KIND_CLUSTER_NAME}'..."
  run "kind delete cluster --name ${KIND_CLUSTER_NAME}"
  ok "Kind cluster deleted."
}

# ========================
# Build report
# ========================
json_safe() { sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
have() { command -v "$1" >/dev/null 2>&1; }

helm_get_values_json() {
  local rel="${HELM_RELEASE_NAME}" ns
  ns="$(helm_ns)"
  helm $HCTX get values "$rel" -n "$ns" -o json 2>/dev/null || echo "{}"
}

collect_cert_manager_version() {
  kubectl $KCTX get ns cert-manager >/dev/null 2>&1 || { echo ""; return; }
  kubectl $KCTX -n cert-manager get deploy -l app.kubernetes.io/name=cert-manager \
    -o jsonpath='{.items[0].spec.template.spec.containers[0].image}' 2>/dev/null \
    | sed -E 's/^.*:([^:]+)$/\1/' || echo ""
}

collect_services_list() {
  kubectl $KCTX get svc -n "${NAMESPACE}" -o jsonpath='{range .items[*]}{.metadata.name} ({.spec.type}){"\n"}{end}' 2>/dev/null
}

collect_deployments_list() {
  kubectl $KCTX get deploy -n "${NAMESPACE}" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null
}

collect_pod_images_lines() {
  { kubectl $KCTX get pods -n "${NAMESPACE}" \
      -o jsonpath='{range .items[*].spec.containers[*]}{.image}{"\n"}{end}{range .items[*].spec.initContainers[*]}{.image}{"\n"}{end}' 2>/dev/null \
    || true; } | grep -v '^$' | sort -u
}

report_table() {
  local cmv imgs deps svcs live_vals
  cmv="$(collect_cert_manager_version || true)"
  imgs="$(collect_pod_images_lines | sed 's/^/    - /' || true)"
  deps="$(collect_deployments_list | sed 's/^/    - /' || true)"
  svcs="$(collect_services_list | sed 's/^/    /'       || true)"
  live_vals="$(helm_get_values_json | sed 's/^/  /')"

cat <<EOF
==================== MDAI Build Report ====================
Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

Cluster
  Kube Context      : ${KUBE_CONTEXT:-<current>}
  Kind Cluster Name : ${KIND_CLUSTER_NAME}
  Kind Config       : ${KIND_CONFIG:-<none>}

Namespaces
  App Namespace     : ${NAMESPACE}
  Chart Namespace   : $(helm_ns)

Helm
  Release Name      : ${HELM_RELEASE_NAME}
  Chart Ref         : ${HELM_CHART_REF:-<repo/name mode>}
  Chart Repo/Name   : ${HELM_REPO_URL} / ${HELM_CHART_NAME}
  Chart Version     : ${HELM_CHART_VERSION}

Helm Runtime Values (this invocation)
  --values          : ${HELM_VALUES[*]:-"<none>"}
  --set             : ${HELM_SET[*]:-"<none>"}
  Extra Helm Args   : ${HELM_EXTRA[*]:-"<none>"}

Live Helm Values (cluster)
${live_vals}

Workloads (namespace: ${NAMESPACE})
  Deployments
${deps:-"    - <none>"}

  Services
${svcs:-"    <none>"}

  Pod Images
${imgs:-"    - <none>"}

Cert-Manager
  Installed         : $(kubectl $KCTX get ns cert-manager >/dev/null 2>&1 && echo "yes" || echo "no")
  Version (image)   : ${cmv:-""}

===========================================================
EOF
}

report_json() {
  local imgs deps svcs live_vals
  imgs="$(collect_pod_images_lines | sed 's/"/\\"/g')"
  deps="$(collect_deployments_list | sed 's/"/\\"/g')"
  svcs="$(collect_services_list   | sed 's/"/\\"/g')"
  live_vals="$(helm_get_values_json | tr -d '\n')"

  printf '{\n'
  printf '  "timestamp": "%s",\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  printf '  "cluster": {"kube_context":"%s","kind_cluster_name":"%s","kind_config":"%s"},\n' \
    "$(printf "%s" "${KUBE_CONTEXT:-<current>}" | json_safe)" \
    "$(printf "%s" "${KIND_CLUSTER_NAME}"     | json_safe)" \
    "$(printf "%s" "${KIND_CONFIG:-}"         | json_safe)"
  printf '  "namespaces": {"app":"%s","chart":"%s"},\n' \
    "$(printf "%s" "${NAMESPACE}"  | json_safe)" \
    "$(printf "%s" "$(helm_ns)"    | json_safe)"
  printf '  "helm": {\n'
  printf '    "release_name":"%s",\n' "$(printf "%s" "${HELM_RELEASE_NAME}" | json_safe)"
  printf '    "chart_ref":"%s",\n'     "$(printf "%s" "${HELM_CHART_REF:-}" | json_safe)"
  printf '    "chart_repo":"%s",\n'    "$(printf "%s" "${HELM_REPO_URL}"    | json_safe)"
  printf '    "chart_name":"%s",\n'    "$(printf "%s" "${HELM_CHART_NAME}"  | json_safe)"
  printf '    "chart_version":"%s",\n' "$(printf "%s" "${HELM_CHART_VERSION}"| json_safe)"

  printf '    "invocation_values_files": ['
    if ((${#HELM_VALUES[@]:-0})); then
      local i=0 first=1
      while (( i < ${#HELM_VALUES[@]} )); do
        if [[ "${HELM_VALUES[$i]}" == "--values" ]]; then
          ((i++)); printf '%s"%s"' $([[ $first -eq 0 ]] && echo ,) "$(printf "%s" "${HELM_VALUES[$i]}" | json_safe)"; first=0
        fi; ((i++))
      done
    fi
  printf '],\n'

  printf '    "invocation_set_flags": ['
    if ((${#HELM_SET[@]:-0})); then
      local i=0 first=1
      while (( i < ${#HELM_SET[@]} )); do
        if [[ "${HELM_SET[$i]}" == "--set" ]]; then
          ((i++)); printf '%s"%s"' $([[ $first -eq 0 ]] && echo ,) "$(printf "%s" "${HELM_SET[$i]}" | json_safe)"; first=0
        fi; ((i++))
      done
    fi
  printf '],\n'

  printf '    "invocation_extra_args": ['
    if ((${#HELM_EXTRA[@]:-0})); then
      local i=0
      for a in "${HELM_EXTRA[@]}"; do
        printf '%s"%s"' $([[ $i -gt 0 ]] && echo ,) "$(printf "%s" "$a" | json_safe)"; ((i++))
      done
    fi
  printf '],\n'

  printf '    "live_values": %s\n' "${live_vals:-{}}"
  printf '  },\n'

  printf '  "workloads": {\n'
  printf '    "deployments": ['; { local first=1; while IFS= read -r d; do [[ -z "$d" ]] && continue; printf '%s"%s"' $([[ $first -eq 0 ]] && echo ,) "$(printf "%s" "$d" | json_safe)"; first=0; done <<< "$deps"; }; printf '],\n'
  printf '    "services": [';    { local first=1; while IFS= read -r s; do [[ -z "$s" ]] && continue; printf '%s"%s"' $([[ $first -eq 0 ]] && echo ,) "$(printf "%s" "$s" | json_safe)"; first=0; done <<< "$svcs"; }; printf '],\n'
  printf '    "images": [';      { local first=1; while IFS= read -r img; do [[ -z "$img" ]] && continue; printf '%s"%s"' $([[ $first -eq 0 ]] && echo ,) "$(printf "%s" "$img" | json_safe)"; first=0; done <<< "$imgs"; }; printf ']\n'
  printf '  },\n'

  printf '  "cert_manager": {"installed": %s, "image_version": "%s"}\n' \
    "$(kubectl $KCTX get ns cert-manager >/dev/null 2>&1 && echo true || echo false)" \
    "$(collect_cert_manager_version | json_safe)"
  printf '}\n'
}

report_yaml() {
  if have yq; then
    report_json | yq -P
    return
  fi
  local imgs deps svcs
  imgs="$(collect_pod_images_lines)"
  deps="$(collect_deployments_list)"
  svcs="$(collect_services_list)"

cat <<EOF
timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
cluster:
  kube_context: ${KUBE_CONTEXT:-<current>}
  kind_cluster_name: ${KIND_CLUSTER_NAME}
  kind_config: ${KIND_CONFIG:-""}
namespaces:
  app: ${NAMESPACE}
  chart: $(helm_ns)
helm:
  release_name: ${HELM_RELEASE_NAME}
  chart_ref: ${HELM_CHART_REF:-""}
  chart_repo: ${HELM_REPO_URL}
  chart_name: ${HELM_CHART_NAME}
  chart_version: ${HELM_CHART_VERSION}
  invocation_values_files: [$(printf '%s' "${HELM_VALUES[*]:-}" | sed 's/ --values /, /g')]
  invocation_set_flags: [$(printf '%s' "${HELM_SET[*]:-}"   | sed 's/ --set /, /g')]
  invocation_extra_args: [$(printf '%s' "${HELM_EXTRA[*]:-}"| sed 's/ /, /g')]
workloads:
  deployments:
$(printf '%s\n' "${deps:-}" | sed 's/^/    - /')
  services:
$(printf '%s\n' "${svcs:-}" | sed 's/^/    /')
  images:
$(printf '%s\n' "${imgs:-}" | sed 's/^/    - /')
cert_manager:
  installed: $(kubectl $KCTX get ns cert-manager >/dev/null 2>&1 && echo true || echo false)
  image_version: "$(collect_cert_manager_version)"
EOF
}

cmd_report() {
  local fmt="table" out=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --format) shift; fmt="${1:-table}"; shift ;;
      --out)    shift; out="${1:-}";     shift ;;
      --) shift; break ;;
      *) err "report: unknown flag '$1'"; return 1 ;;
    esac
  done

  case "$fmt" in
    table)  report_table > "${out:-/dev/stdout}" ;;
    json)   report_json  > "${out:-/dev/stdout}" ;;
    yaml)   report_yaml  > "${out:-/dev/stdout}" ;;
    *) err "report: unsupported --format '${fmt}' (use table|json|yaml)"; return 1 ;;
  esac

  [[ -n "$out" ]] && ok "Report written to ${out}"
}

# Defaults to ./mdai-usage-gen.sh, but you can override with MDAI_USAGE_GEN=/path/to/script
cmd_gen_usage_external() {
  local GEN="${MDAI_USAGE_GEN:-./cli/mdai-usage-gen.sh}"

  if [[ ! -f "$GEN" ]]; then
    err "Generator not found: $GEN"
    err "Put mdai-usage-gen.sh next to mdai.sh or set MDAI_USAGE_GEN=/path/to/script"
    exit 1
  fi

  # Add --in "$0" if the caller didn't specify --in
  local has_in=0
  for a in "$@"; do
    if [[ "$a" == "--in" ]]; then has_in=1; break; fi
  done
  if (( has_in == 0 )); then
    set -- --in "$0" "$@"
  fi

  bash "$GEN" "$@"
}

# ========================
# Higher-level workflows
# ========================
act_check_tools_and_context() {
  act_check_tools
  if [[ -n "${KUBE_CONTEXT:-}" ]]; then
    KCTX="--context ${KUBE_CONTEXT}"
    HCTX="--kube-context ${KUBE_CONTEXT}"
  fi
}

cmd_install_deps() {
  act_check_tools_and_context
  act_create_or_reuse_kind

  # by default add these overrides
  add_set "mdai-operator.manager.env.otelSdkDisabled=true"
  add_set "mdai-gateway.otelSdkDisabled=true"
  add_set "mdai-s3-logs-reader.enabled=false"

  case "$INSTALL_CERT_MANAGER" in
    true|1|yes|on|TRUE|Yes|ON)
      info "cert-manager enabled (INSTALL_CERT_MANAGER=$INSTALL_CERT_MANAGER)"
      act_install_cert_manager
      ;;
    false|0|no|off|FALSE|No|OFF)
      info "cert-manager disabled (INSTALL_CERT_MANAGER=$INSTALL_CERT_MANAGER); applying Helm flags"
      apply_no_cert_manager_sets
      ;;
    *)
      warn "INSTALL_CERT_MANAGER has unexpected value '$INSTALL_CERT_MANAGER'; assuming 'true'."
      act_install_cert_manager
      ;;
  esac
}
cmd_install_mdai() {
  act_check_tools_and_context

  # Subcommand-local parsing for install-only flags
  # Supported:
  #   --version VER
  #   --set key=val
  #   --values FILE
  #   --resources [PREFIX]
  #   --no-cert-manager
  local maybe_prefix
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --no-cert-manager)
        INSTALL_CERT_MANAGER=false
        shift
        ;;
      --version)
        shift
        HELM_CHART_VERSION="${1:?install_mdai: --version requires a value}"
        shift
        ;;
      --set)
        shift
        add_set "${1:?install_mdai: --set requires key=val}"
        shift
        ;;
      --values)
        shift
        add_values "${1:?install_mdai: --values requires a file}"
        shift
        ;;
      --resources)
        if [[ -n "${2:-}" && "${2:-}" != --* ]]; then
          maybe_prefix="${2}."
          shift 2
        else
          maybe_prefix=""
          shift
        fi
        # If you want --resources to actually inject --set flags here, uncomment:
        # add_set "${maybe_prefix}resources.requests.cpu=500m"
        # add_set "${maybe_prefix}resources.requests.memory=1Gi"
        # add_set "${maybe_prefix}resources.limits.cpu=1000m"
        # add_set "${maybe_prefix}resources.limits.memory=2Gi"
        ;;
      --)
        shift; break ;;
      *)
        err "install_mdai: unknown flag '$1'"
        return 1
        ;;
    esac
  done

  # Ensure the "--no-cert-manager" behavior is honored even if install_deps wasn't run
  case "$INSTALL_CERT_MANAGER" in
    false|0|no|off|FALSE|No|OFF)
      info "cert-manager disabled for install_mdai; applying Helm flags"
      apply_no_cert_manager_sets
      ;;
  esac

  ns_ensure
  act_install_mdai_stack
  act_wait_mdai_ready
}

# Back-compat alias for old "install"
cmd_install_legacy() {
  cmd_install_deps "$@"
  cmd_install_mdai "$@"
}

cmd_upgrade()  { act_check_tools_and_context; ns_ensure; helm_install_or_upgrade_mdai; ok "Upgraded."; }

# File apply/delete helpers (new non-conflicting commands)
cmd_apply_file()        { act_check_tools_and_context; [[ $# -ge 1 ]] || { err "apply: need FILE"; exit 1; }; k_apply "$1"; }
cmd_delete_file()       { act_check_tools_and_context; [[ $# -ge 1 ]] || { err "delete_file: need FILE"; exit 1; }; k_delete "$1"; }

# Subcommand parsers
cmd_hub() {
  act_check_tools_and_context
  local file="${MDAI_PATH}/hub/hub_ref.yaml"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file) shift; file="${1:?}"; shift ;;
      *) err "hub: unknown flag $1"; exit 1 ;;
    esac
  done
  act_install_hub "$file"
}

cmd_collector() {
  act_check_tools_and_context
  local file="${OTEL_PATH}/otel_ref.yaml"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file) shift; file="${1:?}"; shift ;;
      *) err "collector: unknown flag $1"; exit 1 ;;
    esac
  done
  act_install_collector "$file"
}

cmd_bundle() { act_apply_bundle "$1" "$2"; }
cmd_bundle_del() { act_delete_bundle "$1" "$2"; }

cmd_compliance() {
  act_check_tools_and_context
  local version="" DO_DELETE=false
  local otel_f="" hub_f=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --otel)    shift; otel_f="${1:?}"; shift ;;
      --hub)     shift; hub_f="${1:?}";  shift ;;
      --version) shift; version="${1:?}"; shift ;;
      --delete)  DO_DELETE=true; shift ;;
      *) err "compliance: unknown flag $1"; exit 1 ;;
    esac
  done

  # Preferred (versioned) layout:
  #   ${USE_CASES_ROOT}/${version}/use_cases/compliance/otel.yaml
  #   ${USE_CASES_ROOT}/${version}/use_cases/compliance/mdaihub.yaml
  # Fallbacks:
  #   ./use_cases/compliance/otel.yaml
  #   ./use_cases/compliance/mdaihub.yaml
  #   ${OTEL_PATH}/otel_compliance.yaml
  #   ${MDAI_PATH}/hub/hub_compliance.yaml
  if [[ -z "$otel_f" ]]; then
    local c1 c2 c3
    [[ -n "$version" ]] && c1="${USE_CASES_ROOT}/${version}/use_cases/compliance/otel.yaml" || c1=""
    c2="./use_cases/compliance/otel.yaml"
    c3="${OTEL_PATH}/otel_compliance.yaml"
    otel_f="$(first_existing "$c1" "$c2" "$c3")"
  fi
  if [[ -z "$hub_f" ]]; then
    local c1 c2 c3
    [[ -n "$version" ]] && c1="${USE_CASES_ROOT}/${version}/use_cases/compliance/mdaihub.yaml" || c1=""
    c2="./use_cases/compliance/mdaihub.yaml"
    c3="${MDAI_PATH}/hub/hub_compliance.yaml"
    hub_f="$(first_existing "$c1" "$c2" "$c3")"
  fi

  if $DO_DELETE; then
    act_delete_bundle "$otel_f" "$hub_f"
  else
    k_apply "$otel_f"   # ensure_file inside k_apply will fail loudly if nothing exists
    k_apply "$hub_f"
    ok "Compliance bundle applied"
  fi
}

cmd_df() {
  act_check_tools_and_context
  local version="" DO_DELETE=false
  local otel_f="" hub_f=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --otel)    shift; otel_f="${1:?}"; shift ;;
      --hub)     shift; hub_f="${1:?}";  shift ;;
      --version) shift; version="${1:?}"; shift ;;
      --delete)  DO_DELETE=true; shift ;;
      *) err "df: unknown flag $1"; exit 1 ;;
    esac
  done

  # Preferred (versioned) layout:
  #   ${USE_CASES_ROOT}/${version}/use_cases/data_filtration/otel.yaml
  #   ${USE_CASES_ROOT}/${version}/use_cases/data_filtration/mdaihub.yaml
  # Fallbacks:
  #   ./use_cases/data_filtration/otel.yaml
  #   ./use_cases/data_filtration/mdaihub.yaml
  #   ${OTEL_PATH}/otel_dynamic_filtration.yaml
  #   ${MDAI_PATH}/hub/hub_dynamic_filtration.yaml
  if [[ -z "$otel_f" ]]; then
    local c1 c2 c3
    [[ -n "$version" ]] && c1="${USE_CASES_ROOT}/${version}/use_cases/data_filtration/otel.yaml" || c1=""
    c2="./use_cases/data_filtration/otel.yaml"
    c3="${OTEL_PATH}/otel_dynamic_filtration.yaml"
    otel_f="$(first_existing "$c1" "$c2" "$c3")"
  fi
  if [[ -z "$hub_f" ]]; then
    local c1 c2 c3
    [[ -n "$version" ]] && c1="${USE_CASES_ROOT}/${version}/use_cases/data_filtration/mdaihub.yaml" || c1=""
    c2="./use_cases/data_filtration/mdaihub.yaml"
    c3="${MDAI_PATH}/hub/hub_dynamic_filtration.yaml"
    hub_f="$(first_existing "$c1" "$c2" "$c3")"
  fi

  if $DO_DELETE; then
    act_delete_bundle "$otel_f" "$hub_f"
  else
    k_apply "$otel_f"
    k_apply "$hub_f"
    ok "Dynamic Filtration bundle applied"
  fi
}

cmd_pii() {
  act_check_tools_and_context
  local version="" DO_DELETE=false
  local otel_f="" hub_f=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --otel)    shift; otel_f="${1:?}"; shift ;;
      --hub)     shift; hub_f="${1:?}";  shift ;;
      --version) shift; version="${1:?}"; shift ;;
      --delete)  DO_DELETE=true; shift ;;
      *) err "pii: unknown flag $1"; exit 1 ;;
    esac
  done

  # Preferred (versioned) layout:
  #   ${USE_CASES_ROOT}/${version}/use_cases/pii/otel.yaml
  #   ${USE_CASES_ROOT}/${version}/use_cases/pii/mdaihub.yaml
  # Fallbacks:
  #   ./use_cases/pii/otel.yaml
  #   ./use_cases/pii/mdaihub.yaml
  #   ${OTEL_PATH}/otel_pii.yaml
  #   ${MDAI_PATH}/hub/hub_pii.yaml
  if [[ -z "$otel_f" ]]; then
    local c1 c2 c3
    [[ -n "$version" ]] && c1="${USE_CASES_ROOT}/${version}/use_cases/pii/otel.yaml" || c1=""
    c2="./use_cases/pii/otel.yaml"
    c3="${OTEL_PATH}/otel_pii.yaml"
    otel_f="$(first_existing "$c1" "$c2" "$c3")"
  fi
  if [[ -z "$hub_f" ]]; then
    local c1 c2 c3
    [[ -n "$version" ]] && c1="${USE_CASES_ROOT}/${version}/use_cases/pii/mdaihub.yaml" || c1=""
    c2="./use_cases/pii/mdaihub.yaml"
    c3="${MDAI_PATH}/hub/hub_pii.yaml"
    hub_f="$(first_existing "$c1" "$c2" "$c3")"
  fi

  if $DO_DELETE; then
    act_delete_bundle "$otel_f" "$hub_f"
  else
    k_apply "$otel_f"
    k_apply "$hub_f"
    ok "PII bundle applied"
  fi
}

cmd_logs()       { act_check_tools_and_context; act_deploy_logs; }
cmd_fluentd()    {
  act_check_tools_and_context
  local values="${SYN_PATH}/loggen_fluent_config.yaml"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --values|--file) shift; values="${1:?}"; shift ;;
      *) err "fluentd: unknown flag $1"; exit 1 ;;
    esac
  done
  act_forward_fluentd "$values"
}
cmd_aws_secret() {
  act_check_tools_and_context
  local script="./aws/aws_secret_from_env.sh"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --script) shift; script="${1:?}"; shift ;;
      *) err "aws_secret: unknown flag $1"; exit 1 ;;
    esac
  done
  act_apply_aws_secret "$script"
}

cmd_mdai_mon() {
  act_check_tools_and_context
  local file="${MDAI_PATH}/hub_monitor/mdai_monitor_no_secrets.yaml"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file) shift; file="${1:?}"; shift ;;
      *) err "mdai_monitor: unknown flag $1"; exit 1 ;;
    esac
  done
  act_install_collector "$file"
}

cmd_clean()        { act_check_tools_and_context; act_clean; }
cmd_delete_cluster(){ act_check_tools_and_context; act_delete_kind; }

# ========================
# CLI parsing
# ========================
usage() {
cat <<'EOF'
mdai.sh - Modular MDAI quickstart

USAGE:
  ./mdai.sh [global flags] <command> [command flags]

GLOBAL FLAGS:
  --cluster-name NAME        Kind cluster name (default: $KIND_CLUSTER_NAME)
  --kind-config FILE         Kind cluster config file (optional)
  --namespace NS             App namespace for kubectl applies (default: $NAMESPACE)
  --chart-namespace NS       Helm namespace (defaults to --namespace if omitted)
  --kube-context NAME        kubecontext for kubectl/helm
  --release-name NAME        Helm release name (default: mdai)
  --chart-ref REF            Full chart ref (e.g., oci://ghcr.io/decisiveai/mdai-hub)
  --chart-repo URL           Helm repo URL (default: $HELM_REPO_URL)
  --chart-name NAME          Helm chart name (default: $HELM_CHART_NAME)
  --chart-version VER        Helm chart version (default: $HELM_CHART_VERSION)
  --values FILE              Add a Helm values file (repeatable)
  --set key=val              Add a Helm --set (repeatable)
  --helm-extra "ARGS"        Extra Helm args (repeatable)
  --cert-manager-url URL     Override cert-manager manifest URL
  --no-cert-manager          Skip installing cert-manager
  --wait-timeout 120s        kubectl wait timeout (default: $KUBECTL_WAIT_TIMEOUT)
  --dry-run                  Print commands without executing
  --verbose                  Print commands and stream output
  -h, --help                 Show help

COMMANDS:

INSTALL / UPGRADE
  install                        Create Kind deps then install MDAI (alias: install_deps + install_mdai)
  install_deps                   Prepare Kind cluster + dependencies
  install_mdai                   Helm install/upgrade + wait
                                 [--version VER] [--values FILE] [--set k=v] [--resources [PREFIX]] [--no-cert-manager]
  upgrade                        Helm upgrade/install only

COMPONENTS
  hub [--file FILE]              Apply Hub manifest (default: ./mdai/hub/hub_ref.yaml)
  collector [--file FILE]        Apply OTel Collector (default: ./otel/otel_ref.yaml)
  fluentd [--values FILE]        Install Fluentd with values
  mdai_monitor [--file FILE]     Apply Monitor manifest
  aws_secret [--script FILE]     Create Kubernetes secret from env script

DATA GENERATION
  datagen [--apply FILE ...]     Apply custom generator YAMLs (falls back to built-in synthetics)
  logs                           Alias for 'datagen'

USE-CASES
  use-case <pii|compliance|tail-sampling>
           [--version VER] [--hub PATH] [--otel PATH] [--apply FILE ...]
                                 Apply a named bundle. If --hub/--otel not given, resolves:
                                 ./use-cases/<case>[/<version>]/{hub.yaml,otel.yaml}
                                 Extras can be added with repeatable --apply.
                                 Examples:
                                   use-case compliance --version 0.8.6
                                   use-case pii --hub ./use-cases/pii/0.8.6/hub.yaml --otel ./use-cases/pii/0.8.6/otel.yaml

KUBECTL HELPERS
  apply FILE                     kubectl apply -f FILE -n $NAMESPACE
  delete_file FILE               kubectl delete -f FILE -n $NAMESPACE

MAINTENANCE
  clean                          Remove common resources (keeps namespace)
  delete                         Delete the Kind cluster

REPORTING / DOCS
  report [--format table|json|yaml] [--out FILE]
                                 Show what’s installed
  gen-usage [--out FILE] [--examples FILE] [--section "..."]
                                 Generate usage.md

DEPRECATED (prefer `use-case`)
  compliance [--version VER] [--delete] [--otel FILE --hub FILE]
  df         [--version VER] [--delete] [--otel FILE --hub FILE]
  pii        [--version VER] [--delete] [--otel FILE --hub FILE]

For a full, nicely formatted guide, run:
  ./mdai.sh gen-usage --out ./docs/usage.md --examples ./cli/examples.md
EOF
}

# Re-parse global flags that appear *after* the subcommand.
# Consumes known globals from CMD_ARGS and leaves only real subcommand args.
parse_trailing_globals() {
  local out=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --cluster-name)      KIND_CLUSTER_NAME="$2"; shift 2 ;;
      --kind-config)       KIND_CONFIG="$2"; shift 2 ;;
      --namespace)         NAMESPACE="$2"; shift 2 ;;
      --chart-namespace)   CHART_NAMESPACE="$2"; shift 2 ;;
      --kube-context)      KUBE_CONTEXT="$2"; shift 2 ;;
      --release-name)      HELM_RELEASE_NAME="$2"; shift 2 ;;
      --chart-ref)         HELM_CHART_REF="$2"; shift 2 ;;
      --chart-repo)        HELM_REPO_URL="$2"; shift 2 ;;
      --chart-name)        HELM_CHART_NAME="$2"; shift 2 ;;
      --chart-version)     HELM_CHART_VERSION="$2"; shift 2 ;;
      --values)            add_values "$2"; shift 2 ;;
      --set)               add_set "$2"; shift 2 ;;
      --helm-extra)        add_extra "$2"; shift 2 ;;
      --cert-manager-url)  CERT_MANAGER_URL="$2"; shift 2 ;;
      --no-cert-manager)   INSTALL_CERT_MANAGER=false; shift ;;
      --wait-timeout)      KUBECTL_WAIT_TIMEOUT="$2"; shift 2 ;;
      --dry-run)           DRY_RUN=true; shift ;;
      --verbose)           VERBOSE=true; shift ;;
      -h|--help)           usage; exit 0 ;;
      --)                  shift; while [[ $# -gt 0 ]]; do out+=("$1"); shift; done; break ;;
      *)                   out+=("$1"); shift ;;
    esac
  done
  CMD_ARGS=("${out[@]}")
}

parse_globals() {
  local seen_cmd=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --cluster-name)      KIND_CLUSTER_NAME="$2"; shift 2 ;;
      --kind-config)       KIND_CONFIG="$2"; shift 2 ;;
      --namespace)         NAMESPACE="$2"; shift 2 ;;
      --chart-namespace)   CHART_NAMESPACE="$2"; shift 2 ;;
      --kube-context)      KUBE_CONTEXT="$2"; shift 2 ;;
      --release-name)      HELM_RELEASE_NAME="$2"; shift 2 ;;
      --chart-ref)         HELM_CHART_REF="$2"; shift 2 ;;
      --chart-repo)        HELM_REPO_URL="$2"; shift 2 ;;
      --chart-name)        HELM_CHART_NAME="$2"; shift 2 ;;
      --chart-version)     HELM_CHART_VERSION="$2"; shift 2 ;;
      --values)            add_values "$2"; shift 2 ;;
      --set)               add_set "$2"; shift 2 ;;
      --helm-extra)        add_extra "$2"; shift 2 ;;
      --cert-manager-url)  CERT_MANAGER_URL="$2"; shift 2 ;;
      --no-cert-manager)   INSTALL_CERT_MANAGER=false; shift ;;
      --wait-timeout)      KUBECTL_WAIT_TIMEOUT="$2"; shift 2 ;;
      --dry-run)           DRY_RUN=true; shift ;;
      --verbose)           VERBOSE=true; shift ;;
      -h|--help)           usage; exit 0 ;;
      --)                  shift; break ;;
      install|install_deps|install_mdai|upgrade|clean|delete|apply|delete_file|logs|hub|collector|fluentd|aws_secret|mdai_monitor|compliance|df|pii|report|gen-usage)
        seen_cmd="$1"; shift; break ;;
      *) err "Unknown flag or command: $1"; usage; exit 1 ;;
    esac
  done

  COMMAND="${seen_cmd:-${1:-}}"
  CMD_ARGS=("$@")

  # Guard empty array to avoid 'unbound variable' on Bash 3.2 + set -u
  if ((${#CMD_ARGS[@]:-0})); then
    # Re-parse globals that were placed after the subcommand
    parse_trailing_globals "${CMD_ARGS[@]}"
  else
    CMD_ARGS=()
  fi


  # Recompute context strings after all globals are known
  if [[ -n "${KUBE_CONTEXT:-}" ]]; then
    KCTX="--context ${KUBE_CONTEXT}"
    HCTX="--kube-context ${KUBE_CONTEXT}"
  fi
}

# Safely pass CMD_ARGS to a subcommand (works with Bash 3.2 + set -u)
call_with_cmd_args() {
  local fn="$1"; shift || true
  if ((${#CMD_ARGS[@]:-0})); then
    "$fn" "${CMD_ARGS[@]}"
  else
    "$fn"
  fi
}

main() {
  if [[ $# -eq 0 ]]; then usage; exit 1; fi
  parse_globals "$@"

  case "${COMMAND:-}" in
    install_deps)    call_with_cmd_args cmd_install_deps ;;
    install_mdai)    call_with_cmd_args cmd_install_mdai ;;
    install)         call_with_cmd_args cmd_install_legacy ;;
    upgrade)         call_with_cmd_args cmd_upgrade ;;
    apply)           call_with_cmd_args cmd_apply_file ;;
    delete_file)     call_with_cmd_args cmd_delete_file ;;
    clean)           cmd_clean ;;
    delete)          cmd_delete_cluster ;;
    logs)            call_with_cmd_args cmd_logs ;;
    hub)             call_with_cmd_args cmd_hub ;;
    collector)       call_with_cmd_args cmd_collector ;;
    fluentd)         call_with_cmd_args cmd_fluentd ;;
    aws_secret)      call_with_cmd_args cmd_aws_secret ;;
    mdai_monitor)    call_with_cmd_args cmd_mdai_mon ;;
    compliance)      call_with_cmd_args cmd_compliance ;;
    df)              call_with_cmd_args cmd_df ;;
    pii)             call_with_cmd_args cmd_pii ;;
    report)          call_with_cmd_args cmd_report ;;
    gen-usage)       call_with_cmd_args cmd_gen_usage_external ;;
    *) err "Unknown command: ${COMMAND:-}"; usage; exit 1 ;;
  esac
}

main "$@"
