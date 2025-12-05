import gleam/bit_array
import gleam/http
import gleam/http/request
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/uri
import midas/effect as e
import midas/task as t

pub fn generate_key() {
  t.generate_keypair(e.EcKeyGenParams("ECDSA", "P-256"), True, [
    e.CanSign,
    e.CanVerify,
  ])
}

@deprecated("use jwt for request instead")
pub fn create_dpop_jwt(keypair, method, uri, nonce) {
  let e.KeyPair(public_key, private_key) = keypair
  use jwk <- t.do(t.export_jwk(public_key))
  use now <- t.do(t.unix_now())

  let method = http.method_to_string(method)
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

pub fn jwt_for_request(request, keypair, nonce, token) {
  let e.KeyPair(public_key, private_key) = keypair
  use jwk <- t.do(t.export_jwk(public_key))

  let headers =
    json.object([
      #("typ", json.string("dpop+jwt")),
      #("alg", json.string("ES256")),
      #("jwk", jwk),
    ])

  use common <- t.do(common_claims(request))
  let nonce = case nonce {
    None -> []
    Some(nonce) -> [#("nonce", json.string(nonce))]
  }
  use ath <- t.do(auth_claim(token))
  let claims = list.flatten([common, nonce, ath])
  let payload = json.object(claims)
  jwt_encode(headers, payload, private_key)
}

fn common_claims(request) {
  use unique <- t.do(t.strong_random(12))
  let identifier = bit_array.base64_url_encode(unique, False)
  use now <- t.do(t.unix_now())
  let request.Request(method:, ..) = request
  let method = http.method_to_string(method)
  let uri = request.to_uri(request)
  let uri = uri.Uri(..uri, query: None, fragment: None)
  t.done([
    #("jti", json.string(identifier)),
    #("htm", json.string(method)),
    #("htu", json.string(uri.to_string(uri))),
    #("iat", json.int(now)),
  ])
}

fn auth_claim(token) {
  case token {
    Some(token) -> {
      use ath <- t.do(t.hash(e.Sha256, <<token:utf8>>))
      let ath = bit_array.base64_url_encode(ath, False)
      t.done([#("ath", json.string(ath))])
    }
    None -> t.done([])
  }
}

/// Non-standard but valid HTTP methods.
fn jwt_encode(headers, payload, private_key) {
  let to_sign =
    bit_array.base64_url_encode(<<json.to_string(headers):utf8>>, False)
    <> "."
    <> bit_array.base64_url_encode(<<json.to_string(payload):utf8>>, False)
  use sig <- t.do(
    t.sign(e.EcdsaParams(e.Sha256), private_key, <<to_sign:utf8>>),
  )
  t.done(to_sign <> "." <> bit_array.base64_url_encode(sig, False))
}
