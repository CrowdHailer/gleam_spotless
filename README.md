# Spotless

*Instant OAuth integration for personal projects.*

[![Package Version](https://img.shields.io/hexpm/v/spotless)](https://hex.pm/packages/spotless)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/spotless/)

Spotless gives you a simple, secure way to connect local projects to many OAuth-powered services. Once authorized you can interact with the service’s API directly using your favourite libraries and tools.

Automate your personal life with Spotless.

```gleam
import midas/sdk/dnsimple
import midas/node
import midas/task as t
import spotless

fn task() {
  // Choose a free port that will be used for the OAuth flow with Spotless.
  let port = 8080
  // Returns a valid access token for your dnsimple account
  use token <- t.do(spotless.dnsimple(port))
  use domains <- t.do(dnsimple.list_domains(token))
  t.done(domains)
}

pub fn main() {
  // Defining tasks with midas is optional.
  // Choosing midas allows you to run tasks in browser or cli.
  node.run(task())
}
```

## ✨ Why Spotless?

- 🔗 Connect to many OAuth services with minimal setup
- 🚀 Hosted authorization flow — no need to register apps yourself
- 🛠 Use your own language and tools — The [spotless.run](https://spotless.run) OAuth server can be used with any language
- 👩‍💻 Built for developers and makers with personal automation in mind

## 🧠 How It Works

The Spotless OAuth server is a hosted service that is already registered with a selection of OAuth services. The Spotless server is preconfigured to accept authorization requests from public clients running on `localhost`.
The spotless library is able to run as a client requiring only a free port to accept the OAuth redirect.

**Can I use Spotless in production?** Yes! You can use spotless as a single integration point to all the services we support. We need to understand your use case and set you up as a confidential client. The best thing is to email me and we can discuss.

## 🏗️ Current Integrations

Spotless supports a growing list of services. Initial integrations include:

- DNSimple
- Github
- Netlify
- Vimeo
- Twitter

Want a new integration? Open an issue.

## 📦 Installation

```sh
gleam add spotless
# Also add your client library of choice
```

## 📚 Documentation
Further documentation can be found at <https://hexdocs.pm/spotless>.

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
```
