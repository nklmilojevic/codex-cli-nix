{ lib
, stdenv
, fetchurl
, makeWrapper
, diffutils
}:

let
  version = "0.159.0";

  targetTriple = {
    "aarch64-darwin" = "aarch64-apple-darwin";
    "x86_64-darwin" = "x86_64-apple-darwin";
    "x86_64-linux" = "x86_64-unknown-linux-musl";
    "aarch64-linux" = "aarch64-unknown-linux-musl";
  }.${stdenv.hostPlatform.system}
    or (throw "Unsupported platform: ${stdenv.hostPlatform.system}");

  hashes = {
    "aarch64-apple-darwin" = "1mym1n4dr5pvz2r5byb7gsbpbikp67sd1s8ms28pp9i1g5yx0j3p";
    "x86_64-apple-darwin" = "05wh8d5vl2kcz966rmr3wzisgzcx59kq3gasq73j8ha5i01d6r5b";
    "x86_64-unknown-linux-musl" = "0km2hcgk8zkck0hwzm2n4d4nn35l2n63skjd1bm2hkk4x3bnbnim";
    "aarch64-unknown-linux-musl" = "1nl9vw435xg84xjx6c3z3y334qqhg0hdpb588ml8vk0qfszx56bk";
  };
in

stdenv.mkDerivation {
  pname = "codex";
  inherit version;

  # The packaged release (codex-package.json manifest plus bin/, codex-path/
  # and codex-resources/) is required since 0.157: codex auto-starts its
  # background app-server daemon and refuses to without a complete package.
  # It also bundles rg (codex-path/) and, on Linux, bwrap (codex-resources/).
  src = fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-package-${targetTriple}.tar.gz";
    sha256 = hashes.${targetTriple};
  };

  sourceRoot = ".";

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;
  # Static musl binary on Linux, signed binary on Darwin — leave untouched
  dontPatchELF = true;
  dontStrip = true;

  # The background daemon runs from its own copy of the package under
  # $CODEX_HOME and, unless pinned, self-updates from GitHub releases. Before
  # each launch, pin it to this store package whenever it is unpinned or was
  # installed from a different package (e.g. after a Nix upgrade).
  installPhase = ''
    mkdir -p $out/bin $out/libexec/codex

    cp -R bin codex-package.json codex-path codex-resources $out/libexec/codex/

    makeWrapper $out/libexec/codex/bin/codex $out/bin/codex \
      --run '
        daemon_pkg="''${CODEX_HOME:-$HOME/.codex}/packages/app-server-daemon"
        if [ -d "$daemon_pkg/current" ] && {
          [ -e "$daemon_pkg/auto-update-version" ] ||
          ! ${diffutils}/bin/cmp -s "$daemon_pkg/current/codex-package.json" "'"$out"'/libexec/codex/codex-package.json"
        }; then
          "'"$out"'/libexec/codex/bin/codex" app-server daemon update --from-cli --yes >/dev/null 2>&1 || true
        fi
      '
  '';

  meta = with lib; {
    description = "OpenAI Codex CLI - AI coding assistant in your terminal";
    homepage = "https://github.com/openai/codex";
    license = licenses.asl20;
    platforms = [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux" ];
    mainProgram = "codex";
  };
}
