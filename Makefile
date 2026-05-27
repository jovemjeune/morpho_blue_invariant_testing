# For convenience, add the following to your aliases:
# `function f() { make forge ARGS="$*"; }`

forge:
	@forge $(ARGS)

# Production bytecode matching upstream Morpho Blue
forge-via-ir:
	@FOUNDRY_PROFILE=via_ir forge $(ARGS)

.PHONY: forge
