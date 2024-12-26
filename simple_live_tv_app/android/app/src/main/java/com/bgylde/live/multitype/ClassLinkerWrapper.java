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

import androidx.annotation.NonNull;

import java.util.Arrays;

/**
 * @author drakeet
 */
final class ClassLinkerWrapper<T> implements Linker<T> {

  private final @NonNull ClassLinker<T> classLinker;
  private final @NonNull ItemViewBinder<T, ?>[] binders;


  private ClassLinkerWrapper(
      @NonNull ClassLinker<T> classLinker,
      @NonNull ItemViewBinder<T, ?>[] binders) {
    this.classLinker = classLinker;
    this.binders = binders;
  }


  static @NonNull <T> ClassLinkerWrapper<T> wrap(
      @NonNull ClassLinker<T> classLinker,
      @NonNull ItemViewBinder<T, ?>[] binders) {
    return new ClassLinkerWrapper<T>(classLinker, binders);
  }


  @Override
  public int index(int position, @NonNull T t) {
    Class<?> userIndexClass = classLinker.index(position, t);
    for (int i = 0; i < binders.length; i++) {
      if (binders[i].getClass().equals(userIndexClass)) {
        return i;
      }
    }
    throw new IndexOutOfBoundsException(
        String.format("%s is out of your registered binders'(%s) bounds.",
            userIndexClass.getName(), Arrays.toString(binders))
    );
  }
}
