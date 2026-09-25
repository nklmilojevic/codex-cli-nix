{ lib
, stdenv
, fetchurl
, makeWrapper
, ripgrep
, bubblewrap
}:

let
  version = "0.157.0";

  targetTriple = {
    "aarch64-darwin" = "aarch64-apple-darwin";
    "x86_64-darwin" = "x86_64-apple-darwin";
    "x86_64-linux" = "x86_64-unknown-linux-musl";
    "aarch64-linux" = "aarch64-unknown-linux-musl";
  }.${stdenv.hostPlatform.system}
    or (throw "Unsupported platform: ${stdenv.hostPlatform.system}");

  hashes = {
    "aarch64-apple-darwin" = { codex = "02c98crdmzhshfmhad2f3lzp42qac0y8mypjifsvpj7q5cv2458g"; codeModeHost = "0mr3dnq6ahb6rd2n952ppi2jgkpiraag3fszi38380d5qzv3zcx5"; };
    "x86_64-apple-darwin" = { codex = "0wybk18250nc7q3n72d73fpmcgp0zxi17c9ivwrqmwwdz20wry5v"; codeModeHost = "0m97q5hb493d01pgcqsn9mrxc13sqba355i7j5mybh4pxbcdx6wc"; };
    "x86_64-unknown-linux-musl" = { codex = "0yv5q364hrzb0dq3vdhgjs939zl2fw8qm64anvghxi9mmany6gyv"; codeModeHost = "174qy5wi9iibbw7afggdzpiz03i5zc5qk8k4nvdwvjcmx0cj9ls7"; };
    "aarch64-unknown-linux-musl" = { codex = "0pyjlw5zmjrjdy3y370l9an40cj4yw841hrvgqzq66wlirwy5yz6"; codeModeHost = "04690pnm2am50gg8f8yq9wm52z408i641c7w1q4zhsz16n0kac9v"; };
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
