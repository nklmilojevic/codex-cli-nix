{ lib
, stdenv
, fetchurl
, makeWrapper
, ripgrep
, bubblewrap
}:

let
  version = "0.156.1";

  targetTriple = {
    "aarch64-darwin" = "aarch64-apple-darwin";
    "x86_64-darwin" = "x86_64-apple-darwin";
    "x86_64-linux" = "x86_64-unknown-linux-musl";
    "aarch64-linux" = "aarch64-unknown-linux-musl";
  }.${stdenv.hostPlatform.system}
    or (throw "Unsupported platform: ${stdenv.hostPlatform.system}");

  hashes = {
    "aarch64-apple-darwin" = { codex = "1jm525qi422f2hia4yrcrjd1jyfg4p8xbgznyaapgm7d9pqlmmib"; codeModeHost = "1ncvywgr4x4fi9im8a1df8y5vhii1073wyj3rhmkvq5nw8ix0996"; };
    "x86_64-apple-darwin" = { codex = "1psld9bd6gs5v76mlw94bfsy7jgz5xij4425jkfj0dz5vs34bqsm"; codeModeHost = "02bj3l4z7wy15225ph09h4w5yz5hycv2hvalw6qzpmqjfag8v5pw"; };
    "x86_64-unknown-linux-musl" = { codex = "0gak2hfw0l1sy3x9la6zz68m7nah5k72nn9cqviqdzrsm0wnbx5g"; codeModeHost = "0266crz2rhwrdi7mb7bgv6n2bc8py4nl1rn9q00drgd0yslxlad9"; };
    "aarch64-unknown-linux-musl" = { codex = "0wlvyx23yh2s300lzmh6d1s592nv46bvyh3jqig37jyslsm153jm"; codeModeHost = "155y1ibcgh52q8872jqhx9s6g2d5iix84k6sq2lgz61pn0w826a0"; };
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
