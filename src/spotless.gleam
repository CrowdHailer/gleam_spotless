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

const origin = oa.Origin(http.Https, "spotless.run", None)

pub fn authenticate(service, scope, state, port) {
  let client_id = "http://localhost:" <> int.to_string(port)
  let redirect_uri = client_id <> "/"
  let code_challenge = int.to_string(int.random(1_000_000_000))
  let code_challenge_method = authorization.Plain

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
      code_verifier: code_challenge,
    )

  use response <- t.do(
    t.fetch(token.request_to_http(#(origin, "/token"), request)),
  )
  use response <- t.try(token_response_from_http(response))
  t.done(response)
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

pub fn dnsimple(port) {
  use response <- t.do(authenticate("dnsimple", [], "", port))
  t.done(response.access_token)
}

pub fn github(port, scopes) {
  use response <- t.do(authenticate("github", scopes, "", port))
  t.done(response.access_token)
}

pub fn netlify(port, scopes) {
  use response <- t.do(authenticate("netlify", scopes, "", port))
  t.done(response.access_token)
}

pub fn vimeo(port, scopes) {
  use response <- t.do(authenticate("vimeo", scopes, "", port))
  t.done(response.access_token)
}
