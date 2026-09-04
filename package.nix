{ lib
, stdenv
, fetchurl
, makeWrapper
, ripgrep
, bubblewrap
}:

let
  version = "0.153.3";

  targetTriple = {
    "aarch64-darwin" = "aarch64-apple-darwin";
    "x86_64-darwin" = "x86_64-apple-darwin";
    "x86_64-linux" = "x86_64-unknown-linux-musl";
    "aarch64-linux" = "aarch64-unknown-linux-musl";
  }.${stdenv.hostPlatform.system}
    or (throw "Unsupported platform: ${stdenv.hostPlatform.system}");

  hashes = {
    "aarch64-apple-darwin" = { codex = "1kannflik19l9cw6s8dz4q5v1qcx6a02aq3gmcn6yqf1fkccpk82"; codeModeHost = "0s884315kd26m3ilx8s08bnz3b6baamwgwwhvm7z4ad8k42889rv"; };
    "x86_64-apple-darwin" = { codex = "067jfi5ym321anjvjzx1cnv7hbv7z0641sypgp7hl4fs706dn6f6"; codeModeHost = "1c1978lim2sfh5qbggygq0w1a846spvxks74r1djb73bgxsikn7s"; };
    "x86_64-unknown-linux-musl" = { codex = "1flcyixfvd40wzhygg9yqmd6xjxkxa48gg284x67650fn15ngybg"; codeModeHost = "0lzgkb329laixdlydx3fxagwxqv8k225v9varmfrv3fj8lq67bhh"; };
    "aarch64-unknown-linux-musl" = { codex = "06dz6s0s4095pzzhhx1l446jibrxi6x6c3d38imlzpip56r7xzv8"; codeModeHost = "1kjalg3ixmfd1m11d99svgab0vabgdi7qj7gxfdb0bzy8a0bji0z"; };
  }.${targetTriple};

  # rg is used by codex for searching; bwrap for Linux sandboxing. Both were
  # previously bundled in the npm tarball, now supplied from nixpkgs.
  runtimePath = lib.makeBinPath ([ ripgrep ] ++ lib.optionals stdenv.hostPlatform.isLinux [ bubblewrap ]);
in

stdenv.mkDerivation {
  pname = "codex";
  inherit version;

  srcs = [
    (fetchurl {
      url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-${targetTriple}.tar.gz";
      sha256 = hashes.codex;
    })
    # Spawned by codex as a sibling of the main binary when
    # `features.code_mode_host` is enabled; code mode fails closed without it.
    (fetchurl {
      url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-code-mode-host-${targetTriple}.tar.gz";
      sha256 = hashes.codeModeHost;
    })
  ];

  sourceRoot = ".";

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;
  # Static musl binary on Linux, signed binary on Darwin — leave untouched
  dontPatchELF = true;
  dontStrip = true;

  installPhase = ''
    mkdir -p $out/bin $out/libexec/codex

    install -m755 codex-${targetTriple} $out/libexec/codex/codex
    install -m755 codex-code-mode-host-${targetTriple} $out/libexec/codex/codex-code-mode-host

    makeWrapper $out/libexec/codex/codex $out/bin/codex \
      --set DISABLE_AUTOUPDATER 1 \
      --prefix PATH : "${runtimePath}"
  '';

  meta = with lib; {
    description = "OpenAI Codex CLI - AI coding assistant in your terminal";
    homepage = "https://github.com/openai/codex";
    license = licenses.asl20;
    platforms = [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux" ];
    mainProgram = "codex";
  };
}
