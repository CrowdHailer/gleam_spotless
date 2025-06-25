import gleam/http
import gleam/int
import gleam/option.{None}
import gleam/result
import gleam/string
import midas/task as t
import snag
import spotless/oauth_2_1 as oa
import spotless/oauth_2_1/authorization
import spotless/oauth_2_1/token
import spotless/proof_key_for_code_exchange as pkce

const origin = oa.Origin(http.Https, "spotless.run", None)

pub fn authenticate(service, scope, state, port, code_challenge_method) {
  let client_id = "http://localhost:" <> int.to_string(port)
  let redirect_uri = client_id <> "/"
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
  let endpoint = #(origin, "/authorize/" <> service)
  let url = authorization.request_to_url(endpoint, request)
  use redirect <- t.do(t.follow(url))
  use response <- t.try(authorization_response_from_uri(redirect))

  let request =
    token.Request(
      grant_type: token.AuthorizationCode,
      client_id:,
      code: response.code,
      code_verifier:,
    )

  use response <- t.do(
    t.fetch(token.request_to_http(#(origin, "/token"), request)),
  )
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

// Currently DNSimple don't use scopes
pub fn dnsimple(port) {
  use response <- t.do(authenticate("dnsimple", [], "", port, pkce.S256))
  t.done(response.access_token)
}

pub fn dropbox(port, scopes) {
  use response <- t.do(authenticate("dropbox", scopes, "", port, pkce.S256))
  t.done(response.access_token)
}

pub fn github(port, scopes) {
  use response <- t.do(authenticate("github", scopes, "", port, pkce.S256))
  t.done(response.access_token)
}

pub fn google(port, scopes) {
  use response <- t.do(authenticate("google", scopes, "", port, pkce.S256))
  t.done(response.access_token)
}

pub fn linkedin(port, scopes) {
  use response <- t.do(authenticate("linkedin", scopes, "", port, pkce.S256))
  t.done(response.access_token)
}

pub fn netlify(port, scopes) {
  use response <- t.do(authenticate("netlify", scopes, "", port, pkce.S256))
  t.done(response.access_token)
}

pub fn strava(port, scopes) {
  use response <- t.do(authenticate("strava", scopes, "", port, pkce.S256))
  t.done(response.access_token)
}

pub fn twitter(port, scopes) {
  use response <- t.do(authenticate("twitter", scopes, "", port, pkce.S256))
  t.done(response.access_token)
}

pub fn vimeo(port, scopes) {
  use response <- t.do(authenticate("vimeo", scopes, "", port, pkce.S256))
  t.done(response.access_token)
}
