package com.xycz.simple_live_tv.widgets;

import android.content.Context;
import android.os.Bundle;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.DiffUtil;

import com.xycz.simple_live_tv.R;
import com.xycz.simple_live_tv.adapter.SelectAdapter;
import com.owen.tvrecyclerview.widget.TvRecyclerView;

import java.util.LinkedHashMap;

public class SelectDialog<T> extends BaseDialog {

    private boolean muteCheck = false;

    public SelectDialog(@NonNull Context context) {
        super(context);
        setContentView(R.layout.dialog_select);
    }

    public SelectDialog(@NonNull Context context, int resId) {
        super(context);
        setContentView(resId);
    }

    public void setItemCheckDisplay(boolean shouldShowCheck) {
        muteCheck = !shouldShowCheck;
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
    }

    public void setTip(String tip) {
        ((TextView) findViewById(R.id.title)).setText(tip);
    }

    public void setAdapter(TvRecyclerView tvRecyclerView, SelectAdapter.ISelectDialog<T> selectDialogCb, DiffUtil.ItemCallback<T> itemDiffCallback, LinkedHashMap<T, String> data, T select) {
        int selectIndex = 0;
        if (select == null) {
            for (T key : data.keySet()) {
                select = key;
                break;
            }
        } else {
            int index = 0;
            for (T key : data.keySet()) {
                if (key == select) {
                    selectIndex = index;
                    break;
                }

                index++;
            }
        }

        SelectAdapter<T> adapter = new SelectAdapter<>(selectDialogCb, itemDiffCallback, muteCheck);
        adapter.setData(data, select);
        if (tvRecyclerView == null) {
            tvRecyclerView = findViewById(R.id.list);
        }

        tvRecyclerView.setAdapter(adapter);
        tvRecyclerView.setSelectedPosition(selectIndex);
        if (selectIndex < 10) {
            tvRecyclerView.setSelection(selectIndex);
        }

        TvRecyclerView finalTvRecyclerView = tvRecyclerView;
        int finalSelectIndex = selectIndex;
        tvRecyclerView.post(new Runnable() {
            @Override
            public void run() {
                finalTvRecyclerView.smoothScrollToPosition(finalSelectIndex);
                finalTvRecyclerView.setSelectionWithSmooth(finalSelectIndex);
            }
        });
    }
}
