/*
 * Copyright (C) 2009 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.bgylde.live.danmaku.flame.model.objectpool;

class FinitePool<T extends Poolable<T>> implements Pool<T> {
    /** Factory used to create new pool objects */
    private final PoolableManager<T> mManager;

    /** Maximum number of objects in the pool */
    private final int mLimit;

    /** If true, mLimit is ignored */
    private final boolean mInfinite;

    /** Next object to acquire */
    private T mRoot;

    /** Number of objects in the pool */
    private int mPoolCount;

    FinitePool(PoolableManager<T> manager) {
        mManager = manager;
        mLimit = 0;
        mInfinite = true;
    }

    FinitePool(PoolableManager<T> manager, int limit) {
        if (limit <= 0) {
            throw new IllegalArgumentException("The pool limit must be > 0");
        }

        mManager = manager;
        mLimit = limit;
        mInfinite = false;
    }

    public T acquire() {
        T element;

        if (mRoot != null) {
            element = mRoot;
            mRoot = element.getNextPoolable();
            mPoolCount--;
        } else {
            element = mManager.newInstance();
        }

        if (element != null) {
            element.setNextPoolable(null);
            element.setPooled(false);
            mManager.onAcquired(element);
        }

        return element;
    }

    public void release(T element) {
        if (!element.isPooled()) {
            if (mInfinite || mPoolCount < mLimit) {
                mPoolCount++;
                element.setNextPoolable(mRoot);
                element.setPooled(true);
                mRoot = element;
            }
            mManager.onReleased(element);
        } else {
            System.out.print("[FinitePool] Element is already in pool: " + element);
        }
    }
}
