{ lib
, stdenv
, fetchurl
, makeWrapper
, diffutils
}:

let
  version = "0.162.1";

  targetTriple = {
    "aarch64-darwin" = "aarch64-apple-darwin";
    "x86_64-darwin" = "x86_64-apple-darwin";
    "x86_64-linux" = "x86_64-unknown-linux-musl";
    "aarch64-linux" = "aarch64-unknown-linux-musl";
  }.${stdenv.hostPlatform.system}
    or (throw "Unsupported platform: ${stdenv.hostPlatform.system}");

  hashes = {
    "aarch64-apple-darwin" = "0pc8ks9v6w9x0plsrwq438nrqkx9l9k3rq8vvjllw3ssvz6prqw8";
    "x86_64-apple-darwin" = "1vbsvk17i6bckgnyhdk0p0w66q7xaiyd535ylji4z7c1zq5c4jl9";
    "x86_64-unknown-linux-musl" = "1qx33xhligzzshx0nc0avj4xs7xbivq34hvnwg5qc3df59rgaxm6";
    "aarch64-unknown-linux-musl" = "12yqq0xak8b10jv37alq71xy36aiv427fbzbzmipmcmyjh5wxaak";
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
