terraform {
  required_providers {
    coderd = {
      source = "coder/coderd"
    }
  }
}

variable "coder_url" {}

variable "coder_api_token" {
  sensitive = true
}

provider "coderd" {
  url   = var.coder_url
  token = var.coder_api_token
}

resource "coderd_user" "sre-admin" {
  username   = "sre-admin"
  name       = "SRE Admin"
  email      = "admin@coder.com"
  password   = "sreadmin1!"
  roles = ["template-admin"]
  login_type = "password"
}

resource "coderd_user" "sre1" {
  username   = "sre1"
  name       = "SRE One"
  email      = "1@coder.com"
  password   = "password1!"
  login_type = "password"
}

resource "coderd_user" "sre2" {
  username   = "sre2"
  name       = "SRE Two"
  email      = "2@coder.com"
  password   = "password2!"
  login_type = "password"
}

resource "coderd_group" "sre-admins" {
  depends_on = [coderd_user.sre-admin]
  name = "sre-admins"
  members = [
    coderd_user.sre-admin.id,
  ]
}

resource "coderd_group" "sres" {
  depends_on = [coderd_user.sre1, coderd_user.sre2]
  name = "sres"
  members = [
    coderd_user.sre1.id,
    coderd_user.sre2.id
  ]
}

resource "coderd_template" "sre-basic" {
  depends_on = [coderd_user.sre-admin, coderd_group.sres]
  name        = "sre-basic"
  description = "Basic template to be used by SREs."
  versions = [
    {
      directory = "/coder-tf/sre-template",
      active    = true,
    },
  ]
  acl = {
    users = [
      {
        id : coderd_user.sre-admin.id,
        role : "admin",
      }
    ],
    groups = [
      {
        id : coderd_group.sres.id,
        role : "use",
      }
    ]
  }
}