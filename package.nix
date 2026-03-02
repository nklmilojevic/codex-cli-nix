{ lib
, stdenv
, fetchurl
, makeWrapper
}:

let
  version = "0.107.0";

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
      sha256 = "0d90pbaiyh2qizzdlpa809ncx0mmbbr4vr7sknl0dmmcgs1n0pxj";
    };
    "x86_64-darwin" = fetchurl {
      url = "https://registry.npmjs.org/@openai/codex/-/codex-${version}-darwin-x64.tgz";
      sha256 = "0cz0sjlais0pwchi5c75g2fb462vh1d1nxsxqj1b3irqh30fz83j";
    };
    "x86_64-linux" = fetchurl {
      url = "https://registry.npmjs.org/@openai/codex/-/codex-${version}-linux-x64.tgz";
      sha256 = "0afz8mrck72b8jz6xgxx6c7v5s8vawgqh9va7g7l2fvmggirb2dz";
    };
    "aarch64-linux" = fetchurl {
      url = "https://registry.npmjs.org/@openai/codex/-/codex-${version}-linux-arm64.tgz";
      sha256 = "0iffjw9rbsppv0r98hpkpljj2j6cid4b31h0506v1cd0c1fvgask";
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
