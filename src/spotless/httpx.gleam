import gleam/bit_array
import gleam/http
import gleam/http/request
import gleam/json
import gleam/list
import gleam/string
import gleam/uri
import ogre/origin

pub type Challenge {
  Challenge(auth_schema: String, params: List(Param))
}

pub fn challenge_to_string(challenge) {
  let Challenge(auth_schema, params) = challenge
  let params = params |> list.map(param_to_string) |> string.join(", ")
  auth_schema <> " " <> params
}

pub type Param {
  Token68(String)
  Param(String, String)
}

fn param_to_string(param) {
  case param {
    Token68(token) -> token
    Param(key, value) -> key <> "=" <> value |> escape_quoted
  }
}

fn escape_quoted(string) {
  let content =
    string
    |> string.replace("\\", "\\\\")
    |> string.replace("\"", "\\\"")
  "\"" <> content <> "\""
}

pub fn with_basic_auth(request, username, password) {
  let str = <<username:utf8, ":", password:utf8>>
  let authorization = "Basic " <> bit_array.base64_encode(str, False)
  request
  |> request.set_header("authorization", authorization)
}

pub fn post(endpoint, content_type, body) {
  let #(origin, path) = endpoint

  origin.to_request(origin)
  |> request.set_method(http.Post)
  |> request.set_path(path)
  |> request.prepend_header("content-type", content_type)
  |> request.set_body(body)
}

pub fn post_form_params(endpoint, params) {
  let body = <<uri.query_to_string(params):utf8>>
  post(endpoint, "application/x-www-form-urlencoded", body)
}

pub fn post_json(endpoint, json) {
  let body = <<json.to_string(json):utf8>>
  post(endpoint, "application/json", body)
}
