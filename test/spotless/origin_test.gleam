import gleam/http
import gleam/option.{None}
import ogre/origin

pub fn https_test() {
  assert origin.Origin(scheme: http.Https, host: "example.com", port: None)
    == origin.https("example.com")
}
