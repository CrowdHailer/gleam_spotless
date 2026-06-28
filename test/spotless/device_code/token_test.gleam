import gleeunit/should
import ogre/origin
import spotless/device_code/token

pub fn request_from_http_test() {
  let request =
    token.Request(client_id: "http://localhost:8080", device_code: "device")
    |> token.request_to_http(#(origin.https("spotless.run"), "/token"), _)

  let token.Request(client_id:, device_code:) =
    token.request_from_http(request)
    |> should.be_ok

  client_id |> should.equal("http://localhost:8080")
  device_code |> should.equal("device")
}
