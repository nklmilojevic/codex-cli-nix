{ lib
, stdenv
, fetchurl
, makeWrapper
, ripgrep
, bubblewrap
}:

let
  version = "0.155.1";

  targetTriple = {
    "aarch64-darwin" = "aarch64-apple-darwin";
    "x86_64-darwin" = "x86_64-apple-darwin";
    "x86_64-linux" = "x86_64-unknown-linux-musl";
    "aarch64-linux" = "aarch64-unknown-linux-musl";
  }.${stdenv.hostPlatform.system}
    or (throw "Unsupported platform: ${stdenv.hostPlatform.system}");

  hashes = {
    "aarch64-apple-darwin" = { codex = "0s1pgah4gbwf2zskv0x690l0xk64pg893lbbv7wj696f1m3m2njy"; codeModeHost = "12jh3c3x89f685q199vj35ylfavsgzmpr18614xrcw5xxq4735g8"; };
    "x86_64-apple-darwin" = { codex = "14bpq8jcp9jcfszii48gz9q53zji8jk0xvr8zgdni1cby85ss8pz"; codeModeHost = "0sh6d1apzw0dx4ng6v44qknz8bsrs7fy4w3wl0zw2hlqldvj67ad"; };
    "x86_64-unknown-linux-musl" = { codex = "05cibl5lg0d2id4pc8nc1nn004z39lskk85i0xz79gy3xcnqpvx0"; codeModeHost = "0bbv0qkksdw7f0b8z4x3d9dny4xm3wvisdgbmhcfhnzm79s87l4z"; };
    "aarch64-unknown-linux-musl" = { codex = "1mx2ykqylrp376hvfbd442lk4pbh2c39v4pk0kp553b8plpydiyn"; codeModeHost = "10qnhsvfi79isws6gqlp79fdq6zdfr2qzh6kfhh6rsaadpbjwvsi"; };
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
