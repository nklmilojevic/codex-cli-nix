{ lib
, stdenv
, fetchurl
, makeWrapper
}:

let
  version = "0.125.0";

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
      sha256 = "1082035aark2zp93s1n9g4f6ibn9dgwc541f9i5ffk0hdcrs6a77";
    };
    "x86_64-darwin" = fetchurl {
      url = "https://registry.npmjs.org/@openai/codex/-/codex-${version}-darwin-x64.tgz";
      sha256 = "1hbhgz711ici4papy1sv6y6f79djyy0jvw4nbsqflqgs53rpa0ih";
    };
    "x86_64-linux" = fetchurl {
      url = "https://registry.npmjs.org/@openai/codex/-/codex-${version}-linux-x64.tgz";
      sha256 = "1zs370wp6jdm2smlwy0ljd270yrhh893mrw9izr5hh4wf4rlf7r1";
    };
    "aarch64-linux" = fetchurl {
      url = "https://registry.npmjs.org/@openai/codex/-/codex-${version}-linux-arm64.tgz";
      sha256 = "0yxicdlcd3y3i1jnif3z4vclnh2v0gkpwzwm1clhax1samn9cp7g";
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
