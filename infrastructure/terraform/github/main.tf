terraform {
  cloud {
    organization = "grey-rock"
    workspaces {
      name = "greyrock-github-provisioner"
    }
  }

  required_providers {
    github = {
      source  = "integrations/github"
      version = "5.28.0"
    }
  }
}

module "onepassword_item_github" {
  source = "github.com/Doonga/terraform-1password-item?ref=main"
  vault  = "Services"
  item   = "Github"
}

module "onepassword_item_github_greyrock_bot" {
  source = "github.com/Doonga/terraform-1password-item?ref=main"
  vault  = "Automation"
  item   = "github-greyrock-bot"
}

module "onepassword_item_flux" {
  source = "github.com/Doonga/terraform-1password-item?ref=main"
  vault  = "Automation"
  item   = "flux"
}

module "doonga" {
  source = "./doonga"

  secrets = {
    greyrock_bot_app_id            = module.onepassword_item_github_greyrock_bot.fields.github_app_id
    greyrock_bot_private_key       = module.onepassword_item_github_greyrock_bot.fields.github_app_private_key
    flux_github_webhook_url    = module.onepassword_item_flux.fields.github_webhook_url
    flux_github_webhook_secret = module.onepassword_item_flux.fields.github_webhook_token
  }
}

moved {
  from = module.vyos-config
  to   = module.doonga.module.vyos_config
}

moved {
  from = module.terraform-1password-item
  to   = module.doonga.module.terraform_1password_item
}

moved {
  from = module.gh-workflows
  to   = module.doonga.module.gh_workflows
}

moved {
  from = module.greyrock-ops
  to   = module.doonga.module.greyrock_ops
}

moved {
  from = module.container-images
  to   = module.doonga.module.container_images
}

moved {
  from = module.esphome-config
  to   = module.doonga.module.esphome_config
}

moved {
  from = module.renovate-config
  to   = module.doonga.module.renovate_config
}

moved {
  from = module.terraform-github-repository
  to   = module.doonga.module.terraform_github_repository
}
