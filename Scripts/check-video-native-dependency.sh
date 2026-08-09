#!/usr/bin/env bash
set -u

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest_path="${VIDEO_NATIVE_MANIFEST:-${repo_root}/NativeBackend/StableDiffusionCpp/video-native-dependency-manifest.json}"
output_path="${VIDEO_NATIVE_REPORT:-}"
xcframework_path="${VIDEO_NATIVE_XCFRAMEWORK:-${repo_root}/LocalDiffusion/Frameworks/LocalDiffusionNative.xcframework}"
symbols_file="${VIDEO_NATIVE_SYMBOLS_FILE:-}"

if [[ ! -f "${manifest_path}" ]]; then
  echo "Video native dependency manifest is missing: ${manifest_path}" >&2
  exit 2
fi

observed_symbols=()
if [[ -n "${symbols_file}" && -f "${symbols_file}" ]]; then
  while IFS= read -r symbol; do
    [[ -n "${symbol}" ]] && observed_symbols+=("${symbol}")
  done < "${symbols_file}"
elif command -v xcrun >/dev/null 2>&1 && [[ -d "${xcframework_path}" ]]; then
  while IFS= read -r archive; do
    symbol_output="$(mktemp)"
    if xcrun nm -gU "${archive}" >"${symbol_output}" 2>/dev/null; then
      for symbol in _generate_video _sd_ctx_supports_video_generation; do
        if grep -q "${symbol}" "${symbol_output}" && [[ ! " ${observed_symbols[*]-} " == *" ${symbol} "* ]]; then
          observed_symbols+=("${symbol}")
        fi
      done
      if grep -q 'LTX' "${symbol_output}" && [[ ! " ${observed_symbols[*]-} " == *" LTX "* ]]; then
        observed_symbols+=("LTX")
      fi
      if grep -q 'WAN' "${symbol_output}" && [[ ! " ${observed_symbols[*]-} " == *" WAN "* ]]; then
        observed_symbols+=("WAN")
      fi
    fi
    rm -f "${symbol_output}"
  done < <(find "${xcframework_path}" -name '*.a' -type f -print 2>/dev/null)
fi

observed_symbols_json="[]"
if [[ "${#observed_symbols[@]}" -gt 0 ]]; then
  observed_symbols_json="$(printf '%s\n' "${observed_symbols[@]}" | python3 -c 'import json, sys; print(json.dumps(list(dict.fromkeys(line.rstrip("\n") for line in sys.stdin if line.strip()))))')"
fi

if [[ -n "${output_path}" ]]; then
  python3 "${repo_root}/Scripts/video-native-dependency-report.py" \
    "${repo_root}" "${manifest_path}" "${observed_symbols_json}" \
    > "${output_path}"
  preflight_status=$?
  if ! python3 -m json.tool "${output_path}" >/dev/null 2>&1; then
    preflight_status=1
  fi
  exit "${preflight_status}"
fi

python3 "${repo_root}/Scripts/video-native-dependency-report.py" \
  "${repo_root}" "${manifest_path}" "${observed_symbols_json}"
exit $?
