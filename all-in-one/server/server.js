/** @prettier */
/*
 * Copyright 2018 Turbine Labs, Inc.
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 * implied. See the License for the specific language governing
 * permissions and limitations under the License.
 */

let http = require('http')

let bodyColor = (process.env.TBN_COLOR || 'FFFAC3') + '\n'
let name = (process.env.TBN_NAME || 'unknown').toLowerCase()

// Box-Muller transform of uniformly distributed random numbers to
// normal distribution, discarding one of the produced values to avoid
// tracking state.
let nextRand = (mean, variance) => {
  let u1 = 0
  do {
    u1 = Math.random()
  } while (u1 <= Number.EPSILON)

  let u2 = 0
  do {
    u2 = Math.random()
  } while (u2 <= Number.EPSILON)

  let z0 = Math.sqrt(-2.0 * Math.log(u1)) * Math.cos(2.0 * Math.PI * u2)
  return z0 * variance + mean
}

let getDelay = meanDelay => {
  let delay = nextRand(meanDelay, meanDelay / 4.0)
  return Math.max(delay, 0)
}

let doRequest = (request, response, body, fail) => {
  let allowHeaders = request.headers['access-control-request-headers']

  let headers = {
    'Content-Length': fail ? 0 : Buffer.byteLength(body),
    'Access-Control-Allow-Origin': '*',
  }

  if (allowHeaders) {
    headers['Access-Control-Allow-Headers'] = allowHeaders
  }

  if (fail) {
    response.writeHead(500, headers)
    response.end()
  } else {
    response.writeHead(200, headers)
    response.end(body)
  }
}

let handleRequest = (request, response) => {
  let delay = 0
  let errorRate = 0

  if (name !== 'unknown') {
    let meanDelay = Number(request.headers['x-' + name + '-delay'] || '0')
    if (meanDelay > 0) {
      delay = getDelay(meanDelay)
    }

    errorRate = Number(request.headers['x-' + name + '-error'] || '0')
  }

  let fail = errorRate > 0 && Math.random() < errorRate

  console.log(
    'Request: ',
    request.url,
    (delay > 0 ? '; delay ' + delay + ' ms' : ''),
    (fail ? '; failing' : '; OK'),
  )

  if (delay > 0.0) {
    setTimeout(doRequest, delay, request, response, bodyColor, fail)
  } else {
    setImmediate(doRequest, request, response, bodyColor, fail)
  }
}

exports.server = http.createServer(handleRequest)
exports.listen = port => {
  exports.server.listen(port)
}

exports.close = callback => {
  exports.server.close(callback)
}
