/*
 * Copyright (C) 2013 Chen Hui <calmer91@gmail.com>
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

package com.bgylde.live.danmaku.flame.model.android;

import com.bgylde.live.danmaku.flame.model.BaseDanmaku;
import com.bgylde.live.danmaku.flame.model.Danmaku;
import com.bgylde.live.danmaku.flame.model.IDanmakuIterator;
import com.bgylde.live.danmaku.flame.model.IDanmakus;
import com.bgylde.live.danmaku.flame.util.DanmakuUtils;

import java.util.ArrayList;
import java.util.Collection;
import java.util.Comparator;
import java.util.Iterator;
import java.util.List;
import java.util.SortedSet;
import java.util.TreeSet;

public class Danmakus implements IDanmakus {

    public static final int ST_BY_TIME = 0;

    public static final int ST_BY_YPOS = 1;

    public static final int ST_BY_YPOS_DESC = 2;

    /**
     * this type is used to iterate/remove/insert elements, not support sub/subnew
     */
    public static final int ST_BY_LIST = 4;

    public Collection<BaseDanmaku> items;

    private Danmakus subItems;

    private BaseDanmaku startItem, endItem;

    private BaseDanmaku endSubItem;

    private BaseDanmaku startSubItem;

    private DanmakuIterator iterator;

    private int mSize = 0;

    private int mSortType = ST_BY_TIME;

    private BaseComparator mComparator;

    private boolean mDuplicateMergingEnabled;

    public Danmakus() {
        this(ST_BY_TIME, false);
    }

    public Danmakus(int sortType) {
        this(sortType, false);
    }

    public Danmakus(int sortType, boolean duplicateMergingEnabled) {
        BaseComparator comparator = null;
        if (sortType == ST_BY_TIME) {
            comparator = new TimeComparator(duplicateMergingEnabled);
        } else if (sortType == ST_BY_YPOS) {
            comparator = new YPosComparator(duplicateMergingEnabled);
        } else if (sortType == ST_BY_YPOS_DESC) {
            comparator = new YPosDescComparator(duplicateMergingEnabled);
        }
        if(sortType == ST_BY_LIST) {
            items = new ArrayList<BaseDanmaku>();
        } else {
            mDuplicateMergingEnabled = duplicateMergingEnabled;
            comparator.setDuplicateMergingEnabled(duplicateMergingEnabled);
            items = new TreeSet<BaseDanmaku>(comparator);
            mComparator = comparator;
        }
        mSortType = sortType;
        mSize = 0;
        iterator = new DanmakuIterator(items);
    }

    public Danmakus(Collection<BaseDanmaku> items) {
        setItems(items);
    }

    public Danmakus(boolean duplicateMergingEnabled) {
        this(ST_BY_TIME, duplicateMergingEnabled);
    }

    public void setItems(Collection<BaseDanmaku> items) {
        if (mDuplicateMergingEnabled && mSortType != ST_BY_LIST) {
            this.items.clear();
            this.items.addAll(items);
            items = this.items;
        }
        else {
            this.items = items;
        }
        if (items instanceof List) {
            mSortType = ST_BY_LIST;
        }
        mSize = (items == null ? 0 : items.size());
        if (iterator == null) {
            iterator = new DanmakuIterator(items);
        } else {
            iterator.setDatas(items);
        }
    }

    public IDanmakuIterator iterator() {
        iterator.reset();
        return iterator;
    }

    @Override
    public boolean addItem(BaseDanmaku item) {
        if (items != null) {
            try {
                if (items.add(item)) {
                    mSize++;
                    return true;
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
        return false;
    }

    @Override
    public boolean removeItem(BaseDanmaku item) {
        if (item == null) {
            return false;
        }
        if (item.isOutside()) {
            item.setVisibility(false);
        }
        if (items.remove(item)) {
            mSize--;
            return true;
        }
        return false;
    }

    private Collection<BaseDanmaku> subset(long startTime, long endTime) {
        if (mSortType == ST_BY_LIST || items == null || items.size() == 0) {
            return null;
        }
        if (subItems == null) {
            subItems = new Danmakus(mDuplicateMergingEnabled);
        }
        if (startSubItem == null) {
            startSubItem = createItem("start");
        }
        if (endSubItem == null) {
            endSubItem = createItem("end");
        }

        startSubItem.time = startTime;
        endSubItem.time = endTime;
        return ((SortedSet<BaseDanmaku>) items).subSet(startSubItem, endSubItem);
    }

    @Override
    public IDanmakus subnew(long startTime, long endTime) {
        Collection<BaseDanmaku> subset = subset(startTime, endTime);
        if (subset == null || subset.isEmpty()) {
            return null;
        }
        ArrayList<BaseDanmaku> newSet = new ArrayList<BaseDanmaku>(subset);
        return new Danmakus(newSet);
    }

    @Override
    public IDanmakus sub(long startTime, long endTime) {
        if (items == null || items.size() == 0) {
            return null;
        }
        if (subItems == null) {
            if(mSortType == ST_BY_LIST) {
                subItems = new Danmakus(Danmakus.ST_BY_LIST);
                subItems.setItems(items);
            } else {
                subItems = new Danmakus(mDuplicateMergingEnabled);
            }
        }
        if (mSortType == ST_BY_LIST) {
            return subItems;
        }
        if (startItem == null) {
            startItem = createItem("start");
        }
        if (endItem == null) {
            endItem = createItem("end");
        }

        if (subItems != null) {
            long dtime = startTime - startItem.time;
            if (dtime >= 0 && endTime <= endItem.time) {
                return subItems;
            }
        }

        startItem.time = startTime;
        endItem.time = endTime;
        subItems.setItems(((SortedSet<BaseDanmaku>) items).subSet(startItem, endItem));
        return subItems;
    }

    private BaseDanmaku createItem(String text) {
        return new Danmaku(text);
    }

    public int size() {
        return mSize;
    }

    @Override
    public void clear() {
        if (items != null) {
            items.clear();
            mSize = 0;
            iterator = new DanmakuIterator(items);
        }
        if (subItems != null) {
            subItems = null;
            startItem = createItem("start");
            endItem = createItem("end");
        }
    }

    @Override
    public BaseDanmaku first() {
        if (items != null && !items.isEmpty()) {
            if (mSortType == ST_BY_LIST) {
                return ((ArrayList<BaseDanmaku>) items).get(0);
            }
            return ((SortedSet<BaseDanmaku>) items).first();
        }
        return null;
    }

    @Override
    public BaseDanmaku last() {
        if (items != null && !items.isEmpty()) {
            if (mSortType == ST_BY_LIST) {
                return ((ArrayList<BaseDanmaku>) items).get(items.size() - 1);
            }
            return ((SortedSet<BaseDanmaku>) items).last();
        }
        return null;
    }

    private class DanmakuIterator implements IDanmakuIterator{

        private Collection<BaseDanmaku> mData;
        private Iterator<BaseDanmaku> it;
        private boolean mIteratorUsed;

        public DanmakuIterator(Collection<BaseDanmaku> datas){
            setDatas(datas);
        }

        public synchronized void reset() {
            if (!mIteratorUsed && it != null) {
                return;
            }
            if (mData != null && mSize > 0) {
                it = mData.iterator();
            } else {
                it = null;
            }
            mIteratorUsed = false;
        }

        public synchronized void setDatas(Collection<BaseDanmaku> datas){
            if (mData != datas) {
                mIteratorUsed = false;
                it = null;
            }
            mData = datas;
        }

        @Override
        public synchronized BaseDanmaku next() {
            mIteratorUsed = true;
            return it != null ? it.next() : null;
        }

        @Override
        public synchronized boolean hasNext() {
            return it != null && it.hasNext();
        }

        @Override
        public synchronized void remove() {
            mIteratorUsed = true;
            if (it != null) {
                it.remove();
                mSize--;
            }
        }

    }

    private class BaseComparator implements Comparator<BaseDanmaku> {

        protected boolean mDuplicateMergingEnable;

        public BaseComparator(boolean duplicateMergingEnabled) {
            setDuplicateMergingEnabled(duplicateMergingEnabled);
        }

        public void setDuplicateMergingEnabled(boolean enable) {
            mDuplicateMergingEnable = enable;
        }

        @Override
        public int compare(BaseDanmaku obj1, BaseDanmaku obj2) {
            if (mDuplicateMergingEnable && DanmakuUtils.isDuplicate(obj1, obj2)) {
                return 0;
            }
            return DanmakuUtils.compare(obj1, obj2);
        }

    }

    private class TimeComparator extends BaseComparator {

        public TimeComparator(boolean duplicateMergingEnabled) {
            super(duplicateMergingEnabled);
        }

        @Override
        public int compare(BaseDanmaku obj1, BaseDanmaku obj2) {
            return super.compare(obj1, obj2);
        }
    }

    private class YPosComparator extends BaseComparator {

        public YPosComparator(boolean duplicateMergingEnabled) {
            super(duplicateMergingEnabled);
        }

        @Override
        public int compare(BaseDanmaku obj1, BaseDanmaku obj2) {
            if (mDuplicateMergingEnable && DanmakuUtils.isDuplicate(obj1, obj2)) {
                return 0;
            }
            return Float.compare(obj1.getTop(), obj2.getTop());
        }
    }

    private class YPosDescComparator extends BaseComparator {

        public YPosDescComparator(boolean duplicateMergingEnabled) {
            super(duplicateMergingEnabled);
        }

        @Override
        public int compare(BaseDanmaku obj1, BaseDanmaku obj2) {
            if (mDuplicateMergingEnable && DanmakuUtils.isDuplicate(obj1, obj2)) {
                return 0;
            }
            return Float.compare(obj2.getTop(), obj1.getTop());
        }
    }

    @Override
    public boolean contains(BaseDanmaku item) {
        return this.items != null && this.items.contains(item);
    }

    @Override
    public boolean isEmpty() {
        return this.items == null || this.items.isEmpty();
    }

    private void setDuplicateMergingEnabled(boolean enable) {
        mComparator.setDuplicateMergingEnabled(enable);
        mDuplicateMergingEnabled = enable;
    }

    @Override
    public void setSubItemsDuplicateMergingEnabled(boolean enable) {
        mDuplicateMergingEnabled = enable;
        startItem = endItem = null;
        if (subItems == null) {
            subItems = new Danmakus(enable);
        }
        subItems.setDuplicateMergingEnabled(enable);
    }

}