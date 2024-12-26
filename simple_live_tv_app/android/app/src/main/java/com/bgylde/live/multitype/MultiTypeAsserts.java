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
import androidx.recyclerview.widget.RecyclerView;

import java.util.List;

import static com.bgylde.live.multitype.Preconditions.checkNotNull;

/**
 * @author drakeet
 */
public final class MultiTypeAsserts {

  private MultiTypeAsserts() {
    throw new AssertionError();
  }


  /**
   * Makes the exception to occur in your class for debug and index.
   *
   * @param adapter the MultiTypeAdapter
   * @param items the items list
   * @throws BinderNotFoundException if check failed
   * @throws IllegalArgumentException if your Items/List is empty
   */
  @SuppressWarnings("unchecked")
  public static void assertAllRegistered(@NonNull MultiTypeAdapter adapter, @NonNull List<?> items)
      throws BinderNotFoundException, IllegalArgumentException, IllegalAccessError {
    checkNotNull(adapter);
    checkNotNull(items);
    if (items.isEmpty()) {
      throw new IllegalArgumentException("Your Items/List is empty.");
    }
    for (int i = 0; i < items.size(); i++) {
      adapter.indexInTypesOf(i, items.get(0));
    }
    /* All passed. */
  }


  /**
   * @param recyclerView the RecyclerView
   * @param adapter the MultiTypeAdapter
   * @throws IllegalAccessError The assertHasTheSameAdapter() method must be placed after
   * recyclerView.setAdapter().
   * @throws IllegalArgumentException If your recyclerView's adapter.
   * is not the sample with the argument adapter.
   */
  public static void assertHasTheSameAdapter(@NonNull RecyclerView recyclerView, @NonNull MultiTypeAdapter adapter)
      throws IllegalArgumentException, IllegalAccessError {
    checkNotNull(recyclerView);
    checkNotNull(adapter);
    if (recyclerView.getAdapter() == null) {
      throw new IllegalAccessError("The assertHasTheSameAdapter() method must " +
          "be placed after recyclerView.setAdapter()");
    }
    if (recyclerView.getAdapter() != adapter) {
      throw new IllegalArgumentException(
          "Your recyclerView's adapter is not the sample with the argument adapter.");
    }
  }
}
