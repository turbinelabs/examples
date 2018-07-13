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

let server = require('../server')
let assert = require('assert')
let http = require('http')

describe('/', () => {
  beforeAll(() => {
    server.listen(8000)
  })

  afterAll(() => {
    server.close()
  })

  it('should return 200', done => {
    http.get('http://localhost:8000', res => {
      assert.equal(200, res.statusCode)
      done()
    })
  })

  it('return a hex color', done => {
    http.get('http://localhost:8000', res => {
      let data = ''

      res.on('data', chunk => {
        data = data + chunk
      })

      res.on('end', () => {
        data = data.trim()
        assert(data.length === 6)
        let color = parseInt('0x' + data)
        assert(color >= 0)
        assert(color <= 0xffffff + 1)
        done()
      })
    })
  })
})
