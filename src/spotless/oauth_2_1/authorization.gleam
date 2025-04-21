import gleam/http
import gleam/http/request
import gleam/list
import gleam/option.{None, Some}
import gleam/result.{try}
import gleam/string
import gleam/uri.{Uri}
import spotless/oauth_2_1 as oa

pub type Request {
  Request(
    // Not included as always "code"
    // response_type:
    client_id: String,
    // not optional as I am not using confidential clients
    code_challenge: String,
    code_challenge_method: CodeChallengeMethod,
    // optional but we always send it and require it for unregistered clients
    redirect_uri: String,
    // optionality represented by empty list
    scope: List(String),
    // optional
    state: String,
  )
}

pub type CodeChallengeMethod {
  Plain
  S256
}

fn code_challenge_method_to_string(method) {
  case method {
    Plain -> "plain"
    S256 -> "S256"
  }
}

fn code_challenge_method_from_string(raw) -> Result(CodeChallengeMethod, _) {
  case raw {
    "plain" -> Ok(Plain)
    "S256" -> Ok(S256)
    _ -> Error(#(InvalidRequest, "unknown code challenge method " <> raw))
  }
}

pub fn request_to_params(request) {
  let Request(
    client_id:,
    code_challenge:,
    code_challenge_method:,
    redirect_uri:,
    scope:,
    state:,
  ) = request
  [
    #("response_type", "code"),
    #("client_id", client_id),
    #("code_challenge", code_challenge),
    #(
      "code_challenge_method",
      code_challenge_method_to_string(code_challenge_method),
    ),
    #("redirect_uri", redirect_uri),
    #("scope", string.join(scope, " ")),
    #("state", state),
  ]
}

pub fn request_to_url(endpoint, request) {
  let #(oa.Origin(scheme, host, port), path) = endpoint
  let scheme = http.scheme_to_string(scheme)
  let query = request_to_params(request)
  let query = Some(uri.query_to_string(query))
  Uri(Some(scheme), None, Some(host), port, path, query, None)
  |> uri.to_string
}

pub fn request_from_http(request) {
  case request.get_query(request) {
    Ok(params) -> request_from_params(params)
    Error(_) -> Error(#(InvalidRequest, "missing params"))
  }
}

pub fn request_from_params(params) -> Result(Request, _) {
  use #(response_type, params) <- try(key_pop(params, "response_type"))
  use _ <- try(case response_type {
    "code" -> Ok(Nil)
    _ -> Error(#(UnsupportedResponseType, "response_type must be code"))
  })
  use #(client_id, params) <- try(key_pop(params, "client_id"))
  use #(code_challenge, params) <- try(key_pop(params, "code_challenge"))
  use #(raw, params) <- try(key_pop(params, "code_challenge_method"))
  use method <- try(code_challenge_method_from_string(raw))
  use #(redirect_uri, params) <- try(key_pop(params, "redirect_uri"))
  let #(scope, params) = case list.key_pop(params, "scope") {
    Ok(#(scope, params)) -> #(string.split(scope, " "), params)
    Error(_) -> #([], params)
  }
  use #(state, params) <- try(key_pop(params, "state"))
  use Nil <- try(case params {
    [] -> Ok(Nil)
    _ -> Error(#(InvalidRequest, "extra params: " <> string.inspect(params)))
  })
  Ok(Request(client_id, code_challenge, method, redirect_uri, scope, state))
}

fn key_pop(params, key) {
  list.key_pop(params, key)
  |> result.replace_error(#(InvalidRequest, "missing key " <> key))
}

pub type Response {
  Response(code: String, state: String)
}

pub fn response_to_params(response) {
  let Response(code, state) = response
  [#("code", code), #("state", state)]
}

pub fn response_to_url(endpoint, response) {
  let #(oa.Origin(scheme, host, port), path) = endpoint
  let scheme = http.scheme_to_string(scheme)
  let query = response_to_params(response)
  let query = Some(uri.query_to_string(query))
  Uri(Some(scheme), None, Some(host), port, path, query, None)
  |> uri.to_string
}

pub fn response_from_params(params) {
  use #(code, params) <- try(key_pop(params, "code"))
  use #(state, params) <- try(key_pop(params, "state"))
  use Nil <- try(case params {
    [] -> Ok(Nil)
    _ -> Error(#(InvalidRequest, "extra params"))
  })
  Ok(Response(code, state))
}

pub fn response_from_uri(uri) {
  let uri.Uri(query:, ..) = uri
  case uri.parse_query(query |> option.unwrap("")) {
    Ok(params) -> response_from_params(params)
    Error(_) -> Error(#(InvalidRequest, "invalid query"))
  }
}

pub fn response_from_http(request) {
  case request.get_query(request) {
    Ok(params) -> response_from_params(params)
    Error(_) -> Error(#(InvalidRequest, "invalid query"))
  }
}

pub type Fail {
  Fail(code: Code, description: String, uri: String, state: String)
}

pub type Code {
  InvalidRequest
  UnauthorizedClient
  AccessDenied
  UnsupportedResponseType
  InvalidScope
  ServerError
  TemporarilyUnavailable
}

pub fn error_code_to_string(code) {
  case code {
    InvalidRequest -> "invalid_request"
    UnauthorizedClient -> "unauthorized_client"
    AccessDenied -> "access_denied"
    UnsupportedResponseType -> "unsupported_response_type"
    InvalidScope -> "invalid_scope"
    ServerError -> "server_error"
    TemporarilyUnavailable -> "temporarily_unavailable"
  }
}

pub fn error_code_from_string(raw) {
  case raw {
    "invalid_request" -> Ok(InvalidRequest)
    "unauthorized_client" -> Ok(UnauthorizedClient)
    "access_denied" -> Ok(AccessDenied)
    "unsupported_response_type" -> Ok(UnsupportedResponseType)
    "invalid_scope" -> Ok(InvalidScope)
    "server_error" -> Ok(ServerError)
    "temporarily_unavailable" -> Ok(TemporarilyUnavailable)
    _ -> Error("invalid error code")
  }
}
