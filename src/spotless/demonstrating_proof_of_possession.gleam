import gleam/bit_array
import gleam/http
import gleam/int
import gleam/json
import gleam/string
import gleam/uri
import midas/task as t

pub fn generate_key() {
  t.generate_keypair(t.EcKeyGenParams("ECDSA", "P-256"), True, [
    t.CanSign,
    t.CanVerify,
  ])
}

pub fn create_dpop_jwt(keypair, method, uri, nonce) {
  let t.KeyPair(public_key, private_key) = keypair
  use jwk <- t.do(t.export_jwk(public_key))
  use now <- t.do(t.unix_now())

  let method = case method {
    http.Get -> "GET"
    http.Post -> "POST"
    http.Head -> "HEAD"
    http.Put -> "PUT"
    http.Delete -> "DELETE"
    http.Trace -> "TRACE"
    http.Connect -> "CONNECT"
    http.Options -> "OPTIONS"
    http.Patch -> "PATCH"

    http.Other(other) -> string.uppercase(other)
  }
  let headers =
    json.object([
      #("typ", json.string("dpop+jwt")),
      #("alg", json.string("ES256")),
      #("jwk", jwk),
    ])
  let payload =
    json.object([
      #("jti", json.string(int.to_string(int.random(1_000_000_000_000)))),
      #("htm", json.string(method)),
      #("htu", json.string(uri.to_string(uri))),
      #("iat", json.int(now)),
      #("nonce", json.string(nonce)),
    ])
  jwt_encode(headers, payload, private_key)
}

/// Non-standard but valid HTTP methods.
fn jwt_encode(headers, payload, private_key) {
  let to_sign =
    bit_array.base64_url_encode(<<json.to_string(headers):utf8>>, False)
    <> "."
    <> bit_array.base64_url_encode(<<json.to_string(payload):utf8>>, False)
  use sig <- t.do(
    t.sign(t.EcdsaParams(t.SHA256), private_key, <<to_sign:utf8>>),
  )
  t.done(to_sign <> "." <> bit_array.base64_url_encode(sig, False))
}
