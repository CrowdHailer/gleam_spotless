import gleam/bit_array
import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result.{try}
import gleam/string
import gleam/uri
import spotless/oauth_2_1 as oa

pub type Request {
  Request(
    grant_type: GrantType,
    client_id: String,
    // client_secret: String,
    code: String,
    code_verifier: String,
    // redirect_uri: String,
  )
}

pub type GrantType {
  AuthorizationCode
  RefreshToken
}

fn grant_type_to_string(grant_type) {
  case grant_type {
    AuthorizationCode -> "authorization_code"
    RefreshToken -> "refresh_token"
  }
}

fn grant_type_from_string(grant_type) {
  case grant_type {
    "authorization_code" -> Ok(AuthorizationCode)
    "refresh_token" -> Ok(RefreshToken)
    _ -> Error(#(InvalidGrant, "invalid grant_type"))
  }
}

fn request_to_params(request) {
  let Request(grant_type, client_id, code, code_verifier) = request
  [
    #("grant_type", grant_type_to_string(grant_type)),
    #("client_id", client_id),
    // #("client_secret", client_secret),
    #("code", code),
    #("code_verifier", code_verifier),
    // #("redirect_uri", redirect_uri),
  ]
}

pub fn request_to_http(endpoint, request) {
  let query = request_to_params(request)
  params_to_http(endpoint, query)
}

pub fn params_to_http(endpoint, query) {
  let #(oa.Origin(scheme, host, port), path) = endpoint
  let r =
    request.new()
    |> request.set_method(http.Post)
    |> request.set_scheme(scheme)
    |> request.set_host(host)
    |> request.set_path(path)
    |> request.prepend_header(
      "content-type",
      "application/x-www-form-urlencoded",
    )
    |> request.set_body(bit_array.from_string(uri.query_to_string(query)))
  case port {
    Some(port) -> request.set_port(r, port)
    None -> r
  }
}

pub fn request_from_http(request) {
  let request.Request(body:, ..) = request
  case uri.parse_query(body) {
    Ok(params) -> request_from_params(params)
    Error(_) -> Error(#(InvalidRequest, "missing params"))
  }
}

pub fn request_from_params(params) -> Result(Request, _) {
  use #(grant_type, params) <- try(key_pop(params, "grant_type"))

  use type_ <- try(grant_type_from_string(grant_type))
  case type_ {
    AuthorizationCode -> {
      use #(client_id, params) <- try(key_pop(params, "client_id"))
      use #(code, params) <- try(key_pop(params, "code"))
      use #(code_verifier, params) <- try(key_pop(params, "code_verifier"))
      use Nil <- try(case params {
        [] -> Ok(Nil)
        _ ->
          Error(#(InvalidRequest, "extra params: " <> string.inspect(params)))
      })
      Ok(Request(AuthorizationCode, client_id, code, code_verifier))
    }
    _ -> Error(#(UnsupportedGrantType, "grant_type must be authorization_code"))
  }
}

fn key_pop(params, key) {
  list.key_pop(params, key)
  |> result.replace_error(#(InvalidRequest, "missing key " <> key))
}

pub type Response {
  Response(
    access_token: String,
    token_type: String,
    expires_in: Option(Int),
    scope: List(String),
    refresh_token: Option(String),
  )
}

pub fn response_from_http(response) {
  case response {
    response.Response(status: 200, body:, ..) ->
      json.parse_bits(body, {
        use access_token <- decode.field("access_token", decode.string)
        use token_type <- decode.field("token_type", decode.string)
        use expires_in <- decode.optional_field(
          "expires_in",
          None,
          decode.map(decode.int, Some),
        )
        // use scope <- decode.optional_field(
        //   "scope",
        //   [],
        //   decode.map(decode.string, string.split(_, " ")),
        // )
        // TODO does optional field not like a missing field is it null on the field
        let scope = []
        use refresh_token <- decode.optional_field(
          "refresh_token",
          None,
          decode.map(decode.string, Some),
        )
        decode.success(Response(
          access_token,
          token_type,
          expires_in,
          scope,
          refresh_token,
        ))
      })
    _ -> todo
  }
}

pub fn response_to_body(response: Response) {
  // response.new(200)
  // |> response.set_header("Content-Type", "application/json")
  // |> response.set_body(
  json.to_string(
    json.object([
      #("access_token", json.string(response.access_token)),
      #("token_type", json.string(response.token_type)),
      // #("expires_in", json.int(response.expires_in)),
    // #("scope", json.string(response.scope)),
    // #("refresh_token", json.string(response.refresh_token)),
    ]),
    // ),
  )
}

pub type Fail {
  InvalidRequest
  InvalidClient
  InvalidGrant
  UnauthorizedClient
  UnsupportedGrantType
  InvalidScope
}

pub fn error_code_to_string(code) {
  case code {
    InvalidRequest -> "invalid_request"
    InvalidClient -> "invalid_client"
    InvalidGrant -> "invalid_grant"
    UnauthorizedClient -> "unauthorized_client"
    UnsupportedGrantType -> "unsupported_grant_type"
    InvalidScope -> "invalid_scope"
  }
}

pub fn error_code_from_string(string) {
  case string {
    "invalid_request" -> Ok(InvalidRequest)
    "invalid_client" -> Ok(InvalidClient)
    "invalid_grant" -> Ok(InvalidGrant)
    "unauthorized_client" -> Ok(UnauthorizedClient)
    "unsupported_grant_type" -> Ok(UnsupportedGrantType)
    "invalid_scope" -> Ok(InvalidScope)
    _ -> Error("unknown error code")
  }
}
