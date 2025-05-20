{
  fetchFromGitHub,
  graalvmPackages,
  installShellFiles,
  lib,
  makeWrapper,
  maven,
  mvnd,
  nix-update-script,
  runCommand,
  stdenv,
  testers,
}:

let
  platformMap = {
    aarch64-darwin = {
      os = "darwin";
      arch = "aarch64";
    };
    aarch64-linux = {
      os = "linux";
      arch = "aarch64";
    };
    x86_64-darwin = {
      os = "darwin";
      arch = "arm64";
    };
    x86_64-linux = {
      os = "linux";
      arch = "arm64";
    };
  };
  inherit (platformMap.${stdenv.hostPlatform.system}) os arch;
in

maven.buildMavenPackage rec {
  pname = "mvnd";
  version = "1.0.2";
  src = fetchFromGitHub {
    owner = "apache";
    repo = "maven-mvnd";
    rev = version;
    sha256 = "sha256-c1jD7m4cOdPWQEoaUMcNap2zvvX7H9VaWQv8JSgAnRU=";
  };
  patches = [ ./patches/0001-hack-remove-gmavenplus-plugin.patch ];

  # need graalvm at build-time for the `native-image` tool
  mvnJdk = graalvmPackages.graalvm-ce;
  mvnHash = "sha256-RvFFssd9PdU/k/PL+L+xJ/cy46vT+x6Hj212auj3Ipw=";

  nativeBuildInputs = [
    graalvmPackages.graalvm-ce
    installShellFiles
    makeWrapper
  ];

  mvnDepsParameters = mvnParameters;
  mvnParameters = lib.concatStringsSep " " [
    "-Dmaven.buildNumber.skip=true" # skip build number generation; requires a git repository
    "-Drat.skip=true" # skip license checks; they require manaul approval and should have already been run upstream
    "-Dspotless.skip=true" # skip formatting checks

    # normally the `gmavenplus` plugin would set these; do it ourselves so we
    # don't have to worry about it not supporting older versions of the JDK
    "-Dos.detected.name=${os}"
    "-Dos.detected.arch=${arch}"

    # skip tests that fail in the sandbox
    "-pl"
    "!integration-tests"
    "-Dtest=!org.mvndaemon.mvnd.client.OsUtilsTest,!org.mvndaemon.mvnd.cache.impl.CacheFactoryTest"
    "-Dsurefire.failIfNoSpecifiedTests=false"

    "-Pnative"
    # propagate linker args required by the darwin build
    # see `buildGraalvmNativeImage`
    ''-Dgraalvm-native-static-opt="-H:-CheckToolchain $(export -p | sed -n 's/^declare -x \([^=]\+\)=.*$/ -E\1/p' | tr -d \\n)"''
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    mkdir -p $out/mvnd-home

    cp -r dist/target/maven-mvnd-${version}-${os}-${arch}/* $out/mvnd-home
    makeWrapper $out/mvnd-home/bin/mvnd $out/bin/mvnd \
      --set-default MVND_HOME $out/mvnd-home

    installShellCompletion --cmd mvnd \
      --bash $out/mvnd-home/bin/mvnd-bash-completion.bash

    runHook postInstall
  '';

  passthru =
    {
      updateScript = nix-update-script { };
    }
    // (lib.optionalAttrs (!stdenv.hostPlatform.isDarwin) {
      tests.version = testers.testVersion {
        # `java` or `JAVA_HOME` is required to run mvnd
        # presumably the user already has a JDK installed if they're using maven; don't pull in an unnecessary runtime dependency
        package =
          runCommand "mvnd"
            {
              inherit version;
              nativeBuildInputs = [ makeWrapper ];
            }
            ''
              mkdir -p $out/bin
              makeWrapper${mvnd}/bin/mvnd $out/bin/mvnd \
                --suffix PATH : ${lib.makeBinPath [ mvnJdk ]}

            '';
      };
    });

  meta = {
    description = "The Apache Maven Daemon";
    homepage = "https://maven.apache.org/";
    license = lib.licenses.asl20;
    platforms = lib.platforms.unix;
    maintainers = with lib.maintainers; [ nathanregner ];
    mainProgram = "mvnd";
  };
}
