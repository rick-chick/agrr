# frozen_string_literal: true

# Compatibility shim: many domain files under lib/domain/* use the top-level
# ContactMessages namespace. Define Domain::ContactMessages to point to it so
# Zeitwerk autoloading for paths under lib/domain/... resolves to the existing modules.
module Domain
  ContactMessages = ::ContactMessages
end

