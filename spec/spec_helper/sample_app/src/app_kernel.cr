require "../../../spec_helper"
require "./bundles/app_bundle/app_bundle"
require "./bundles/other_bundle/other_bundle"

class AppKernel < Glassy::Kernel::Kernel
  register_bundles [
    Glassy::Console::Bundle,
    Glassy::MongoODM::Bundle,
    AppBundle,
    OtherBundle,
  ]
end
