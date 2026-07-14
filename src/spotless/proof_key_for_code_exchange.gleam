import gleam/bit_array
import midas/continuation.{type Continuation as K}
import midas/effect

pub type CodeChallengeMethod {
  Plain
  S256
}

pub fn code_challenge_method_to_string(method: CodeChallengeMethod) -> String {
  case method {
    Plain -> "plain"
    S256 -> "S256"
  }
}

pub fn code_challenge_method_from_string(
  raw: String,
) -> Result(CodeChallengeMethod, Nil) {
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
pub fn create_code_verifier(
  strong_random: fn(Int) -> K(t, BitArray),
) -> K(t, String) {
  use bytes <- continuation.then(strong_random(32))
  continuation.return(bit_array.base64_url_encode(bytes, False))
}

/// > If the client is capable of using "S256", it MUST use "S256", as
/// > "S256" is Mandatory To Implement (MTI) on the server.
pub fn create_code_challenge(
  verifier: String,
  method: CodeChallengeMethod,
  hash: fn(effect.HashAlgorithm, BitArray) -> K(t, BitArray),
) -> K(t, String) {
  case method {
    Plain -> continuation.return(verifier)
    S256 -> create_s256_code_challenge(verifier, hash)
  }
}

pub fn create_s256_code_challenge(
  verifier: String,
  hash: fn(effect.HashAlgorithm, BitArray) -> K(t, BitArray),
) -> K(t, String) {
  use bytes <- continuation.then(hash(effect.Sha256, <<verifier:utf8>>))
  continuation.return(bit_array.base64_url_encode(bytes, False))
}
