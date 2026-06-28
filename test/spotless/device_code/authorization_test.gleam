import gleam/bit_array
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/list
import gleam/option.{Some}
import gleam/uri
import gleeunit/should
import ogre/origin
import spotless/device_code/device_authorization as device

pub fn request_to_http_test() {
  let request =
    device.Request(client_id: "http://localhost:8080", scope: ["repo", "user"])
    |> device.request_to_http(#(origin.https("spotless.run"), "/device"), _)

  request.method |> should.equal(http.Post)
  request.host |> should.equal("spotless.run")
  request.path |> should.equal("/device")
  let params =
    request.body
    |> bit_array.to_string
    |> should.be_ok
    |> uri.parse_query
    |> should.be_ok

  params
  |> list.key_find("client_id")
  |> should.be_ok
  |> should.equal("http://localhost:8080")
  params |> list.key_find("scope") |> should.be_ok |> should.equal("repo user")
}

pub fn request_from_http_test() {
  let request =
    request.new()
    |> request.set_body(<<
      "client_id=http%3A%2F%2Flocalhost%3A8080&scope=repo+user":utf8,
    >>)

  let device.Request(client_id:, scope:) =
    device.request_from_http(request)
    |> should.be_ok

  client_id |> should.equal("http://localhost:8080")
  scope |> should.equal(["repo", "user"])
}

pub fn response_from_http_test() {
  let response =
    response.Response(200, [], <<
      "{\"device_code\":\"device\",\"user_code\":\"ABCD\",\"verification_uri\":\"https://spotless.run/device\",\"verification_uri_complete\":\"https://spotless.run/device?user_code=ABCD\",\"expires_in\":600,\"interval\":5}":utf8,
    >>)

  let device.Response(
    device_code:,
    user_code:,
    verification_uri:,
    verification_uri_complete:,
    expires_in:,
    interval:,
  ) = device.response_from_http(response) |> should.be_ok |> should.be_ok

  device_code |> should.equal("device")
  user_code |> should.equal("ABCD")
  verification_uri |> should.equal("https://spotless.run/device")
  verification_uri_complete
  |> should.equal(Some("https://spotless.run/device?user_code=ABCD"))
  expires_in |> should.equal(600)
  interval |> should.equal(Some(5))
}
