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

import java.util.ArrayList;
import java.util.List;

import static com.bgylde.live.multitype.Preconditions.checkNotNull;

/**
 * An List implementation of TypePool.
 *
 * @author drakeet
 */
public class MultiTypePool implements TypePool {

  private final @NonNull List<Class<?>> classes;
  private final @NonNull List<ItemViewBinder<?, ?>> binders;
  private final @NonNull List<Linker<?>> linkers;


  /**
   * Constructs a MultiTypePool with default lists.
   */
  public MultiTypePool() {
    this.classes = new ArrayList<>();
    this.binders = new ArrayList<>();
    this.linkers = new ArrayList<>();
  }


  /**
   * Constructs a MultiTypePool with default lists and a specified initial capacity.
   *
   * @param initialCapacity the initial capacity of the list
   */
  public MultiTypePool(int initialCapacity) {
    this.classes = new ArrayList<>(initialCapacity);
    this.binders = new ArrayList<>(initialCapacity);
    this.linkers = new ArrayList<>(initialCapacity);
  }


  /**
   * Constructs a MultiTypePool with specified lists.
   *
   * @param classes the list for classes
   * @param binders the list for binders
   * @param linkers the list for linkers
   */
  public MultiTypePool(
      @NonNull List<Class<?>> classes,
      @NonNull List<ItemViewBinder<?, ?>> binders,
      @NonNull List<Linker<?>> linkers) {
    checkNotNull(classes);
    checkNotNull(binders);
    checkNotNull(linkers);
    this.classes = classes;
    this.binders = binders;
    this.linkers = linkers;
  }


  @Override
  public <T> void register(
      @NonNull Class<? extends T> clazz,
      @NonNull ItemViewBinder<T, ?> binder,
      @NonNull Linker<T> linker) {
    checkNotNull(clazz);
    checkNotNull(binder);
    checkNotNull(linker);
    classes.add(clazz);
    binders.add(binder);
    linkers.add(linker);
  }


  @Override
  public boolean unregister(@NonNull Class<?> clazz) {
    checkNotNull(clazz);
    boolean removed = false;
    while (true) {
      int index = classes.indexOf(clazz);
      if (index != -1) {
        classes.remove(index);
        binders.remove(index);
        linkers.remove(index);
        removed = true;
      } else {
        break;
      }
    }
    return removed;
  }


  @Override
  public int size() {
    return classes.size();
  }


  @Override
  public int firstIndexOf(@NonNull final Class<?> clazz) {
    checkNotNull(clazz);
    int index = classes.indexOf(clazz);
    if (index != -1) {
      return index;
    }
    for (int i = 0; i < classes.size(); i++) {
      if (classes.get(i).isAssignableFrom(clazz)) {
        return i;
      }
    }
    return -1;
  }


  @Override
  public @NonNull Class<?> getClass(int index) {
    return classes.get(index);
  }


  @Override
  public @NonNull ItemViewBinder<?, ?> getItemViewBinder(int index) {
    return binders.get(index);
  }


  @Override
  public @NonNull Linker<?> getLinker(int index) {
    return linkers.get(index);
  }
}
