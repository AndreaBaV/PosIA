#!/usr/bin/env bash
# Instala Flutter desde el CDN de Google (no desde GitHub) para no chocar
# con el rate limit de codeload al bajar subosito/flutter-action.
set -euo pipefail

if [[ -z "${FLUTTER_VERSION:-}" ]]; then
	echo "FLUTTER_VERSION es obligatorio" >&2
	exit 1
fi

os="$(uname -s)"
arch="$(uname -m)"
base="https://storage.googleapis.com/flutter_infra_release/releases"

case "$os" in
	Linux)
		archive="stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
		;;
	Darwin)
		if [[ "$arch" == "arm64" ]]; then
			archive="stable/macos/flutter_macos_arm64_${FLUTTER_VERSION}-stable.zip"
		else
			archive="stable/macos/flutter_macos_${FLUTTER_VERSION}-stable.zip"
		fi
		;;
	*)
		echo "SO no soportado para este setup: $os" >&2
		exit 1
		;;
esac

url="${base}/${archive}"
workdir="${RUNNER_TEMP:-/tmp}/flutter-setup"
mkdir -p "$workdir"
bundle="${workdir}/sdk.archive"

echo "Descargando Flutter ${FLUTTER_VERSION} desde ${url}"
curl -fL --retry 5 --retry-delay 2 --retry-all-errors -o "$bundle" "$url"

extract_parent="${RUNNER_TEMP:-/tmp}"
rm -rf "${extract_parent}/flutter"
if [[ "$archive" == *.zip ]]; then
	unzip -q "$bundle" -d "$extract_parent"
else
	tar xf "$bundle" -C "$extract_parent"
fi

flutter_root="${extract_parent}/flutter"
if [[ ! -x "${flutter_root}/bin/flutter" ]]; then
	echo "No se encontro bin/flutter en ${flutter_root}" >&2
	exit 1
fi

if command -v git >/dev/null 2>&1; then
	git config --global --add safe.directory "$flutter_root" || true
fi

if [[ -n "${GITHUB_PATH:-}" ]]; then
	echo "${flutter_root}/bin" >> "${GITHUB_PATH}"
	echo "${HOME}/.pub-cache/bin" >> "${GITHUB_PATH}"
fi
export PATH="${flutter_root}/bin:${PATH}"

flutter --version
