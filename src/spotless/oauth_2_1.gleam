import gleam/result
import gleam/string
import midas/task as t
import snag
import spotless/oauth_2_1/authorization
import spotless/oauth_2_1/token
import spotless/origin.{type Origin}
import spotless/proof_key_for_code_exchange as pkce

pub type ClientType {
  Public
  Confidential(client_secret: String)
}

pub type AuthorizationServer {
  AuthorizationServer(
    issuer: String,
    authorization_endpoint: #(Origin, String),
    token_endpoint: #(Origin, String),
  )
}

pub type App {
  App(client_type: ClientType, client_id: String, redirect_uri: String)
}

pub fn authorize(server, app, scope, state, code_challenge_method) {
  let AuthorizationServer(issuer: _, authorization_endpoint:, token_endpoint:) =
    server
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
  let url = authorization.request_to_url(authorization_endpoint, request)
  use redirect <- t.do(t.follow(url))
  use response <- t.try(authorization_response_from_uri(redirect))

  let request =
    token.Request(
      grant_type: token.AuthorizationCode,
      client_id:,
      code: response.code,
      code_verifier:,
    )

  use response <- t.do(t.fetch(token.request_to_http(token_endpoint, request)))
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
