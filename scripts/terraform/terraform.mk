# This file is for you! Edit it to implement your own Terraform make targets.

# ==============================================================================
# Custom implementation - implementation of a make target should not exceed 5 lines of effective code.
# In most cases there should be no need to modify the existing make targets.

# Your default 'TERRAFORM_STACK'
TERRAFORM_STACK := $(or $(or $(TERRAFORM_STACK), $(STACK)), scripts/terraform/examples/terraform-state-aws-s3)

terraform-init: # Initialise Terraform - optional: dir=[path to a directory where the command will be executed, relative to the project's top-level directory, default is '.'], opts=[options to pass to the Terraform init command, default is none/empty]
	source scripts/terraform/terraform.lib.sh
	dir=$(or $(dir), $(TERRAFORM_STACK)) terraform-init # 'dir' and 'opts' are passed to the function as environment variables, if set

terraform-plan: # Plan Terraform changes - optional: dir=[path to a directory where the command will be executed, relative to the project's top-level directory, default is '.'], opts=[options to pass to the Terraform plan command, default is none/empty]
	source scripts/terraform/terraform.lib.sh
	dir=$(or $(dir), $(TERRAFORM_STACK)) terraform-plan # 'dir' and 'opts' are passed to the function as environment variables, if set

terraform-apply: # Apply Terraform changes - optional: dir=[path to a directory where the command will be executed, relative to the project's top-level directory, default is '.'], opts=[options to pass to the Terraform apply command, default is none/empty]
	source scripts/terraform/terraform.lib.sh
	dir=$(or $(dir), $(TERRAFORM_STACK)) terraform-apply # 'dir' and 'opts' are passed to the function as environment variables, if set

terraform-destroy: # Destroy Terraform resources - optional: dir=[path to a directory where the command will be executed, relative to the project's top-level directory, default is '.'], opts=[options to pass to the Terraform destroy command, default is none/empty]
	source scripts/terraform/terraform.lib.sh
	dir=$(or $(dir), $(TERRAFORM_STACK)) terraform-destroy # 'dir' and 'opts' are passed to the function as environment variables, if set

terraform-fmt: # Format Terraform files - optional: dir=[path to a directory where the command will be executed, relative to the project's top-level directory, default is '.'], opts=[options to pass to the Terraform fmt command, default is '-recursive']
	source scripts/terraform/terraform.lib.sh
	dir=$(or $(dir), $(TERRAFORM_STACK)) terraform-fmt # 'dir' and 'opts' are passed to the function as environment variables, if set

terraform-validate: # Validate Terraform configuration - optional: dir=[path to a directory where the command will be executed, relative to the project's top-level directory, default is '.'], opts=[options to pass to the Terraform validate command, default is none/empty]
	source scripts/terraform/terraform.lib.sh
	dir=$(or $(dir), $(TERRAFORM_STACK)) terraform-validate # 'dir' and 'opts' are passed to the function as environment variables, if set

clean:: # Remove Terraform files - optional: dir=[path to a directory where the command will be executed, relative to the project's top-level directory, default is '.']
	source scripts/terraform/terraform.lib.sh
	dir=$(or $(dir), $(TERRAFORM_STACK)) terraform-clean # 'dir' is passed to the function as environment variable, if set

# ==============================================================================
# Quality checks - please, DO NOT edit this section!

terraform-shellscript-lint: # Lint all Terraform module shell scripts
	for file in $$(find ./scripts/terraform -type f -name "*.sh"); do
		file=$$file ./scripts/shellscript-linter.sh
	done

# ==============================================================================
# Module tests and examples - please, DO NOT edit this section!

terraform-example-provision-infrastructure: # Provision example infrastructure
	make terraform-init
	make terraform-plan opts="-out=terraform.tfplan"
	make terraform-apply opts="-auto-approve terraform.tfplan"

terraform-example-destroy-infrastructure: # Destroy example infrastructure
	make terraform-destroy opts="-auto-approve"

terraform-example-clean: # Remove Terraform example files
	source scripts/terraform/terraform.lib.sh
	dir=$(or $(dir), $(TERRAFORM_STACK)) terraform-clean

# ==============================================================================
# Configuration - please, DO NOT edit this section!

terraform-install: # Install Terraform
	make _install-dependency name="terraform"

# ==============================================================================

.SILENT: \
	terraform-apply \
	terraform-destroy \
	terraform-example-clean \
	terraform-example-destroy-infrastructure \
	terraform-example-provision-infrastructure \
	terraform-fmt \
	terraform-init \
	terraform-plan \
	terraform-shellscript-lint \
	terraform-validate \
