{ lib
, stdenv
, fetchurl
, makeWrapper
, ripgrep
, bubblewrap
}:

let
  version = "0.154.0";

  targetTriple = {
    "aarch64-darwin" = "aarch64-apple-darwin";
    "x86_64-darwin" = "x86_64-apple-darwin";
    "x86_64-linux" = "x86_64-unknown-linux-musl";
    "aarch64-linux" = "aarch64-unknown-linux-musl";
  }.${stdenv.hostPlatform.system}
    or (throw "Unsupported platform: ${stdenv.hostPlatform.system}");

  hashes = {
    "aarch64-apple-darwin" = { codex = "1mzrrvmiczna671smflqjiy90s8s682g7vsgw29b3hcilnh10hrl"; codeModeHost = "1bbgr1fn8hs1xwac4c3gk00xpl81wbcdgrsjj18sx6555shf43jh"; };
    "x86_64-apple-darwin" = { codex = "1rx630z7l0yfwqznvg3rcahrqpcb0g02bh94lj9v84zqv0vwh68j"; codeModeHost = "1zl76fwxpr1i673sd8wzzdxk24kjg7z9qn3av314vx4iwm0n3ym0"; };
    "x86_64-unknown-linux-musl" = { codex = "00kzq045shxniy3djd6nxp4xnj7gvs89xviibwpj93xfjwjqpqfp"; codeModeHost = "1xq1mx0xd1jb4nhk64yx98ikmiv1vvvpsrvmw76sfv9wlb6gg3d6"; };
    "aarch64-unknown-linux-musl" = { codex = "09rwld7m42nc4skmg9qzh9047cq6vdd2x31krnyi6hl06bglhfsq"; codeModeHost = "1ynbdnv347kipngxnswwfkywfxjz9aavy499wfbb88i05hqgmbi0"; };
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
