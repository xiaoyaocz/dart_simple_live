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

package com.xycz.simple_live_tv.multitype;

import androidx.annotation.NonNull;

/**
 * End-operators for one-to-many.
 *
 * @author drakeet
 */
public interface OneToManyEndpoint<T> {

  /**
   * Sets a linker to link the items and binders by array index.
   *
   * @param linker the row linker
   * @see Linker
   */
  void withLinker(@NonNull Linker<T> linker);

  /**
   * Sets a class linker to link the items and binders by the class instance of binders.
   *
   * @param classLinker the class linker
   * @see ClassLinker
   */
  void withClassLinker(@NonNull ClassLinker<T> classLinker);
}
