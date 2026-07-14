import gleam/bit_array
import gleam/http
import gleam/http/request
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/uri
import midas/continuation.{type Continuation as K}
import midas/effect as e
import spotless/context.{Context}

// pub fn generate_key() {
//   t.generate_keypair(e.EcKeyGenParams("ECDSA", "P-256"), True, [
//     e.CanSign,
//     e.CanVerify,
//   ])
// }

pub fn jwt_for_request(
  request: request.Request(BitArray),
  keypair: e.KeyPair(key),
  nonce: option.Option(String),
  token: option.Option(String),
  context: context.Context(t, key),
) -> K(t, Result(String, String)) {
  let e.KeyPair(public_key, private_key) = keypair
  use jwk <- continuation.then(context.export_jwk(public_key))

  let headers =
    json.object([
      #("typ", json.string("dpop+jwt")),
      #("alg", json.string("ES256")),
      #("jwk", jwk),
    ])

  use common <- continuation.then(common_claims(request, context))
  let nonce = case nonce {
    None -> []
    Some(nonce) -> [#("nonce", json.string(nonce))]
  }
  use ath <- continuation.try_then(auth_claim(token, context.hash))
  let claims = list.flatten([common, nonce, ath])
  let payload = json.object(claims)
  jwt_encode(headers, payload, private_key, context.sign)
}

fn common_claims(
  request: request.Request(BitArray),
  context: context.Context(t, key),
) -> K(t, List(#(String, json.Json))) {
  let Context(strong_random:, unix_now:, ..) = context
  use unique <- continuation.then(strong_random(12))
  let identifier = bit_array.base64_url_encode(unique, False)
  use now <- continuation.then(unix_now())
  let request.Request(method:, ..) = request
  let method = http.method_to_string(method)
  let uri = request.to_uri(request)
  let uri = uri.Uri(..uri, query: None, fragment: None)
  continuation.return([
    #("jti", json.string(identifier)),
    #("htm", json.string(method)),
    #("htu", json.string(uri.to_string(uri))),
    #("iat", json.int(now)),
  ])
}

fn auth_claim(
  token: option.Option(String),
  hash: fn(e.HashAlgorithm, BitArray) -> K(t, BitArray),
) -> K(t, Result(List(#(String, json.Json)), String)) {
  case token {
    Some(token) -> {
      use ath <- continuation.then(hash(e.Sha256, <<token:utf8>>))
      let ath = bit_array.base64_url_encode(ath, False)
      continuation.return(Ok([#("ath", json.string(ath))]))
    }
    None -> continuation.return(Ok([]))
  }
}

/// Non-standard but valid HTTP methods.
fn jwt_encode(
  headers: json.Json,
  payload: json.Json,
  private_key: key,
  sign: e.Sign(t, key),
) -> K(t, Result(String, String)) {
  let to_sign =
    bit_array.base64_url_encode(<<json.to_string(headers):utf8>>, False)
    <> "."
    <> bit_array.base64_url_encode(<<json.to_string(payload):utf8>>, False)
  use sig <- continuation.try_then(
    sign(e.EcdsaParams(e.Sha256), private_key, <<to_sign:utf8>>),
  )

  continuation.done(to_sign <> "." <> bit_array.base64_url_encode(sig, False))
}
