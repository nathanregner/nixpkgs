jettyLog="$(mktemp)"
echo $jettyLog

pushd releng/third-party 1>/dev/null || {
    err_log "directory releng/third-party not found"
    exit 1
}
echo "$(date +%T) building p2:site - logging output to ${p2SiteLog}"
mvn p2:site

echo "$(date +%T) run jetty - logging output to ${jettyLog}"
mvn jetty:run | tee "${jettyLog}" &
JETTY_PID=$!

while ! grep -q "^\[INFO\] Started Server@" "${jettyLog}"; do
    echo "$(date +%T) waiting for jetty server to start"
    sleep 1
done
echo "$(date +%T) jetty server up and running on pid ${JETTY_PID}"

popd 1>/dev/null || {
    err_log "could not go to project root directory"
    exit 1
}
