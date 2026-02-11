# Common Tags Configuration
# Centralized tag definitions for consistent tagging across all environments

locals {
  # Standard team and ownership tags
  standard_tags = {
    owning_team          = "NETENG"
    managed_by_terraform = true
  }

  # Environment-specific tags will be added at environment level
  # environment, region, region_short should be passed from each environment
}
