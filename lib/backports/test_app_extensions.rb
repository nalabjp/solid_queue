# Backport `stub_const` API
require 'backports/active_support/testing/constant_stubbing.rb'
ActiveSupport::TestCase.include(ActiveSupport::Testing::ConstantStubbing)
