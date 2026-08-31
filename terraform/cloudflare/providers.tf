terraform {
  required_version = ">= 1.5"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

provider "cloudflare" {
  # API token read from the CLOUDFLARE_API_TOKEN env var (the provider's default
  # lookup) — never passed as an argument, never committed.
}
