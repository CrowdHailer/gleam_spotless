import gleam/list
import gleam/string

pub type Challenge {
  Challenge(auth_schema: String, params: List(Param))
}

pub fn challenge_to_string(challenge) {
  let Challenge(auth_schema, params) = challenge
  let params = params |> list.map(param_to_string) |> string.join(", ")
  auth_schema <> " " <> params
}

pub type Param {
  Token68(String)
  Param(String, String)
}

fn param_to_string(param) {
  case param {
    Token68(token) -> token
    Param(key, value) -> key <> "=" <> value |> escape_quoted
  }
}

fn escape_quoted(string) {
  let content =
    string
    |> string.replace("\\", "\\\\")
    |> string.replace("\"", "\\\"")
  "\"" <> content <> "\""
}
