import gleam/http/request
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/uri
import midas/continuation.{type Continuation as K}
import midas/effect
import non_empty_list.{type NonEmptyList}
import ogre/origin.{type Origin}
import spotless/context
import spotless/demonstrating_proof_of_possession as dpop
import spotless/oauth_2_1/authorization
import spotless/oauth_2_1/token
import spotless/proof_key_for_code_exchange as pkce
import spotless/pushed_authorization_request as par

pub type ClientType {
  Public
  Confidential(client_secret: String)
}

/// Metadata of an authorization server.
/// 
/// Names follow the RFC8414 specification.
/// Where a list of values is expected and a server does not support the feature, e.g. PKCE, add an empty list
pub type AuthorizationServer {
  AuthorizationServer(
    issuer: String,
    authorization_endpoint: #(Origin, String),
    token_endpoint: #(Origin, String),
    scopes_supported: List(String),
    pushed_authorization_request_endpoint: Option(#(#(Origin, String), Bool)),
    code_challenge_methods_supported: List(String),
  )
}

/// Configuration of a OAuth client
pub type App {
  App(
    client_type: ClientType,
    client_id: String,
    redirect_uris: NonEmptyList(uri.Uri),
  )
}

pub fn start(
  server: AuthorizationServer,
  client_id: String,
  redirect_uri: uri.Uri,
  scope: List(String),
  state: String,
  code_challenge_method: pkce.CodeChallengeMethod,
  context: context.Context(t, key),
) -> K(t, #(authorization.Request, String)) {
  let context.Context(strong_random:, hash:, ..) = context
  let AuthorizationServer(issuer: _, ..) = server

  use code_verifier <- continuation.then(pkce.create_code_verifier(
    strong_random,
  ))

  use code_challenge <- continuation.then(pkce.create_code_challenge(
    code_verifier,
    code_challenge_method,
    hash,
  ))
  let request =
    authorization.Request(
      client_id:,
      redirect_uri: uri.to_string(redirect_uri),
      code_challenge:,
      code_challenge_method:,
      scope:,
      state:,
      extra: [],
    )

  continuation.return(#(request, code_verifier))
}

pub fn add_parameter(request, key, value) {
  let authorization.Request(extra:, ..) = request
  authorization.Request(..request, extra: [#(key, value), ..extra])
}

/// Copy/Paste of main authorize function but without DPoP
/// and with state, iss returned
pub fn grant(redirect, server, app, code_verifier, fetch) {
  use response <- continuation.try(authorization_response_from_uri(redirect))

  let authorization.Response(result:, state:, iss:) = response

  case result {
    Ok(code) -> {
      use response <- continuation.try_then(get_token(
        code,
        server,
        app,
        code_verifier,
        fetch,
      ))
      continuation.done(#(response, state, iss))
    }
    Error(reason) -> continuation.fail(reason.error)
  }
}

/// Get a token response from a code.
/// This endpoint is more useful that the grant function as working out which app 
/// and token verifier should be used depend on getting back a valid, signed, state
pub fn get_token(
  code: String,
  server: AuthorizationServer,
  app: App,
  code_verifier: String,
  fetch: effect.Fetch(t),
) -> K(t, Result(token.Response, String)) {
  let AuthorizationServer(token_endpoint:, ..) = server
  let App(client_id:, ..) = app

  let request = token.AuthorizationCode(client_id:, code: code, code_verifier:)

  let request = token.authorization_code_to_http(token_endpoint, request)

  use response <- continuation.then(fetch(request))
  use response <- continuation.try(result.map_error(
    response,
    effect.describe_fetch_error,
  ))
  use response <- continuation.try(
    token_response_from_http(response) |> result.map_error(string.inspect),
  )
  case response {
    Ok(response) -> continuation.done(response)
    Error(token.ErrorResponse(error:, ..)) -> continuation.fail(error)
  }
}

pub fn authorize(
  server: AuthorizationServer,
  client_id: String,
  redirect_uri: uri.Uri,
  keypair: Option(effect.KeyPair(key)),
  scope: List(String),
  state: String,
  code_challenge_method: pkce.CodeChallengeMethod,
  context: context.Context(t, key),
) -> K(t, Result(token.Response, String)) {
  use #(request, code_verifier) <- continuation.then(start(
    server,
    client_id,
    redirect_uri,
    scope,
    state,
    code_challenge_method,
    context,
  ))
  let AuthorizationServer(
    pushed_authorization_request_endpoint:,
    authorization_endpoint:,
    token_endpoint:,
    ..,
  ) = server

  use #(url, nonce) <- continuation.try_then(
    case pushed_authorization_request_endpoint {
      Some(#(endpoint, _)) -> {
        use #(response, headers) <- continuation.try_then(par.do_request(
          endpoint,
          request,
          context.fetch,
        ))
        let par.Response(request_uri:, expires_in: _) = response
        let url = par.token_url(authorization_endpoint, client_id, request_uri)
        let nonce = list.key_find(headers, "dpop-nonce")
        continuation.done(#(url, nonce))
      }
      None -> {
        let url = authorization.request_to_url(authorization_endpoint, request)
        continuation.done(#(url, Error(Nil)))
      }
    },
  )

  use redirect <- continuation.try_then(context.follow(url))
  use response <- continuation.try(authorization_response_from_uri(redirect))
  use code <- continuation.try(
    response.result |> result.map_error(fn(reason) { reason.error }),
  )

  let request = token.AuthorizationCode(client_id:, code: code, code_verifier:)

  let request = token.authorization_code_to_http(token_endpoint, request)
  use request <- continuation.try_then(case keypair, nonce {
    Some(keypair), Ok(nonce) -> {
      use jwt <- continuation.then(dpop.jwt_for_request(
        request,
        keypair,
        Some(nonce),
        None,
        context,
      ))
      use jwt <- continuation.try(jwt)
      continuation.done(request.set_header(request, "dpop", jwt))
    }
    _, _ -> continuation.done(request)
  })

  use response <- continuation.then(context.fetch(request))
  use response <- continuation.try(result.map_error(
    response,
    effect.describe_fetch_error,
  ))
  use response <- continuation.try(
    token_response_from_http(response) |> result.map_error(string.inspect),
  )
  case response {
    Ok(response) -> continuation.done(response)
    Error(token.ErrorResponse(error:, ..)) -> continuation.fail(error)
  }
}

pub fn authorization_response_from_uri(redirect) {
  authorization.response_from_uri(redirect)
}

pub fn token_response_from_http(response) {
  token.response_from_http(response)
}
