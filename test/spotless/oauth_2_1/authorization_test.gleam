import spotless/oauth_2_1/authorization
import spotless/proof_key_for_code_exchange

const minimal = [
  #("response_type", "code"),
  #("client_id", "example"),
  #("code_challenge", "secret"),
  #("redirect_uri", "http://example.com"),
]

pub fn minimal_parameters_test() {
  let assert Ok(request) = authorization.request_from_params(minimal)
  assert authorization.Request(
      client_id: "example",
      code_challenge: "secret",
      code_challenge_method: proof_key_for_code_exchange.Plain,
      redirect_uri: "http://example.com",
      scope: [],
      state: "",
      extra: [],
    )
    == request
}

pub fn empty_scope_encode_test() {
  let assert Ok(request) =
    authorization.request_from_params([#("scope", ""), ..minimal])
  assert [] == request.scope
}
