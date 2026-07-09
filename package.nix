{ lib
, stdenv
, fetchurl
, makeWrapper
, ripgrep
, bubblewrap
}:

let
  version = "0.144.0";

  targetTriple = {
    "aarch64-darwin" = "aarch64-apple-darwin";
    "x86_64-darwin" = "x86_64-apple-darwin";
    "x86_64-linux" = "x86_64-unknown-linux-musl";
    "aarch64-linux" = "aarch64-unknown-linux-musl";
  }.${stdenv.hostPlatform.system}
    or (throw "Unsupported platform: ${stdenv.hostPlatform.system}");

  hashes = {
    "aarch64-apple-darwin" = "114jnik61p2x10ilgplr70bq4q2wslwa2v4pg18l4qi41cr65q0h";
    "x86_64-apple-darwin" = "0c935n87iqm5p0fihwiq240pn3v48jlhrabkggfmyxbsrz0li5xx";
    "x86_64-unknown-linux-musl" = "1fy80pxm1fancrd33xzr71i22b6iyvns1ai9503z6jmb43y86n3j";
    "aarch64-unknown-linux-musl" = "0lbbrkn857nk5zlzy3lp271yfbpcqdx5zfzm8g3mbddxa1wlmi67";
  };

  # rg is used by codex for searching; bwrap for Linux sandboxing. Both were
  # previously bundled in the npm tarball, now supplied from nixpkgs.
  runtimePath = lib.makeBinPath ([ ripgrep ] ++ lib.optionals stdenv.isLinux [ bubblewrap ]);
in

stdenv.mkDerivation {
  pname = "codex";
  inherit version;

  src = fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-${targetTriple}.tar.gz";
    sha256 = hashes.${targetTriple};
  };

  sourceRoot = ".";

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;
  # Static musl binary on Linux, signed binary on Darwin — leave untouched
  dontPatchELF = true;
  dontStrip = true;

  installPhase = ''
    mkdir -p $out/bin $out/libexec/codex

    install -m755 codex-${targetTriple} $out/libexec/codex/codex

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
