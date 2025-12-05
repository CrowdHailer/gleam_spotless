import gleam/http
import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/uri

pub type Origin {
  Origin(scheme: http.Scheme, host: String, port: Option(Int))
}

pub fn https(host) {
  Origin(http.Https, host, None)
}

pub fn http(host) {
  Origin(http.Http, host, None)
}

pub fn to_uri(origin) {
  let Origin(scheme, host, port) = origin
  uri.Uri(
    scheme: Some(http.scheme_to_string(scheme)),
    userinfo: None,
    host: Some(host),
    port: port,
    path: "",
    query: None,
    fragment: None,
  )
}

pub fn from_uri(uri) {
  case uri {
    uri.Uri(scheme: Some(scheme), host: Some(host), port: port, ..) ->
      case http.scheme_from_string(scheme) {
        Ok(scheme) -> Ok(Origin(scheme:, host:, port:))
        Error(Nil) -> Error(Nil)
      }
    _ -> Error(Nil)
  }
}

pub fn to_string(origin) {
  let Origin(scheme, host, port) = origin
  let scheme = http.scheme_to_string(scheme)
  let port = case port {
    None -> ""
    Some(port) -> ":" <> int.to_string(port)
  }
  scheme <> "://" <> host <> port
}

pub fn from_string(uri) {
  use uri <- result.try(uri.parse(uri))
  from_uri(uri)
}
