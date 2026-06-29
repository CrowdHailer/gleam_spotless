import gleam/http
import gleam/http/request
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result.{try}
import gleam/string
import gleam/uri.{Uri}
import ogre/origin.{Origin}
import spotless/proof_key_for_code_exchange as pkce

pub type Request {
  Request(
    // Not included as always "code"
    // response_type:
    client_id: String,
    // not optional as I am not using confidential clients
    code_challenge: String,
    code_challenge_method: pkce.CodeChallengeMethod,
    // optional but we always send it and require it for unregistered clients
    redirect_uri: String,
    // optionality represented by empty list
    scope: List(String),
    // optional
    state: String,
    extra: List(#(String, String)),
  )
}

pub fn request_to_params(request) {
  let Request(
    client_id:,
    code_challenge:,
    code_challenge_method:,
    redirect_uri:,
    scope:,
    state:,
    extra:,
  ) = request
  [
    #("response_type", "code"),
    #("client_id", client_id),
    #("code_challenge", code_challenge),
    #(
      "code_challenge_method",
      pkce.code_challenge_method_to_string(code_challenge_method),
    ),
    #("redirect_uri", redirect_uri),
    #("scope", string.join(scope, " ")),
    #("state", state),
    ..extra
  ]
}

pub fn request_to_url(endpoint, request) {
  let #(Origin(scheme, host, port), path) = endpoint
  let scheme = http.scheme_to_string(scheme)
  let query = request_to_params(request)
  let query = Some(uri.query_to_string(query))
  Uri(Some(scheme), None, Some(host), port, path, query, None)
}

pub fn request_to_http(endpoint, request) {
  let #(origin, path) = endpoint

  origin.to_request(origin)
  |> request.set_path(path)
  |> request.set_query(request_to_params(request))
  |> request.set_body(<<>>)
}

// Used by an OAuth server to turn an incoming HTTP request into a `AuthorizationRequest`.
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
  let #(raw, params) =
    key_pop(params, "code_challenge_method")
    |> result.unwrap(#("plain", params))

  use code_challenge_method <- try(
    pkce.code_challenge_method_from_string(raw)
    |> result.replace_error(#(
      InvalidRequest,
      "unknown code challenge method " <> raw,
    )),
  )
  use #(redirect_uri, params) <- try(key_pop(params, "redirect_uri"))
  let #(scope, params) = case list.key_pop(params, "scope") {
    Ok(#(scope, params)) -> #(split_scope(scope), params)
    Error(_) -> #([], params)
  }
  let #(state, extra) = key_pop(params, "state") |> result.unwrap(#("", []))
  // The client MUST ignore unrecognized response parameters
  // use Nil <- try(case params {
  //   [] -> Ok(Nil)
  //   _ -> Error(#(InvalidRequest, "extra params: " <> string.inspect(params)))
  // })
  Ok(Request(
    client_id:,
    code_challenge:,
    code_challenge_method:,
    redirect_uri:,
    scope:,
    state:,
    extra:,
  ))
}

/// split a uri encoded list of scopes to a list of scopes
pub fn split_scope(scope: String) -> List(String) {
  case string.trim(scope) {
    "" -> []
    _ -> string.split(scope, " ")
  }
}

// this function only works for request.
fn key_pop(params, key) {
  list.key_pop(params, key)
  |> result.replace_error(#(InvalidRequest, "missing key " <> key))
}

pub type Response {
  Response(
    result: Result(String, ErrorResponse),
    state: Option(String),
    iss: Option(String),
  )
}

pub type ErrorResponse {
  ErrorResponse(
    error: String,
    error_description: Option(String),
    error_uri: Option(String),
  )
}

pub fn response_to_params(response) {
  let Response(result:, state:, iss:) = response
  let params = case result {
    Ok(code) -> [#("code", code)]
    Error(ErrorResponse(error:, error_description:, error_uri:)) -> {
      let params = [#("error", error)]
      let params = case error_description {
        Some(error_description) ->
          list.append(params, [#("error_description", error_description)])
        None -> params
      }
      case error_uri {
        Some(error_uri) -> list.append(params, [#("error_uri", error_uri)])
        None -> params
      }
    }
  }
  let params = case state {
    Some(state) -> list.append(params, [#("state", state)])
    None -> params
  }
  case iss {
    Some(iss) -> list.append(params, [#("iss", iss)])
    None -> params
  }
}

/// Turn the authorization response into the redirect uri.
pub fn response_to_uri(endpoint, response) {
  let #(Origin(scheme, host, port), path) = endpoint
  let scheme = http.scheme_to_string(scheme)
  let query = response_to_params(response)
  let query = Some(uri.query_to_string(query))
  Uri(Some(scheme), None, Some(host), port, path, query, None)
}

pub fn response_to_http(endpoint, response) {
  let #(origin, path) = endpoint

  origin.to_request(origin)
  |> request.set_path(path)
  |> request.set_query(response_to_params(response))
  |> request.set_body(<<>>)
}

/// Turn the authorization response into the redirect uri.
@deprecated("use response_to_uri")
pub fn response_to_url(endpoint, response) {
  response_to_uri(endpoint, response)
  |> uri.to_string
}

// The client MUST ignore unrecognized response parameters
pub fn response_from_params(
  params: List(#(String, String)),
) -> Result(Response, String) {
  case list.key_pop(params, "error") {
    Ok(#(error, params)) -> {
      let error_description =
        list.key_find(params, "error_description")
        |> option.from_result
      let error_uri =
        list.key_find(params, "error_uri")
        |> option.from_result
      let state =
        list.key_find(params, "state")
        |> option.from_result
      let iss =
        list.key_find(params, "iss")
        |> option.from_result

      Ok(Response(
        Error(ErrorResponse(error:, error_description:, error_uri:)),
        state:,
        iss:,
      ))
    }
    Error(Nil) -> {
      use #(code, params) <- try(
        list.key_pop(params, "code") |> result.replace_error("missing code"),
      )
      use #(state, params) <- try(
        list.key_pop(params, "state") |> result.replace_error("missing state"),
      )
      let iss =
        list.key_find(params, "iss")
        |> option.from_result
      Ok(Response(Ok(code), Some(state), iss))
    }
  }
}

pub fn response_from_uri(uri) {
  let uri.Uri(query:, ..) = uri
  case uri.parse_query(query |> option.unwrap("")) {
    Ok(params) -> response_from_params(params)
    Error(_) -> Error("invalid query")
  }
}

// Used by a client to handle the redirect from an authorization server.
pub fn response_from_http(request) {
  case request.get_query(request) {
    Ok(params) -> response_from_params(params)
    Error(_) -> Error("invalid query")
  }
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
    _ -> Error(Nil)
  }
}
