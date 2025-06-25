import gleam/bit_array
import midas/task as t

pub type CodeChallengeMethod {
  Plain
  S256
}

pub fn code_challenge_method_to_string(method) {
  case method {
    Plain -> "plain"
    S256 -> "S256"
  }
}

pub fn code_challenge_method_from_string(raw) {
  case raw {
    "plain" -> Ok(Plain)
    "S256" -> Ok(S256)
    // _ -> Error(#(InvalidRequest, "unknown code challenge method " <> raw))
    _ -> Error(Nil)
  }
}

/// 
/// > It is RECOMMENDED that the output of
/// > a suitable random number generator be used to create a 32-octet
/// > sequence.  The octet sequence is then base64url-encoded to produce a
/// > 43-octet URL safe string to use as the code verifier.
pub fn create_code_verifier() {
  use bytes <- t.do(t.strong_random(32))
  t.done(bit_array.base64_url_encode(bytes, False))
}

/// > If the client is capable of using "S256", it MUST use "S256", as
/// > "S256" is Mandatory To Implement (MTI) on the server.
pub fn create_code_challenge(verifier, method) {
  case method {
    Plain -> t.done(verifier)
    S256 -> {
      use bytes <- t.do(t.hash(t.SHA256, <<verifier:utf8>>))
      t.done(bit_array.base64_url_encode(bytes, False))
    }
  }
}
