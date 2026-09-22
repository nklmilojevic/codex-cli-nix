{ lib
, stdenv
, fetchurl
, makeWrapper
, ripgrep
, bubblewrap
}:

let
  version = "0.156.0";

  targetTriple = {
    "aarch64-darwin" = "aarch64-apple-darwin";
    "x86_64-darwin" = "x86_64-apple-darwin";
    "x86_64-linux" = "x86_64-unknown-linux-musl";
    "aarch64-linux" = "aarch64-unknown-linux-musl";
  }.${stdenv.hostPlatform.system}
    or (throw "Unsupported platform: ${stdenv.hostPlatform.system}");

  hashes = {
    "aarch64-apple-darwin" = { codex = "1hra4355is49qldnvgjyas4lxlhrwvb4576gck2pp2knagjy1nih"; codeModeHost = "1virfw93f2ycilbhl2wa1aqnw6hci70zqnz2ssr6c1c202gpxr3p"; };
    "x86_64-apple-darwin" = { codex = "1chwvmjlpqvhq9n8365wr666a4yk2byi0zjpwva87m43whrkdlci"; codeModeHost = "0v3mb6i8sdsvia1q1f4j16pxjyj4p6xm2f0gri891qdiy4sajrhi"; };
    "x86_64-unknown-linux-musl" = { codex = "0yswajr7q04vz0a7rbjrqa1k1ciqn85543p5a7y8q5m54npxjj9x"; codeModeHost = "0fz5r94s8sdvh08zrfcidrmdj2jm3pz4i98w3bq7fkvb1fdwg0w3"; };
    "aarch64-unknown-linux-musl" = { codex = "18n598hlpvaazgrvz0bqj28d3k60zpgjx7fafwvzv9qp4rkpmlbp"; codeModeHost = "1c76z0h6897awniwwrss8csxslmck7hjh9kjbvyl3cq7w92ml9nq"; };
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
