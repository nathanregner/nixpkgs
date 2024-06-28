{
  darwin,
  fetchFromGitHub,
  graalvmCEPackages,
  installShellFiles,
  jdk,
  lib,
  makeWrapper,
  maven,
  mvnd,
  nix-update-script,
  stdenv,
  testers,
}:

assert jdk != null;

let
  platformMap = {
    aarch64-darwin = "darwin-aarch64";
    aarch64-linux = "linux-aarch64";
    x86_64-darwin = "darwin-amd64";
    x86_64-linux = "linux-amd64";
  };
in

maven.buildMavenPackage rec {
  pname = "mvnd";
  version = "1.0.1";
  src = fetchFromGitHub {
    owner = "apache";
    repo = "maven-mvnd";
    rev = version;
    fetchSubmodules = false;
    sha256 = "sha256-93WmyIYmJAyuU1kmZlv1HKIv7KNquOe8vkWUvHpgTFU=";
  };

  manualMvnArtifacts = [
    "org.apache.apache.resources:apache-jar-resource-bundle:1.5"
    "org.apache.maven.surefire:surefire-junit-platform:3.2.5:jar"
    "org.apache.maven:apache-maven:3.9.8:tar.gz:bin"
    "org.apache.maven:maven-slf4j-provider:3.9.8:jar:sources"
    "org.graalvm.buildtools:graalvm-reachability-metadata:0.10.2:zip:repository"
    "org.graalvm.buildtools:native-maven-plugin:0.10.2"
  ];

  mvnHash = "sha256-kBQQWmvAkxB8/Tvcp5VR/OC6mFwPh8A8XXdAIg7TYuQ=";

  buildOffline = true;

  nativeBuildInputs = [
    graalvmCEPackages.graalvm-ce
    installShellFiles
    makeWrapper
  ] ++ lib.optionals stdenv.isDarwin [ darwin.apple_sdk.frameworks.Foundation ];

  mvnParameters = lib.concatStringsSep " " [
    "-Dmaven.buildNumber.skip=true" # skip build number generation; requires a git repository
    "-Drat.skip=true" # skip license checks; they require manaul approval and should have already been run upstream
    "-Dspotless.skip=true" # skip formatting checks

    "-pl"
    "!integration-tests" # skip tests requiring network acccess

    "-Dtest=!org.mvndaemon.mvnd.client.OsUtilsTest,!org.mvndaemon.mvnd.cache.impl.CacheFactoryTest.timestampCache" # not happy in the sandbox
    "-Dsurefire.failIfNoSpecifiedTests=false"

    "-Pnative"
    # Propagate linker args required by the darwin build
    # > Pass the whole environment to the native-image build process by
    # > generating a -E option for every environment variable.
    # source: `buildGraalvmNativeImage`
    ''-Dgraalvm-native-static-opt="-H:-CheckToolchain $(export -p | sed -n 's/^declare -x \([^=]\+\)=.*$/ -E\1/p' | tr -d \\n)"''
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    mkdir -p $out/mvnd-home

    cp -r dist/target/maven-mvnd-${version}-${platformMap.${stdenv.system}}/* $out/mvnd-home
    makeWrapper $out/mvnd-home/bin/mvnd $out/bin/mvnd \
      --set-default JAVA_HOME "${jdk}" \
      --set-default MVND_HOME $out/mvnd-home

    installShellCompletion --cmd mvnd \
      --bash $out/mvnd-home/bin/mvnd-bash-completion.bash

    runHook postInstall
  '';

  passthru = {
    tests.version = testers.testVersion { package = mvnd; };
    updateScript = nix-update-script { };
  };

  meta = with lib; {
    description = "The Apache Maven Daemon";
    homepage = "https://maven.apache.org/";
    license = licenses.asl20;
    platforms = platforms.unix;
    maintainers = with maintainers; [ nathanregner ];
    mainProgram = "mvnd";
  };
}
