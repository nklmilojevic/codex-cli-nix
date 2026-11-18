{ lib
, stdenv
, fetchurl
, makeWrapper
, installShellFiles
, diffutils
}:

let
  version = "0.170.0";

  targetTriple = {
    "aarch64-darwin" = "aarch64-apple-darwin";
    "x86_64-darwin" = "x86_64-apple-darwin";
    "x86_64-linux" = "x86_64-unknown-linux-musl";
    "aarch64-linux" = "aarch64-unknown-linux-musl";
  }.${stdenv.hostPlatform.system}
    or (throw "Unsupported platform: ${stdenv.hostPlatform.system}");

  hashes = {
    "aarch64-apple-darwin" = "14vq5kr3rfrxjisb7h48ysw92w76kv0003ld5l91ppdf2fzj8mcp";
    "x86_64-apple-darwin" = "09fz5hg8yjjvp402zxp78ip5a54wbsgb9jdx7n8hnmqa8qj1b5rf";
    "x86_64-unknown-linux-musl" = "1svmhh5vjac9xz8id52j0zf2fdffymw0l9r8axqrv05swxxzhzx7";
    "aarch64-unknown-linux-musl" = "0iw89vrm6akyq1qjpmiqln7x0dn9xvl5bf42w0i77qjgikiilziz";
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

  nativeBuildInputs = [ makeWrapper installShellFiles ];

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
  ''
  # The unwrapped binary: the wrapper's daemon check has no business in a build.
  + lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    export HOME=$TMPDIR
    installShellCompletion --cmd codex \
      --bash <($out/libexec/codex/bin/codex completion bash) \
      --fish <($out/libexec/codex/bin/codex completion fish) \
      --zsh <($out/libexec/codex/bin/codex completion zsh)
  '';

  meta = with lib; {
    description = "OpenAI Codex CLI - AI coding assistant in your terminal";
    homepage = "https://github.com/openai/codex";
    license = licenses.asl20;
    platforms = [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux" ];
    mainProgram = "codex";
  };
}
