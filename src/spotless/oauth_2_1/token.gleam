import gleam/bit_array
import gleam/dynamic/decode
import gleam/http/request
import gleam/http/response
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result.{try}
import gleam/uri
import ogre/origin
import spotless/httpx

pub type AuthorizationCode {
  AuthorizationCode(
    client_id: String,
    // client_secret: String,
    code: String,
    code_verifier: String,
    // needed for atproto
    // redirect_uri: String,
  )
}

fn authorization_code_to_params(request) {
  let AuthorizationCode(client_id, code, code_verifier) = request
  [
    #("grant_type", "authorization_code"),
    #("client_id", client_id),
    // #("client_secret", client_secret),
    #("code", code),
    #("code_verifier", code_verifier),
    // See https://datatracker.ietf.org/doc/html/draft-ietf-oauth-v2-1#redirect-uri-in-token-request
  // redirect uri is not part of the OAuth 2.1 token request
  // #("redirect_uri", redirect_uri),
  ]
}

pub fn authorization_code_to_http(
  endpoint: #(origin.Origin, String),
  request: AuthorizationCode,
) -> request.Request(BitArray) {
  httpx.post_form_params(endpoint, authorization_code_to_params(request))
  |> request.prepend_header("accept", "application/json")
}

/// Unconstrained set of parameters to a token request, must include grant_type to be valid.
@deprecated("use httpx.post_form_params instead")
pub fn params_to_http(endpoint, params) {
  httpx.post_form_params(endpoint, params)
  |> request.prepend_header("accept", "application/json")
}

pub fn request_from_http(request) {
  let request.Request(body:, ..) = request
  case bit_array.to_string(body) {
    Ok(body) ->
      case uri.parse_query(body) {
        Ok(params) -> key_pop(params, "grant_type")
        // request_from_params(params, redirect_uri)
        Error(_) -> Error(#(InvalidRequest, "missing params"))
      }
    Error(_) -> Error(#(InvalidRequest, "not utf8"))
  }
}

// pub fn request_from_params(params, redirect_uri) -> Result(Request, _) {
//   use #(grant_type, params) <- try(key_pop(params, "grant_type"))

//   use type_ <- try(grant_type_from_string(grant_type))
//   case type_ {
//     AuthorizationCode -> todo
//     _ -> Error(#(UnsupportedGrantType, "grant_type must be authorization_code"))
//   }
// }

pub fn authorization_code_from_params(params) {
  {
    use #(client_id, params) <- try(key_pop(params, "client_id"))
    use #(code, params) <- try(key_pop(params, "code"))
    use #(code_verifier, _params) <- try(key_pop(params, "code_verifier"))
    // The client MUST ignore unrecognized response parameters
    // use Nil <- try(case params {
    //   [] -> Ok(Nil)
    //   _ ->
    //     Error(#(InvalidRequest, "extra params: " <> string.inspect(params)))
    // })
    Ok(AuthorizationCode(client_id, code, code_verifier))
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
        decode.success(
          Ok(Response(
            access_token,
            token_type,
            expires_in,
            scope,
            refresh_token,
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
        use error_uri <- decode.optional_field(
          "error_uri",
          None,
          decode.map(decode.string, Some),
        )
        decode.success(
          Error(ErrorResponse(error:, error_description:, error_uri:)),
        )
      })
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

pub type ErrorResponse {
  ErrorResponse(
    error: String,
    error_description: Option(String),
    error_uri: Option(String),
  )
}

pub fn error_response_to_http(response) -> response.Response(BitArray) {
  let ErrorResponse(error:, error_description:, error_uri:) = response
  let data =
    json.object([
      #("error", json.string(error)),
      #("error_description", json.nullable(error_description, json.string)),
      #("error_uri", json.nullable(error_uri, json.string)),
    ])
  response.new(400)
  |> response.set_header("content-type", "application/json")
  |> response.set_body(<<json.to_string(data):utf8>>)
}

pub fn error_response_from_http(response) {
  let response.Response(body:, ..) = response
  json.parse_bits(body, token_error_response_decoder())
}

pub fn token_error_response_decoder() {
  use error <- decode.field("error", decode.string)
  use error_description <- decode.optional_field(
    "error_description",
    None,
    decode.optional(decode.string),
  )
  use error_uri <- decode.optional_field(
    "error_uri",
    None,
    decode.optional(decode.string),
  )
  decode.success(ErrorResponse(error:, error_description:, error_uri:))
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
