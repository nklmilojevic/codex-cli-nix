{ lib
, stdenv
, fetchurl
, makeWrapper
}:

let
  version = "0.142.5";

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
      sha256 = "0v3p26gy9fh5l5n37cygxdp3lc8sr350i8d7pkl8d84kgd8xpy2i";
    };
    "x86_64-darwin" = fetchurl {
      url = "https://registry.npmjs.org/@openai/codex/-/codex-${version}-darwin-x64.tgz";
      sha256 = "1yfl2m81sn6503fsj66s6hmr40h5brr9l40hha440caz7vnhkvzk";
    };
    "x86_64-linux" = fetchurl {
      url = "https://registry.npmjs.org/@openai/codex/-/codex-${version}-linux-x64.tgz";
      sha256 = "0iyyga8glgqnnqwijqw9skwxm8dk310csf9y0fxsw289rcb32gm0";
    };
    "aarch64-linux" = fetchurl {
      url = "https://registry.npmjs.org/@openai/codex/-/codex-${version}-linux-arm64.tgz";
      sha256 = "0ihdkdqmwji7ddz6d0wjz2ic1w2hpwvlr3sjx9zli6z8js4vmk3y";
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

    # Tarball layout changed in 0.142.x: codex/codex -> bin/codex, path -> codex-path
    if [ -x $out/libexec/codex/bin/codex ]; then
      codexBin=$out/libexec/codex/bin/codex
      toolsPath=$out/libexec/codex/codex-path
    else
      codexBin=$out/libexec/codex/codex/codex
      toolsPath=$out/libexec/codex/path
    fi

    # Create wrapper that adds bundled tools (e.g. rg) to PATH
    makeWrapper $codexBin $out/bin/codex \
      --prefix PATH : "$toolsPath"
  '';

  meta = with lib; {
    description = "OpenAI Codex CLI - AI coding assistant in your terminal";
    homepage = "https://github.com/openai/codex";
    license = licenses.unfree;
    platforms = [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux" ];
    mainProgram = "codex";
  };
}
