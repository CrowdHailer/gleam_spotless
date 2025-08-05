//// OAuth 2.0 Protected Resource Metadata
//// Implementation of RFC 9728

import gleam/http/response
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/uri.{type Uri, Uri}
import spotless/httpx
import spotless/origin

pub const oauth_protected_resource = "oauth-protected-resource"

pub fn unauthorized(origin) {
  let path = "/.well-known/" <> oauth_protected_resource
  let uri = Uri(..origin.to_uri(origin), path:) |> uri.to_string

  let challenge =
    httpx.Challenge("Bearer", [httpx.Param("resource_metadata", uri)])
    |> httpx.challenge_to_string()

  response.new(401)
  |> response.set_header("WWW-Authenticate", challenge)
}

pub type Metadata {
  Metadata(
    resource: String,
    authorization_servers: List(origin.Origin),
    jwks_uri: Option(Uri),
    scopes_supported: List(String),
    bearer_methods_supported: Option(List(String)),
    resource_signing_alg_values_supported: Option(List(String)),
    resource_name: Option(String),
    resource_documentation: Option(Uri),
    resource_policy_uri: Option(Uri),
    resource_tos_uri: Option(Uri),
    tls_client_certificate_bound_access_tokens: Bool,
    authorization_details_types_supported: List(String),
    dpop_signing_alg_values_supported: List(String),
    dpop_bound_access_tokens_required: Bool,
  )
}

pub fn new(resource) {
  Metadata(
    resource: resource,
    authorization_servers: [],
    jwks_uri: None,
    scopes_supported: [],
    bearer_methods_supported: None,
    resource_signing_alg_values_supported: None,
    resource_name: None,
    resource_documentation: None,
    resource_policy_uri: None,
    resource_tos_uri: None,
    tls_client_certificate_bound_access_tokens: False,
    authorization_details_types_supported: [],
    dpop_signing_alg_values_supported: [],
    dpop_bound_access_tokens_required: False,
  )
}

pub fn to_json(metadata: Metadata) {
  sparse_object([
    #("resource", Some(json.string(metadata.resource))),
    #(
      "authorization_servers",
      Some(json.array(metadata.authorization_servers, json_origin)),
    ),
    #("jwks_uri", option.map(metadata.jwks_uri, json_uri)),
    #(
      "scopes_supported",
      Some(json.array(metadata.scopes_supported, json.string)),
    ),
    #(
      "bearer_methods_supported",
      option.map(metadata.bearer_methods_supported, json.array(_, json.string)),
    ),
    #(
      "resource_signing_alg_values_supported",
      option.map(metadata.resource_signing_alg_values_supported, json.array(
        _,
        json.string,
      )),
    ),
    #("resource_name", option.map(metadata.resource_name, json.string)),
    #(
      "resource_documentation",
      option.map(metadata.resource_documentation, json_uri),
    ),
    #("resource_policy_uri", option.map(metadata.resource_policy_uri, json_uri)),
    #("resource_tos_uri", option.map(metadata.resource_tos_uri, json_uri)),
    #(
      "tls_client_certificate_bound_access_tokens",
      Some(json.bool(metadata.tls_client_certificate_bound_access_tokens)),
    ),
    #(
      "authorization_details_types_supported",
      Some(json.array(
        metadata.authorization_details_types_supported,
        json.string,
      )),
    ),
    #(
      "dpop_signing_alg_values_supported",
      Some(json.array(metadata.dpop_signing_alg_values_supported, json.string)),
    ),
    #(
      "dpop_bound_access_tokens_required",
      Some(json.bool(metadata.dpop_bound_access_tokens_required)),
    ),
  ])
}

fn json_origin(origin) {
  json.string(origin.to_string(origin))
}

fn json_uri(uri) {
  json.string(uri.to_string(uri))
}

fn sparse_object(entries) {
  list.filter_map(entries, fn(entry) {
    let #(key, value) = entry
    case value {
      Some(value) -> Ok(#(key, value))
      None -> Error(Nil)
    }
  })
  |> json.object
}
