//// https://datatracker.ietf.org/doc/html/rfc9126#name-pushed-authorization-reques

import gleam/bit_array
import gleam/dynamic/decode
import gleam/http
import gleam/http/response
import gleam/int
import gleam/json
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import gleam/uri.{Uri}
import midas/task as t
import ogre/origin.{Origin}
import snag
import spotless/httpx
import spotless/oauth_2_1/authorization

pub fn do_request(endpoint, request) {
  let request = request_to_http(endpoint, request)
  use response <- t.do(t.fetch(request))

  let headers = response.headers
  let response = response_from_http(response)
  use response <- t.try(
    result.map_error(response, fn(reason) { snag.new(string.inspect(reason)) }),
  )
  t.done(#(response, headers))
}

pub fn request_to_http(endpoint, request) {
  httpx.post_form_params(endpoint, authorization.request_to_params(request))
}

pub type Response {
  Response(request_uri: String, expires_in: Int)
}

pub fn response_from_http(response) {
  let response.Response(status:, body:, ..) = response
  case status {
    201 ->
      case json.parse_bits(body, response_decoder()) {
        Ok(response) -> Ok(response)
        Error(reason) -> Error(string.inspect(reason))
      }
    code ->
      Error(
        "Returned status: "
        <> int.to_string(code)
        <> "\n"
        <> result.unwrap(bit_array.to_string(body), ""),
      )
  }
}

fn response_decoder() {
  use request_uri <- decode.field("request_uri", decode.string)
  use expires_in <- decode.field("expires_in", decode.int)
  decode.success(Response(request_uri:, expires_in:))
}

pub fn token_url(endpoint, client_id, request_uri) {
  let #(Origin(scheme, host, port), path) = endpoint
  let scheme = http.scheme_to_string(scheme)
  let query = [#("client_id", client_id), #("request_uri", request_uri)]
  let query = Some(uri.query_to_string(query))
  Uri(Some(scheme), None, Some(host), port, path, query, None)
}
