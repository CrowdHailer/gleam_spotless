import gleam/http/request
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/uri
import midas/task as t
import snag
import spotless/demonstrating_proof_of_possession as dpop
import spotless/oauth_2_1/authorization
import spotless/oauth_2_1/token
import spotless/origin.{type Origin}
import spotless/proof_key_for_code_exchange as pkce
import spotless/pushed_authorization_request as par

pub type ClientType {
  Public
  Confidential(client_secret: String)
}

pub type AuthorizationServer {
  AuthorizationServer(
    issuer: String,
    authorization_endpoint: #(Origin, String),
    token_endpoint: #(Origin, String),
    pushed_authorization_request_endpoint: Option(#(#(Origin, String), Bool)),
  )
}

pub type App {
  App(client_type: ClientType, client_id: String, redirect_uri: String)
}

pub fn authorize(server, app, keypair, scope, state, code_challenge_method) {
  let AuthorizationServer(
    issuer: _,
    authorization_endpoint:,
    token_endpoint:,
    pushed_authorization_request_endpoint:,
  ) = server
  let App(client_type: _, client_id:, redirect_uri:) = app

  use code_verifier <- t.do(pkce.create_code_verifier())
  use code_challenge <- t.do(pkce.create_code_challenge(
    code_verifier,
    code_challenge_method,
  ))
  let request =
    authorization.Request(
      client_id:,
      redirect_uri:,
      code_challenge:,
      code_challenge_method:,
      scope:,
      state:,
    )
  use #(url, nonce) <- t.do(case pushed_authorization_request_endpoint {
    Some(#(endpoint, _)) -> {
      use #(response, headers) <- t.do(par.do_request(endpoint, request))
      let par.Response(request_uri:, expires_in: _) = response
      let url = par.token_url(authorization_endpoint, client_id, request_uri)
      let nonce = list.key_find(headers, "dpop-nonce")
      t.done(#(url, nonce))
    }
    None -> {
      let url = authorization.request_to_url(authorization_endpoint, request)
      t.done(#(url, Error(Nil)))
    }
  })
  let url = uri.to_string(url)
  use redirect <- t.do(t.follow(url))
  use response <- t.try(authorization_response_from_uri(redirect))

  let request =
    token.Request(
      grant_type: token.AuthorizationCode,
      client_id:,
      code: response.code,
      code_verifier:,
      redirect_uri:,
    )

  let request = token.request_to_http(token_endpoint, request)
  use request <- t.do(case keypair, nonce {
    Some(keypair), Ok(nonce) -> {
      use jwt <- t.do(dpop.jwt_for_request(request, keypair, Some(nonce), None))
      t.done(request.set_header(request, "dpop", jwt))
    }
    _, _ -> t.done(request)
  })

  use response <- t.do(t.fetch(request))
  use response <- t.try(token_response_from_http(response))
  case response {
    Ok(response) -> t.done(response)
    Error(token.ErrorResponse(error:, ..)) ->
      t.abort(snag.new(error) |> snag.layer("failed to fetch token"))
  }
}

fn authorization_response_from_uri(redirect) {
  authorization.response_from_uri(redirect)
  |> result.map_error(fn(error) {
    let #(_reason, description) = error
    snag.new(description)
  })
}

fn token_response_from_http(response) {
  token.response_from_http(response)
  |> result.map_error(fn(error) { snag.new(string.inspect(error)) })
}
