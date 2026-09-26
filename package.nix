{ lib
, stdenv
, fetchurl
, makeWrapper
, ripgrep
, bubblewrap
}:

let
  version = "0.157.1";

  targetTriple = {
    "aarch64-darwin" = "aarch64-apple-darwin";
    "x86_64-darwin" = "x86_64-apple-darwin";
    "x86_64-linux" = "x86_64-unknown-linux-musl";
    "aarch64-linux" = "aarch64-unknown-linux-musl";
  }.${stdenv.hostPlatform.system}
    or (throw "Unsupported platform: ${stdenv.hostPlatform.system}");

  hashes = {
    "aarch64-apple-darwin" = { codex = "1yllb2jrnz63c9bwsncvgadj2wrc26ld1c8ma0r52vx7nxib2i9w"; codeModeHost = "05432diwyzjklhnr8i8rmjqjzxwb9b3fmpzvr1hmrpvhr79350r8"; };
    "x86_64-apple-darwin" = { codex = "084s3j8gf404iqdj789gyzr9b41nv8di0r9b3q6vfqjzdf09n6i8"; codeModeHost = "15hcbdh70m58krxk6lvd9ws2rsvrjkw4j5szax0bpzrqdgyair9z"; };
    "x86_64-unknown-linux-musl" = { codex = "1wja8lqwmcz5mi55bqr7lq0kfywfqlpch5945px3g0cf0a71x379"; codeModeHost = "1z6pfblkkf6523mbkf8h7x5ikavyl69v54nvggp0dg76pfwgj5im"; };
    "aarch64-unknown-linux-musl" = { codex = "0lv2n5fv3245r5lv5shz5drym5bvhs0p86wmn97hvzf5q4biqssc"; codeModeHost = "13iipfbmr24g885sshd3amvj5s192syrwc14mmvrm3m9dn044dz8"; };
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
