import gleam/http
import gleam/option.{type Option}

pub type Origin {
  Origin(scheme: http.Scheme, host: String, port: Option(Int))
}
