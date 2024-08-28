#!/usr/bin/env bash

set -euo pipefail

GH_REPO="https://github.com/atuinsh/atuin"
TOOL_NAME="atuin"
TOOL_TEST="atuin --version"

fail() {
  echo -e "asdf-$TOOL_NAME: $*"
  exit 1
}

curl_opts=(-fsSL)

if [ -n "${GITHUB_API_TOKEN:-}" ]; then
  curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

sort_versions() {
  sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
    LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_github_tags() {
  git ls-remote --tags --refs "$GH_REPO" |
    grep -o 'refs/tags/.*' | cut -d/ -f3- |
    sed 's/^v//'
}

list_all_versions() {
  list_github_tags
}

download_release() {
  local version filename url
  version="$1"
  filename="$2"

  local arch
  arch=$(uname -m | tr '[:upper:]' '[:lower:]')
  local kernel
  kernel=$(uname -s | tr '[:upper:]' '[:lower:]')
  case "${arch}-${kernel}" in
    arm64-linux)
      url="$GH_REPO/releases/download/v${version}/atuin-aarch64-unknown-linux-gnu.tar.gz"
      ;;
    aarch64-linux)
      url="$GH_REPO/releases/download/v${version}/atuin-aarch64-unknown-linux-gnu.tar.gz"
      ;;
    x86_64-linux)
      url="$GH_REPO/releases/download/v${version}/atuin-x86_64-unknown-linux-gnu.tar.gz"
      ;;
    arm64-darwin)
      url="$GH_REPO/releases/download/v${version}/atuin-aarch64-apple-darwin.tar.gz"
      ;;
    x86_64-darwin)
      url="$GH_REPO_CBIN/releases/download/atuin-${version}/atuin-x86_64-apple-darwin.tar.gz"
      ;;
    *)
      fail "Could not determine release URL"
      ;;
  esac

  echo "* Downloading $TOOL_NAME release $version..."
  curl "${curl_opts[@]}" -o "$filename" -C - "$url" || fail "Could not download $url"
}

install_version() {
  local install_type="$1"
  local version="$2"
  local install_path="$3"

  if [ "$install_type" != "version" ]; then
    fail "asdf-$TOOL_NAME supports release installs only"
  fi

  local release_bin="$install_path/bin"
  local release_file="$release_bin/$TOOL_NAME"
  local release_tar="$release_file.tar.gz"
  (
    mkdir -p "$release_bin"
    download_release "$version" "$release_tar"
    tar -xf "$release_tar" -C "$install_path" --strip-components=1 || fail "Could not extract $release_file"
    mv "$install_path/atuin" "$release_file"
    rm "$release_tar"
    chmod +x "$release_file"

    local tool_cmd
    tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"
    test -x "$install_path/bin/$tool_cmd" || fail "Expected $install_path/bin/$tool_cmd to be executable."

    echo "$TOOL_NAME $version installation was successful!"
  ) || (
    rm -rf "$install_path"
    fail "An error ocurred while installing $TOOL_NAME $version."
  )
}
