import midas/effect

/// Pass functions that don't fail because we don't want to decide a result type.
/// 
/// - fetch does fail as there is an enumerable type of failures and the failure is external.
///   failure of hash would be closer to fetch failing due to missing network stack
pub type Context(t, key) {
  Context(
    export_jwk: effect.ExportJsonWebKey(t, key),
    follow: effect.Follow(t),
    fetch: effect.Fetch(t),
    hash: effect.Hash(t),
    sign: effect.Sign(t, key),
    strong_random: effect.StrongRandom(t),
    unix_now: effect.UnixNow(t),
  )
}
