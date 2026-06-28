import gleam/bit_array
import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/uri
import ogre/origin
import spotless/oauth_2_1/authorization

/// This is a device authorization request, which is structurally different and at a different endpoint to authorization request.
pub type Request {
  Request(client_id: String, scope: List(String))
}

pub fn request_to_http(endpoint, device_request) {
  let Request(client_id:, scope:) = device_request
  params_to_http(endpoint, [
    #("client_id", client_id),
    #("scope", scope |> string.join(" ")),
  ])
}

pub fn request_from_http(request) {
  let request.Request(body:, ..) = request
  case bit_array.to_string(body) {
    Ok(body) ->
      case uri.parse_query(body) {
        Ok(params) -> request_from_params(params)
        Error(_) -> Error(#(InvalidRequest, "missing params"))
      }
    Error(_) -> Error(#(InvalidRequest, "not utf8"))
  }
}

pub fn request_from_params(params) {
  use #(client_id, params) <- result.try(key_pop(params, "client_id"))
  let scope =
    list.key_find(params, "scope")
    |> result.unwrap("")
    |> authorization.split_scope()
  Ok(Request(client_id:, scope:))
}

fn params_to_http(endpoint, query) {
  let #(origin, path) = endpoint

  origin.to_request(origin)
  |> request.set_method(http.Post)
  |> request.set_path(path)
  |> request.prepend_header("content-type", "application/x-www-form-urlencoded")
  |> request.prepend_header("accept", "application/json")
  |> request.set_body(bit_array.from_string(uri.query_to_string(query)))
}

fn key_pop(params, key) {
  list.key_pop(params, key)
  |> result.replace_error(#(InvalidRequest, "missing key " <> key))
}

pub type Response {
  Response(
    device_code: String,
    user_code: String,
    verification_uri: String,
    verification_uri_complete: Option(String),
    expires_in: Int,
    interval: Option(Int),
  )
}

pub fn response_from_http(response) {
  case response {
    response.Response(status: 200, body:, ..) ->
      json.parse_bits(body, {
        use device_code <- decode.field("device_code", decode.string)
        use user_code <- decode.field("user_code", decode.string)
        use verification_uri <- decode.field("verification_uri", decode.string)
        use verification_uri_complete <- decode.optional_field(
          "verification_uri_complete",
          None,
          decode.map(decode.string, Some),
        )
        use expires_in <- decode.field("expires_in", decode.int)
        use interval <- decode.optional_field(
          "interval",
          None,
          decode.map(decode.int, Some),
        )
        decode.success(
          Ok(Response(
            device_code:,
            user_code:,
            verification_uri:,
            verification_uri_complete:,
            expires_in:,
            interval:,
          )),
        )
      })
    response.Response(body:, ..) ->
      json.parse_bits(body, {
        use error <- decode.field("error", decode.string)
        use error_description <- decode.optional_field(
          "error_description",
          None,
          decode.map(decode.string, Some),
        )
        decode.success(Error(ErrorResponse(error:, error_description:)))
      })
  }
}

pub fn response_to_body(response: Response) {
  let complete = case response.verification_uri_complete {
    Some(uri) -> [#("verification_uri_complete", json.string(uri))]
    None -> []
  }
  let interval = case response.interval {
    Some(interval) -> [#("interval", json.int(interval))]
    None -> []
  }

  list.append(complete, interval)
  |> list.append([
    #("device_code", json.string(response.device_code)),
    #("user_code", json.string(response.user_code)),
    #("verification_uri", json.string(response.verification_uri)),
    #("expires_in", json.int(response.expires_in)),
  ])
  |> json.object
  |> json.to_string
}

pub fn response_to_http(response) {
  response.new(200)
  |> response.set_body(response_to_body(response) |> bit_array.from_string)
}

pub type ErrorResponse {
  ErrorResponse(error: String, error_description: Option(String))
}

pub type Fail {
  InvalidRequest
  InvalidClient
  InvalidScope
}

pub fn error_code_to_string(code) {
  case code {
    InvalidRequest -> "invalid_request"
    InvalidClient -> "invalid_client"
    InvalidScope -> "invalid_scope"
  }
}
