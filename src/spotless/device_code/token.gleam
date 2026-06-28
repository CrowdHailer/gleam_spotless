import gleam/bit_array
import gleam/http/request
import gleam/list
import gleam/result
import gleam/uri
import spotless/httpx
import spotless/oauth_2_1/token

pub const grant_type = "urn:ietf:params:oauth:grant-type:device_code"

pub type Request {
  Request(client_id: String, device_code: String)
}

pub fn request_to_http(endpoint, device_request) {
  let Request(client_id:, device_code:) = device_request
  httpx.post_form_params(endpoint, [
    #("grant_type", grant_type),
    #("client_id", client_id),
    #("device_code", device_code),
  ])
}

pub fn request_from_http(request) {
  let request.Request(body:, ..) = request
  case bit_array.to_string(body) {
    Ok(body) ->
      case uri.parse_query(body) {
        Ok(params) -> request_from_params(params)
        Error(_) -> Error(#(token.InvalidRequest, "missing params"))
      }
    Error(_) -> Error(#(token.InvalidRequest, "not utf8"))
  }
}

pub fn request_from_params(params) {
  use #(client_id, params) <- result.try(key_pop(params, "client_id"))
  use #(device_code, _params) <- result.try(key_pop(params, "device_code"))
  Ok(Request(client_id:, device_code:))
}

fn key_pop(params, key) {
  list.key_pop(params, key)
  |> result.replace_error(#(token.InvalidRequest, "missing key " <> key))
}
