{ lib
, stdenv
, fetchurl
, makeWrapper
, ripgrep
, bubblewrap
}:

let
  version = "0.155.0";

  targetTriple = {
    "aarch64-darwin" = "aarch64-apple-darwin";
    "x86_64-darwin" = "x86_64-apple-darwin";
    "x86_64-linux" = "x86_64-unknown-linux-musl";
    "aarch64-linux" = "aarch64-unknown-linux-musl";
  }.${stdenv.hostPlatform.system}
    or (throw "Unsupported platform: ${stdenv.hostPlatform.system}");

  hashes = {
    "aarch64-apple-darwin" = { codex = "0jdsrlfd10mvlpv0ahgnnwk1a8y4bc7z2lysra1p1af2vmy4nn2s"; codeModeHost = "0szshyrxqcqvmm95gr0plzvsnwmqzsar7702hvq2ci8vz7p1sx9x"; };
    "x86_64-apple-darwin" = { codex = "0x41a5r7rz2dq3sz9w57wpffp38win0jim5qr08flki82ldhi16c"; codeModeHost = "17glds30831ard5majamldzfnn6g0s5skh21w07m16ygv9piqp98"; };
    "x86_64-unknown-linux-musl" = { codex = "1h5nxh5a18zjvmp5s6p55r5w6710m5cdvd24impf3bclvcxcq5g4"; codeModeHost = "1m2lg15awdrv53sq727fh61v3lsklgz6wmwl6w2jgiwzw3mip31j"; };
    "aarch64-unknown-linux-musl" = { codex = "0jv9qnz5zf13lyzxv2kmr6y724zsp00qm49zr7vibi8nd4srqjlb"; codeModeHost = "16s8smvryihcbfyfm5lp1hn0b8zbmzmwkikd1ivj1db86hk8xk8f"; };
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
