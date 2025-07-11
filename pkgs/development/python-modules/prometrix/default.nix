{

  boto3,
  botocore,
  buildPythonPackage,
  fetchFromGitHub,
  fonttools,
  idna,
  lib,
  pillow,
  poetry-core,
  prometheus-api-client,
  pydantic,
  requests,
  urllib3,
  zipp,
}:

buildPythonPackage {
  pname = "prometrix";
  version = "0.2.1-unstable-2025-07-11";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "robusta-dev";
    repo = "prometrix";
    # https://github.com/robusta-dev/prometrix/issues/19
    rev = "b10e0b33ad65a915c2d408140528cd5003dee60f";
    hash = "sha256-mgAvY5q3tndqfd19seC9OuGzFAVCjdQGSm2pr1FcpLc=";
  };

  postPatch = ''
    cat <<EOF >>pyproject.toml
      [project]
      name = "prometrix"
    EOF
  '';

  pythonRelaxDeps = [
    "pillow"
    "prometheus-api-client"
    "pydantic"
    "urllib3"
  ];

  build-system = [ poetry-core ];

  dependencies = [
    boto3
    botocore
    fonttools
    idna
    pillow
    prometheus-api-client
    pydantic
    requests
    urllib3
    zipp
  ];

  pythonImportsCheck = [ "prometrix" ];

  meta = with lib; {
    description = "Unified Prometheus client";
    longDescription = ''
      This Python package provides a unified Prometheus client that can be used
      to connect to and query various types of Prometheus instances.
    '';
    homepage = "https://github.com/robusta-dev/prometrix";
    license = licenses.mit;
    maintainers = [ ];
    # prometheus-api-client 0.5.5 is not working
    # https://github.com/robusta-dev/prometrix/issues/14
  };
}
