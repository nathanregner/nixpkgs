{
  lib,
  fetchFromGitHub,
  makeWrapper,
  nodejs,
  stdenv,
  versionCheckHook,
  yarn-berry_4,
}:
let
  manifest = lib.importJSON ./manifest.json;
in
stdenv.mkDerivation (finalAttrs: rec {
  pname = "graphql-language-service-cli";
  inherit (manifest.src) version;

  src = fetchFromGitHub {
    owner = "graphql";
    repo = "graphiql";
    inherit (manifest.src) rev hash;
  };

  patches = [
    ./patches/0001-repurpose-vscode-graphql-build-script.patch
  ];

  inherit (manifest.yarn) missingHashes;
  offlineCache = yarn-berry_4.fetchYarnBerryDeps {
    inherit src missingHashes;
    inherit (manifest.yarn) sha256;
  };

  nativeBuildInputs = [
    makeWrapper
    yarn-berry_4
    yarn-berry_4.yarnBerryConfigHook
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,lib}

    pushd packages/graphql-language-service-cli

    node esbuild.js --minify

    # copy package.json for --version command
    mv {out/graphql.js,package.json} $out/lib

    makeWrapper ${lib.getExe nodejs} $out/bin/graphql-lsp \
      --add-flags $out/lib/graphql.js \

    popd

    runHook postInstall
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;
  versionCheckProgram = "${placeholder "out"}/bin/${finalAttrs.meta.mainProgram}";

  passthru = {
    updateScript = ./update.py;
  };

  meta = {
    description = "Official, runtime independent Language Service for GraphQL";
    homepage = "https://github.com/graphql/graphiql";
    changelog = "https://github.com/graphql/graphiql/blob/${finalAttrs.src.tag}/packages/graphql-language-service-cli/CHANGELOG.md";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ nathanregner ];
    mainProgram = "graphql-lsp";
  };
})
