#include "new_window_requested_args.h"

namespace flutter_inappwebview_plugin
{
  NewWindowRequestedArgs::NewWindowRequestedArgs(wil::com_ptr<ICoreWebView2NewWindowRequestedEventArgs> args,
    wil::com_ptr<ICoreWebView2Deferral> deferral)
    : args(std::move(args)), deferral(std::move(deferral))
  {}
}