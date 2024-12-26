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

import androidx.annotation.IntRange;
import androidx.annotation.NonNull;

/**
 * An interface to link the items and binders by array integer index.
 *
 * @author drakeet
 */
public interface Linker<T> {

  /**
   * Returns the index of your registered binders for your item. The result should be in range of
   * {@code [0, one-to-multiple-binders.length)}.
   *
   * <p>Note: The argument of {@link OneToManyFlow#to(ItemViewBinder[])} is the
   * one-to-multiple-binders.</p>
   *
   * @param position The position in items
   * @param t Your item data
   * @return The index of your registered binders
   * @see OneToManyFlow#to(ItemViewBinder[])
   * @see OneToManyEndpoint#withLinker(Linker)
   */
  @IntRange(from = 0) int index(int position, @NonNull T t);
}
