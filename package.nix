{ lib
, stdenv
, fetchurl
, makeWrapper
}:

let
  version = "0.122.0";

  targetTriple = {
    "aarch64-darwin" = "aarch64-apple-darwin";
    "x86_64-darwin" = "x86_64-apple-darwin";
    "x86_64-linux" = "x86_64-unknown-linux-musl";
    "aarch64-linux" = "aarch64-unknown-linux-musl";
  }.${stdenv.hostPlatform.system}
    or (throw "Unsupported platform: ${stdenv.hostPlatform.system}");

  platformSources = {
    "aarch64-darwin" = fetchurl {
      url = "https://registry.npmjs.org/@openai/codex/-/codex-${version}-darwin-arm64.tgz";
      sha256 = "16r3wqpfjizwc98a7nqhjrgdy1ylk41vk5jgj59b3227wm4ylcbd";
    };
    "x86_64-darwin" = fetchurl {
      url = "https://registry.npmjs.org/@openai/codex/-/codex-${version}-darwin-x64.tgz";
      sha256 = "1z76hpgfibqkv9rh4jwy6apysw5s1xzr0ws1p5k7vims2hb3kfcn";
    };
    "x86_64-linux" = fetchurl {
      url = "https://registry.npmjs.org/@openai/codex/-/codex-${version}-linux-x64.tgz";
      sha256 = "09ll523xbqq2jlbhn304vh0v0ca5adhgh2n6iwli4gnhjsaghsdc";
    };
    "aarch64-linux" = fetchurl {
      url = "https://registry.npmjs.org/@openai/codex/-/codex-${version}-linux-arm64.tgz";
      sha256 = "0aw3y4rqqxg3i0y7x2y2y0pqxxi9ksz3qkwy4r5jfmzhn75gx9kr";
    };
  };

  platformSrc = platformSources.${stdenv.hostPlatform.system};
in

stdenv.mkDerivation {
  pname = "codex";
  inherit version;

  src = platformSrc;

  sourceRoot = ".";

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;

  installPhase = ''
    mkdir -p $out/bin $out/libexec/codex

    # Copy the native binary and bundled tools
    cp -r package/vendor/${targetTriple}/* $out/libexec/codex/

    # Create wrapper that adds bundled tools (e.g. rg) to PATH
    makeWrapper $out/libexec/codex/codex/codex $out/bin/codex \
      --prefix PATH : "$out/libexec/codex/path"
  '';

  meta = with lib; {
    description = "OpenAI Codex CLI - AI coding assistant in your terminal";
    homepage = "https://github.com/openai/codex";
    license = licenses.unfree;
    platforms = [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux" ];
    mainProgram = "codex";
  };
}
