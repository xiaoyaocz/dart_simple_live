/*
 * Copyright 2016 drakeet. https://github.com/drakeet
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.bgylde.live.multitype;

import androidx.annotation.CheckResult;
import androidx.annotation.NonNull;

/**
 * Process and flow operators for one-to-many.
 *
 * @author drakeet
 */
public interface OneToManyFlow<T> {

  /**
   * Sets some item view binders to the item type.
   *
   * @param binders the item view binders
   * @return end flow operator
   */
  @CheckResult @SuppressWarnings("unchecked")
  @NonNull
  OneToManyEndpoint<T> to(@NonNull ItemViewBinder<T, ?>... binders);
}
