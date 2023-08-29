# This file is for you! Edit it to implement your own Terraform make targets.

# ==============================================================================
# Custom implementation - implementation of a make target should not exceed 5 lines of effective code.
# In most cases there should be no need to modify the existing make targets.

terraform-init: # Initialise Terraform - optional: dir=[path to a directory where the command will be executed, relative to the project's top-level directory, default is one of the module variables or the example directory, if not set], opts=[options to pass to the Terraform init command, default is none/empty]
	make _terraform cmd="init"

terraform-plan: # Plan Terraform changes - optional: dir=[path to a directory where the command will be executed, relative to the project's top-level directory, default is one of the module variables or the example directory, if not set], opts=[options to pass to the Terraform plan command, default is none/empty]
	make _terraform cmd="plan"

terraform-apply: # Apply Terraform changes - optional: dir=[path to a directory where the command will be executed, relative to the project's top-level directory, default is one of the module variables or the example directory, if not set], opts=[options to pass to the Terraform apply command, default is none/empty]
	make _terraform cmd="apply"

terraform-destroy: # Destroy Terraform resources - optional: dir=[path to a directory where the command will be executed, relative to the project's top-level directory, default is one of the module variables or the example directory, if not set], opts=[options to pass to the Terraform destroy command, default is none/empty]
	make _terraform cmd="destroy"

terraform-fmt: # Format Terraform files - optional: dir=[path to a directory where the command will be executed, relative to the project's top-level directory, default is one of the module variables or the example directory, if not set], opts=[options to pass to the Terraform fmt command, default is '-recursive']
	make _terraform cmd="fmt"

terraform-validate: # Validate Terraform configuration - optional: dir=[path to a directory where the command will be executed, relative to the project's top-level directory, default is one of the module variables or the example directory, if not set], opts=[options to pass to the Terraform validate command, default is none/empty]
	make _terraform cmd="validate"

clean:: # Remove Terraform files - optional: dir=[path to a directory where the command will be executed, relative to the project's top-level directory, default is one of the module variables or the example directory, if not set]
	make _terraform cmd="clean"

_terraform: # Terraform command wrapper - mandatory: cmd=[command to execute]; optional: dir=[path to a directory where the command will be executed, relative to the project's top-level directory, default is one of the module variables or the example directory, if not set], opts=[options to pass to the Terraform command, default is none/empty]
	# 'TERRAFORM_STACK' is passed to the functions as environment variable
	TERRAFORM_STACK=$(or ${TERRAFORM_STACK}, $(or ${terraform_stack}, $(or ${STACK}, $(or ${stack}, scripts/terraform/examples/terraform-state-aws-s3))))
	dir=$(or ${dir}, ${TERRAFORM_STACK})
	source scripts/terraform/terraform.lib.sh
	terraform-${cmd} # 'dir' and 'opts' are passed to the function as environment variables, if set

# ==============================================================================
# Quality checks - please, DO NOT edit this section!

terraform-shellscript-lint: # Lint all Terraform module shell scripts
	for file in $$(find scripts/terraform -type f -name "*.sh"); do
		file=$${file} scripts/shellscript-linter.sh
	done

# ==============================================================================
# Module tests and examples - please, DO NOT edit this section!

terraform-example-provision-aws-infrastructure: # Provision example of AWS infrastructure
	make terraform-init
	make terraform-plan opts="-out=terraform.tfplan"
	make terraform-apply opts="-auto-approve terraform.tfplan"

terraform-example-destroy-aws-infrastructure: # Destroy example of AWS infrastructure
	make terraform-destroy opts="-auto-approve"

terraform-example-clean: # Remove Terraform example files
	dir=$(or ${dir}, ${TERRAFORM_STACK})
	source scripts/terraform/terraform.lib.sh
	terraform-clean
	rm -f ${TERRAFORM_STACK}/.terraform.lock.hcl

# ==============================================================================
# Configuration - please, DO NOT edit this section!

terraform-install: # Install Terraform
	make _install-dependency name="terraform"

# ==============================================================================

.SILENT: \
	_terraform \
	clean \
	terraform-apply \
	terraform-destroy \
	terraform-example-clean \
	terraform-example-destroy-aws-infrastructure \
	terraform-example-provision-aws-infrastructure \
	terraform-fmt \
	terraform-init \
	terraform-plan \
	terraform-shellscript-lint \
	terraform-validate \
