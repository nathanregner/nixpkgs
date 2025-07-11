{
  lib,
  python3,
  fetchFromGitHub,
  testers,
  krr,
  nix-update-script,
}:

python3.pkgs.buildPythonPackage rec {
  pname = "krr";
  version = "1.24.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "robusta-dev";
    repo = "krr";
    tag = "v${version}";
    hash = "sha256-2Kj94Co+4JV/ikLBUFqV4BdwFJSzvsbchf6As9U7LpQ=";
  };

  # postPatch = ''
  #   substituteInPlace robusta_krr/__init__.py \
  #     --replace-warn '1.7.0-dev' '${version}'
  #
  #   substituteInPlace pyproject.toml \
  #     --replace-warn '1.7.0-dev' '${version}' \
  #     --replace-fail 'aiostream = "^0.4.5"' 'aiostream = "*"' \
  #     --replace-fail 'kubernetes = "^26.1.0"' 'kubernetes = "*"' \
  #     --replace-fail 'pydantic = "1.10.7"' 'pydantic = "*"' \
  #     --replace-fail 'typer = { extras = ["all"], version = "^0.7.0" }' 'typer = { extras = ["all"], version = "*" }'
  # '';

  pythonRelaxDeps = [
    "idna"
    "kubernetes"
    "numpy"
    "pandas"
    "prometheus-api-client"
    "pydantic"
    "pyyaml"
    "requests"
    "setuptools"
    "typer"
    "typing-extensions"
    "urllib3"
  ];

  propagatedBuildInputs = with python3.pkgs; [
    poetry-core

    alive-progress
    idna
    kubernetes
    numpy
    pandas
    prometheus-api-client
    prometrix
    pydantic
    pyyaml
    requests
    setuptools
    slack-sdk
    tenacity
    typer
    typing-extensions
    urllib3
    zipp
  ];

  nativeCheckInputs = with python3.pkgs; [
    pytestCheckHook
  ];

  pythonImportsCheck = [
    "robusta_krr"
  ];

  passthru.updateScript = nix-update-script { };

  passthru.tests.version = testers.testVersion {
    package = krr;
    command = "krr version";
  };

  meta = with lib; {
    description = "Prometheus-based Kubernetes resource recommendations";
    longDescription = ''
      Robusta KRR (Kubernetes Resource Recommender) is a CLI tool for optimizing
      resource allocation in Kubernetes clusters. It gathers Pod usage data from
      Prometheus and recommends requests and limits for CPU and memory. This
      reduces costs and improves performance.
    '';
    homepage = "https://github.com/robusta-dev/krr";
    changelog = "https://github.com/robusta-dev/krr/releases/tag/v${src.rev}";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "krr";
  };
}
