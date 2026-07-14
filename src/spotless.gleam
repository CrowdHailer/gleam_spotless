import gleam/http
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/uri
import midas/continuation
import ogre/origin.{Origin}
import spotless/oauth_2_1 as oa
import spotless/proof_key_for_code_exchange as pkce

/// The authenticate function and therefore all named helpers builds upon the oauth_2_1.authorize function
/// This use the `task.Follow` effect and keeps the process state in memory as a continuation.
/// Keeping the state in memory is not possible if the state needs to be serialized in any way.
/// For example a server that would keep code_verifier in a session cannot keep a gleam continuation in a session.
///
/// Instead use the `_server` function and use `oauth_2_1.start`
pub fn authenticate(
  service,
  scope,
  state,
  port,
  code_challenge_method,
  context,
) {
  let client_id = "http://localhost:" <> int.to_string(port)
  let redirect_uri =
    uri.Uri(
      scheme: Some("http"),
      userinfo: None,
      host: Some("localhost"),
      port: Some(port),
      path: "/",
      query: None,
      fragment: None,
    )

  let server = spotless_server(service)

  oa.authorize(
    server,
    client_id,
    redirect_uri,
    None,
    scope,
    state,
    code_challenge_method,
    context,
  )
}

/// The origin of the Spotless service.
const origin = Origin(http.Https, "spotless.run", None)

/// The configuration of the public Spotless authorization server.
pub fn spotless_server(service) {
  oa.AuthorizationServer(
    issuer: "https://spotless.run",
    authorization_endpoint: #(origin, "/authorize/" <> service),
    token_endpoint: #(origin, "/token"),
    scopes_supported: [],
    pushed_authorization_request_endpoint: None,
    code_challenge_methods_supported: [],
  )
}

pub fn bsky(port, scope, state, keypair, context) {
  // If state is empty string that value is not returned from oauth server
  let origin = Origin(http.Https, "bsky.social", None)
  // No port on client id
  let client_id =
    "http://localhost?scope=atproto%20transition:generic%20transition:email%20transition:chat.bsky"

  let redirect_uri =
    uri.Uri(
      scheme: Some("http"),
      userinfo: None,
      host: Some("127.0.0.1"),
      port: Some(port),
      path: "/",
      query: None,
      fragment: None,
    )

  let server =
    oa.AuthorizationServer(
      issuer: "https://bsky.social",
      authorization_endpoint: #(origin, "/oauth/authorize"),
      token_endpoint: #(origin, "/oauth/token"),
      scopes_supported: [],
      pushed_authorization_request_endpoint: Some(#(
        #(origin, "/oauth/par"),
        True,
      )),
      code_challenge_methods_supported: [],
    )

  oa.authorize(
    server,
    client_id,
    redirect_uri,
    Some(keypair),
    scope,
    state,
    pkce.S256,
    context,
  )
}

const services = [
  "dnsimple", "dropbox", "github", "google", "linkedin", "netlify", "strava",
  "twitter", "vimeo",
]

pub fn server(service) {
  case list.contains(services, service) {
    True -> Ok(spotless_server(service))
    False -> Error(Nil)
  }
}

// Currently DNSimple don't use scopes
pub fn dnsimple(port, context) {
  use response <- continuation.try_then(authenticate(
    "dnsimple",
    [],
    "",
    port,
    pkce.S256,
    context,
  ))
  continuation.done(response.access_token)
}

pub fn dropbox(port, scopes, context) {
  use response <- continuation.try_then(authenticate(
    "dropbox",
    scopes,
    "",
    port,
    pkce.S256,
    context,
  ))
  continuation.done(response.access_token)
}

pub fn github(port, scopes, context) {
  use response <- continuation.try_then(authenticate(
    "github",
    scopes,
    "",
    port,
    pkce.S256,
    context,
  ))
  continuation.done(response.access_token)
}

pub fn google(port, scopes, context) {
  use response <- continuation.try_then(authenticate(
    "google",
    scopes,
    "",
    port,
    pkce.S256,
    context,
  ))
  continuation.done(response.access_token)
}

pub fn linkedin(port, scopes, context) {
  use response <- continuation.try_then(authenticate(
    "linkedin",
    scopes,
    "",
    port,
    pkce.S256,
    context,
  ))
  continuation.done(response.access_token)
}

pub fn netlify(port, scopes, context) {
  use response <- continuation.try_then(authenticate(
    "netlify",
    scopes,
    "",
    port,
    pkce.S256,
    context,
  ))
  continuation.done(response.access_token)
}

pub fn strava(port, scopes, context) {
  use response <- continuation.try_then(authenticate(
    "strava",
    scopes,
    "",
    port,
    pkce.S256,
    context,
  ))
  continuation.done(response.access_token)
}

pub fn twitter(port, scopes, context) {
  use response <- continuation.try_then(authenticate(
    "twitter",
    scopes,
    "",
    port,
    pkce.S256,
    context,
  ))
  continuation.done(response.access_token)
}

pub fn vimeo(port, scopes, context) {
  use response <- continuation.try_then(authenticate(
    "vimeo",
    scopes,
    "",
    port,
    pkce.S256,
    context,
  ))
  continuation.done(response.access_token)
}
