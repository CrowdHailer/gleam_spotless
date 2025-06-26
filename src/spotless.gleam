import gleam/http
import gleam/int
import gleam/option.{None, Some}
import midas/task as t
import spotless/oauth_2_1 as oa
import spotless/origin.{Origin}
import spotless/proof_key_for_code_exchange as pkce

pub fn authenticate(service, scope, state, port, code_challenge_method) {
  let origin = Origin(http.Https, "spotless.run", None)
  let client_id = "http://localhost:" <> int.to_string(port)
  let redirect_uri = client_id <> "/"

  let server =
    oa.AuthorizationServer(
      issuer: "https://spotless.run",
      authorization_endpoint: #(origin, "/authorize/" <> service),
      token_endpoint: #(origin, "/token"),
      pushed_authorization_request_endpoint: None,
    )
  let app = oa.App(oa.Public, client_id, redirect_uri)

  oa.authorize(server, app, None, scope, state, code_challenge_method)
}

pub fn bsky(port, scope, state, keypair) {
  // If state is empty string that value is not returned from oauth server
  let origin = Origin(http.Https, "bsky.social", None)
  // No port on client id
  let client_id =
    "http://localhost?scope=atproto%20transition:generic%20transition:email%20transition:chat.bsky"
  let redirect_uri = "http://127.0.0.1:" <> int.to_string(port) <> "/"

  let server =
    oa.AuthorizationServer(
      issuer: "https://bsky.social",
      authorization_endpoint: #(origin, "/oauth/authorize"),
      token_endpoint: #(origin, "/oauth/token"),
      pushed_authorization_request_endpoint: Some(#(
        #(origin, "/oauth/par"),
        True,
      )),
    )
  let app = oa.App(oa.Public, client_id, redirect_uri)

  oa.authorize(server, app, Some(keypair), scope, state, pkce.S256)
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
