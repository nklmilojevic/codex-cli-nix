{ lib
, stdenv
, fetchurl
, makeWrapper
}:

let
  version = "0.118.0";

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
      sha256 = "0hciyc1g9n0c1vdfql9chp1jfj1h5gil8wpy696qw9xaph5rihkv";
    };
    "x86_64-darwin" = fetchurl {
      url = "https://registry.npmjs.org/@openai/codex/-/codex-${version}-darwin-x64.tgz";
      sha256 = "15qnspn6dh8va4zlxppbdla64bbcypzfxymhrsallg0xabfl3glv";
    };
    "x86_64-linux" = fetchurl {
      url = "https://registry.npmjs.org/@openai/codex/-/codex-${version}-linux-x64.tgz";
      sha256 = "1jpgcrfw05d44vdyr55qnaxz478m6cw4i5zjr4zj4y4555qjckjj";
    };
    "aarch64-linux" = fetchurl {
      url = "https://registry.npmjs.org/@openai/codex/-/codex-${version}-linux-arm64.tgz";
      sha256 = "1hb8949bwfyawvhrhdblrgxf57vy895c1m3xz9ka64ry60myz8l1";
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
