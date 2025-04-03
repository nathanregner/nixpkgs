{
  coreutils,
  fetchFromGitHub,
  gnugrep,
  installShellFiles,
  lib,
  makeWrapper,
  maven,
  nix-update-script,
  stdenv,
}:

let
  platformMap = {
    aarch64-darwin = "darwin-aarch64";
    aarch64-linux = "linux-aarch64";
    x86_64-darwin = "darwin-amd64";
    x86_64-linux = "linux-amd64";
  };
in

maven.buildMavenPackage rec {
  pname = "jmc";
  version = "9.0.0";
  src = fetchFromGitHub {
    owner = "openjdk";
    repo = "jmc";
    tag = "${version}-ga";
    sha256 = "sha256-S3rv7ZC9XJfq80jK0qjqcDqhYp1He8pXySU859gcZaY=";
  };

  # need graalvm at build-time for the `native-image` tool
  # mvnJdk = graalvmPackages.graalvm-ce;
  mvnHash = "";

  nativeBuildInputs = [
    coreutils
    gnugrep
    installShellFiles
    makeWrapper
  ]
  # ++ lib.optionals stdenv.hostPlatform.isDarwin [ darwin.apple_sdk_11_0.frameworks.Foundation ]
  ;

  mvnDepsParameters = mvnParameters;
  mvnParameters = lib.concatStringsSep " " [
    "-s"
    ./settings.xml
    # "-Djetty.http.host=127.0.0.1"
    "-Dspotless.skip=true" # skip formatting checks
  ];

  goOffline = true;

  mvnFetchExtraArgs = {
    preBuild = ''
      ${./start-jetty.sh}
    '';
  };

  buildOffline = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    mkdir -p $out/mvnd-home

    cp -r dist/target/maven-mvnd-${version}-${platformMap.${stdenv.system}}/* $out/mvnd-home
    makeWrapper $out/mvnd-home/bin/mvnd $out/bin/mvnd \
      --set-default MVND_HOME $out/mvnd-home

    installShellCompletion --cmd mvnd \
      --bash $out/mvnd-home/bin/mvnd-bash-completion.bash

    runHook postInstall
  '';

  passthru = {
    updateScript = nix-update-script {
      extraArgs = [
        "--version-regex=^(.*)-ga"
      ];
    };
  };

  meta = {
    description = "Production time profiling and diagnostics tools suite for Java";
    homepage = "https://openjdk.org/projects/jmc/";
    license = lib.licenses.upl;
    platforms = lib.platforms.unix;
    maintainers = with lib.maintainers; [ nathanregner ];
    mainProgram = "jmc";
  };
}
