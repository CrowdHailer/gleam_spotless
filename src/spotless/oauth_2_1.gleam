import gleam/http
import gleam/option.{type Option}

pub type ClientType {
  Public
  Confidential(client_secret: String)
}

pub type Origin {
  Origin(scheme: http.Scheme, host: String, port: Option(Int))
}

pub type AuthorizationServer {
  AuthorizationServer(
    issuer: String,
    authorization_endpoint: #(Origin, String),
    token_endpoint: #(Origin, String),
  )
}

pub type App {
  App(client_type: ClientType, client_id: String, redirect_uri: String)
}
