from flask import Flask
from flask import request
import socket
import os
import sys
import requests

app = Flask(__name__)

TRACE_HEADERS_TO_PROPAGATE = [
    'X-Ot-Span-Context',
    'X-Request-Id',

    # Zipkin headers
    'X-B3-TraceId',
    'X-B3-SpanId',
    'X-B3-ParentSpanId',
    'X-B3-Sampled',
    'X-B3-Flags',

    # Jaeger header (for native client)
    "uber-trace-id"
]

@app.route('/service/<service_number>')
def hello(service_number):
    return ('Hello from minikube (service {})! hostname: {} resolved'
            'hostname: {}\n'.format(os.environ['SERVICE_NAME'],
                                    socket.gethostname(),
                                    socket.gethostbyname(socket.gethostname())))

@app.route('/trace/<service_number>')
def trace(service_number):
    headers = {}
    # call service 2 from service 1
    ret = 'nothing upstream'
    if int(os.environ['SERVICE_NAME']) == 1 :
        for header in TRACE_HEADERS_TO_PROPAGATE:
            if header in request.headers:
                headers[header] = request.headers[header]

        # Setting this host header may be done in some services, depending on
        # how abstract your service discovery is right now
        headers['host'] = 'demo.turbinelabs.io'
        ret = requests.get("http://localhost:8888/api/", headers=headers).text

    return ('Hello from minikube -- {} (service {})! hostname: {} resolved'
            'hostname: {}\n'.format(ret,
                                    os.environ['SERVICE_NAME'],
                                    socket.gethostname(),
                                    socket.gethostbyname(socket.gethostname())))

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=8080, debug=True)
