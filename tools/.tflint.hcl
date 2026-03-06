config {
  # Disable module inspection — no AWS credentials available in CI.
  # tflint will still lint all resource/variable declarations in the
  # current directory; it just won't follow module source references.
  call_module_type = "none"
}

plugin "aws" {
  enabled = true
  version = "0.45.0" # Check GitHub for the latest version
  source  = "github.com/terraform-linters/tflint-ruleset-aws"

  # deep_check makes live AWS API calls to validate values (e.g. AMI IDs).
  # Disabled because CI has no real AWS credentials scoped for tflint.
  deep_check = false
}
