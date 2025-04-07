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

import android.util.Log;
import android.view.LayoutInflater;
import android.view.ViewGroup;

import androidx.annotation.CheckResult;
import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;
import androidx.recyclerview.widget.RecyclerView.ViewHolder;

import java.util.Collections;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;

import static com.xycz.simple_live_tv.multitype.Preconditions.checkNotNull;

/**
 * @author drakeet
 */
public class MultiTypeAdapter extends RecyclerView.Adapter<ViewHolder> {

  private static final String TAG = "MultiTypeAdapter";

  private @NonNull List<?> items;
  private @NonNull TypePool typePool;


  /**
   * Constructs a MultiTypeAdapter with an empty items list.
   */
  public MultiTypeAdapter() {
    this(Collections.emptyList());
  }


  /**
   * Constructs a MultiTypeAdapter with a items list.
   *
   * @param items the items list
   */
  public MultiTypeAdapter(@NonNull List<?> items) {
    this(items, new MultiTypePool());
  }


  /**
   * Constructs a MultiTypeAdapter with a items list and an initial capacity of TypePool.
   *
   * @param items the items list
   * @param initialCapacity the initial capacity of TypePool
   */
  public MultiTypeAdapter(@NonNull List<?> items, int initialCapacity) {
    this(items, new MultiTypePool(initialCapacity));
  }


  /**
   * Constructs a MultiTypeAdapter with a items list and a TypePool.
   *
   * @param items the items list
   * @param pool the type pool
   */
  public MultiTypeAdapter(@NonNull List<?> items, @NonNull TypePool pool) {
    checkNotNull(items);
    checkNotNull(pool);
    this.items = items;
    this.typePool = pool;
  }


  /**
   * Registers a type class and its item view binder. If you have registered the class,
   * it will override the original binder(s). Note that the method is non-thread-safe
   * so that you should not use it in concurrent operation.
   * <p>
   * Note that the method should not be called after
   * {@link RecyclerView#setAdapter(RecyclerView.Adapter)}, or you have to call the setAdapter
   * again.
   * </p>
   *
   * @param clazz the class of a item
   * @param binder the item view binder
   * @param <T> the item data type
   */
  public <T> void register(@NonNull Class<? extends T> clazz, @NonNull ItemViewBinder<T, ?> binder) {
    checkNotNull(clazz);
    checkNotNull(binder);
    checkAndRemoveAllTypesIfNeeded(clazz);
    register(clazz, binder, new DefaultLinker<T>());
  }


  <T> void register(
      @NonNull Class<? extends T> clazz,
      @NonNull ItemViewBinder<T, ?> binder,
      @NonNull Linker<T> linker) {
    typePool.register(clazz, binder, linker);
    binder.adapter = this;
  }


  /**
   * Registers a type class to multiple item view binders. If you have registered the
   * class, it will override the original binder(s). Note that the method is non-thread-safe
   * so that you should not use it in concurrent operation.
   * <p>
   * Note that the method should not be called after
   * {@link RecyclerView#setAdapter(RecyclerView.Adapter)}, or you have to call the setAdapter
   * again.
   * </p>
   *
   * @param clazz the class of a item
   * @param <T> the item data type
   * @return {@link OneToManyFlow} for setting the binders
   * @see #register(Class, ItemViewBinder)
   */
  @CheckResult
  public @NonNull <T> OneToManyFlow<T> register(@NonNull Class<? extends T> clazz) {
    checkNotNull(clazz);
    checkAndRemoveAllTypesIfNeeded(clazz);
    return new OneToManyBuilder<>(this, clazz);
  }


  /**
   * Registers all of the contents in the specified type pool. If you have registered a
   * class, it will override the original binder(s). Note that the method is non-thread-safe
   * so that you should not use it in concurrent operation.
   * <p>
   * Note that the method should not be called after
   * {@link RecyclerView#setAdapter(RecyclerView.Adapter)}, or you have to call the setAdapter
   * again.
   * </p>
   *
   * @param pool type pool containing contents to be added to this adapter inner pool
   * @see #register(Class, ItemViewBinder)
   * @see #register(Class)
   */
  public void registerAll(@NonNull final TypePool pool) {
    checkNotNull(pool);
    final int size = pool.size();
    for (int i = 0; i < size; i++) {
      registerWithoutChecking(
          pool.getClass(i),
          pool.getItemViewBinder(i),
          pool.getLinker(i)
      );
    }
  }


  /**
   * Sets and updates the items atomically and safely. It is recommended to use this method
   * to update the items with a new wrapper list or consider using {@link CopyOnWriteArrayList}.
   *
   * <p>Note: If you want to refresh the list views after setting items, you should
   * call {@link RecyclerView.Adapter#notifyDataSetChanged()} by yourself.</p>
   *
   * @param items the new items list
   * @since v2.4.1
   */
  public void setItems(@NonNull List<?> items) {
    checkNotNull(items);
    this.items = items;
  }


  public @NonNull List<?> getItems() {
    return items;
  }


  /**
   * Set the TypePool to hold the types and view binders.
   *
   * @param typePool the TypePool implementation
   */
  public void setTypePool(@NonNull TypePool typePool) {
    checkNotNull(typePool);
    this.typePool = typePool;
  }


  public @NonNull TypePool getTypePool() {
    return typePool;
  }


  @Override
  public final int getItemViewType(int position) {
    Object item = items.get(position);
    return indexInTypesOf(position, item);
  }


  @Override
  public final ViewHolder onCreateViewHolder(ViewGroup parent, int indexViewType) {
    LayoutInflater inflater = LayoutInflater.from(parent.getContext());
    ItemViewBinder<?, ?> binder = typePool.getItemViewBinder(indexViewType);
    return binder.onCreateViewHolder(inflater, parent);
  }


  /**
   * This method is deprecated and unused. You should not call this method.
   * <p>
   * If you need to call the binding, use {@link RecyclerView.Adapter#onBindViewHolder(ViewHolder,
   * int, List)} instead.
   * </p>
   *
   * @param holder The ViewHolder which should be updated to represent the contents of the
   * item at the given position in the data set.
   * @param position The position of the item within the adapter's data set.
   * @throws IllegalAccessError By default.
   * @deprecated Call {@link RecyclerView.Adapter#onBindViewHolder(ViewHolder, int, List)}
   * instead.
   */
  @Override @Deprecated
  public final void onBindViewHolder(@NonNull ViewHolder holder, int position) {
    onBindViewHolder(holder, position, Collections.emptyList());
  }


  @Override @SuppressWarnings("unchecked")
  public final void onBindViewHolder(ViewHolder holder, int position, @NonNull List<Object> payloads) {
    Object item = items.get(position);
    ItemViewBinder binder = typePool.getItemViewBinder(holder.getItemViewType());
    binder.onBindViewHolder(holder, item, payloads);
  }


  @Override
  public final int getItemCount() {
    return items.size();
  }


  /**
   * Called to return the stable ID for the item, and passes the event to its associated binder.
   *
   * @param position Adapter position to query
   * @return the stable ID of the item at position
   * @see ItemViewBinder#getItemId(Object)
   * @see RecyclerView.Adapter#setHasStableIds(boolean)
   * @since v3.2.0
   */
  @Override @SuppressWarnings("unchecked")
  public final long getItemId(int position) {
    Object item = items.get(position);
    int itemViewType = getItemViewType(position);
    ItemViewBinder binder = typePool.getItemViewBinder(itemViewType);
    return binder.getItemId(item);
  }


  /**
   * Called when a view created by this adapter has been recycled, and passes the event to its
   * associated binder.
   *
   * @param holder The ViewHolder for the view being recycled
   * @see RecyclerView.Adapter#onViewRecycled(ViewHolder)
   * @see ItemViewBinder#onViewRecycled(ViewHolder)
   */
  @Override @SuppressWarnings("unchecked")
  public final void onViewRecycled(@NonNull ViewHolder holder) {
    getRawBinderByViewHolder(holder).onViewRecycled(holder);
  }


  /**
   * Called by the RecyclerView if a ViewHolder created by this Adapter cannot be recycled
   * due to its transient state, and passes the event to its associated item view binder.
   *
   * @param holder The ViewHolder containing the View that could not be recycled due to its
   * transient state.
   * @return True if the View should be recycled, false otherwise. Note that if this method
   * returns <code>true</code>, RecyclerView <em>will ignore</em> the transient state of
   * the View and recycle it regardless. If this method returns <code>false</code>,
   * RecyclerView will check the View's transient state again before giving a final decision.
   * Default implementation returns false.
   * @see RecyclerView.Adapter#onFailedToRecycleView(ViewHolder)
   * @see ItemViewBinder#onFailedToRecycleView(ViewHolder)
   */
  @Override @SuppressWarnings("unchecked")
  public final boolean onFailedToRecycleView(@NonNull ViewHolder holder) {
    return getRawBinderByViewHolder(holder).onFailedToRecycleView(holder);
  }


  /**
   * Called when a view created by this adapter has been attached to a window, and passes the
   * event to its associated item view binder.
   *
   * @param holder Holder of the view being attached
   * @see RecyclerView.Adapter#onViewAttachedToWindow(ViewHolder)
   * @see ItemViewBinder#onViewAttachedToWindow(ViewHolder)
   */
  @Override @SuppressWarnings("unchecked")
  public final void onViewAttachedToWindow(@NonNull ViewHolder holder) {
    getRawBinderByViewHolder(holder).onViewAttachedToWindow(holder);
  }


  /**
   * Called when a view created by this adapter has been detached from its window, and passes
   * the event to its associated item view binder.
   *
   * @param holder Holder of the view being detached
   * @see RecyclerView.Adapter#onViewDetachedFromWindow(ViewHolder)
   * @see ItemViewBinder#onViewDetachedFromWindow(ViewHolder)
   */
  @Override @SuppressWarnings("unchecked")
  public final void onViewDetachedFromWindow(@NonNull ViewHolder holder) {
    getRawBinderByViewHolder(holder).onViewDetachedFromWindow(holder);
  }


  private @NonNull ItemViewBinder getRawBinderByViewHolder(@NonNull ViewHolder holder) {
    return typePool.getItemViewBinder(holder.getItemViewType());
  }


  int indexInTypesOf(int position, @NonNull Object item) throws BinderNotFoundException {
    int index = typePool.firstIndexOf(item.getClass());
    if (index != -1) {
      @SuppressWarnings("unchecked")
      Linker<Object> linker = (Linker<Object>) typePool.getLinker(index);
      return index + linker.index(position, item);
    }
    throw new BinderNotFoundException(item.getClass());
  }


  private void checkAndRemoveAllTypesIfNeeded(@NonNull Class<?> clazz) {
    if (typePool.unregister(clazz)) {
      Log.w(TAG, "You have registered the " + clazz.getSimpleName() + " type. " +
          "It will override the original binder(s).");
    }
  }


  /** A safe register method base on the TypePool's safety for TypePool. */
  @SuppressWarnings("unchecked")
  private void registerWithoutChecking(@NonNull Class clazz, @NonNull ItemViewBinder binder, @NonNull Linker linker) {
    checkAndRemoveAllTypesIfNeeded(clazz);
    register(clazz, binder, linker);
  }
}
