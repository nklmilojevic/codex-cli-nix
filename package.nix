{ lib
, stdenv
, fetchurl
, makeWrapper
, ripgrep
, bubblewrap
}:

let
  version = "0.153.2";

  targetTriple = {
    "aarch64-darwin" = "aarch64-apple-darwin";
    "x86_64-darwin" = "x86_64-apple-darwin";
    "x86_64-linux" = "x86_64-unknown-linux-musl";
    "aarch64-linux" = "aarch64-unknown-linux-musl";
  }.${stdenv.hostPlatform.system}
    or (throw "Unsupported platform: ${stdenv.hostPlatform.system}");

  hashes = {
    "aarch64-apple-darwin" = { codex = "1770x6gvgwxy0r0fd11pkvf78zpjsj8amw8lv0bfrfnzy1qc5pwi"; codeModeHost = "02rhahcbqph0m9pz23im1za6fdimf11x31zc9klwpys1c55faw9l"; };
    "x86_64-apple-darwin" = { codex = "0ypf476fbpp8619pbrjga5d0jnlplmxq4a7yqjhmahmi4zgiaifq"; codeModeHost = "12zi68zvih4947gc0qk5k2llx968lizag9q0vvvlbr4y4vyqf1g1"; };
    "x86_64-unknown-linux-musl" = { codex = "17lpy3yncvpg4xfi4wk3165zq638vmri1f6a20m5swhz0xh13kg8"; codeModeHost = "0jmy5qs2zxfpys7m1gd8fsl72slznfblc0xc2gqrfzycp43layhp"; };
    "aarch64-unknown-linux-musl" = { codex = "0ap6ljxc17ixd7g37izjl6d7syv8ynhrxyck2yi0wckhngwr71l7"; codeModeHost = "01xzpk4x22z905rmk1gf6rgrm8c2aym73gkhbyvki80rd5g4izkh"; };
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
