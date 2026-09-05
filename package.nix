{ lib
, stdenv
, fetchurl
, makeWrapper
, ripgrep
, bubblewrap
}:

let
  version = "0.153.4";

  targetTriple = {
    "aarch64-darwin" = "aarch64-apple-darwin";
    "x86_64-darwin" = "x86_64-apple-darwin";
    "x86_64-linux" = "x86_64-unknown-linux-musl";
    "aarch64-linux" = "aarch64-unknown-linux-musl";
  }.${stdenv.hostPlatform.system}
    or (throw "Unsupported platform: ${stdenv.hostPlatform.system}");

  hashes = {
    "aarch64-apple-darwin" = { codex = "1cahk0mkydd3v2s6slxdj145dfiain263i8y2arby8v5czm13ycc"; codeModeHost = "1pziklcha8lh805bakx1lwl175hfv5fif7mrdddbi61vypyv1aa5"; };
    "x86_64-apple-darwin" = { codex = "194zrblghhhh9fjfh6mrpb14ybiafk7q02zq0wd1s6w4pzq014nn"; codeModeHost = "1xrvprpk8h8m0yxs0g4g28p8dnjri189lhaqqcr655rx238fpyig"; };
    "x86_64-unknown-linux-musl" = { codex = "0c2ah46q14z465hms13098il1k7l8j6f4ynq83f88909r9744ygl"; codeModeHost = "0cfdnj4ny5q8b7qvlw1nd5mq0ww7n367pimz9dk5f2ard6l30n7r"; };
    "aarch64-unknown-linux-musl" = { codex = "1pkc3c3sbhf6907xf56vzn8zdxzbi5a4jfmn5q7s7hwlpn163njw"; codeModeHost = "0fw11p3mvc69730l7hd1pa32c2p6dnvpxli9wy86039p6f6pn16q"; };
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
