#ifndef FLUTTER_INAPPWEBVIEW_PLUGIN_CALLBACKS_COMPLETE_H_
#define FLUTTER_INAPPWEBVIEW_PLUGIN_CALLBACKS_COMPLETE_H_

#include <functional>
#include <mutex>
#include <vector>

namespace flutter_inappwebview_plugin
{
  template<typename T>
  class CallbacksComplete
  {
  public:
    std::function<void(const std::vector<T>&)> onComplete;

    CallbacksComplete(const std::function<void(const std::vector<T>&)> onComplete)
      : onComplete(onComplete)
    {}

    ~CallbacksComplete()
    {
      if (onComplete) {
        onComplete(values_);
      }
    }

    void addValue(const T& value)
    {
      const std::lock_guard<std::mutex> lock(mutex_);
      values_.push_back(value);
    }

  private:
    std::vector<T> values_;
    std::mutex mutex_;
  };
}

#endif //FLUTTER_INAPPWEBVIEW_PLUGIN_CALLBACKS_COMPLETE_H_