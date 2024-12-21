package com.bgylde.live.widgets;

import android.content.Context;
import android.os.Bundle;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.DiffUtil;

import com.bgylde.live.R;
import com.bgylde.live.adapter.SelectDialogAdapter;
import com.owen.tvrecyclerview.widget.TvRecyclerView;

import java.util.List;

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

    public void setAdapter(TvRecyclerView tvRecyclerView, SelectDialogAdapter.SelectDialogInterface<T> sourceBeanSelectDialogInterface, DiffUtil.ItemCallback<T> sourceBeanItemCallback, List<T> data, int select) {
        if (select >= data.size() || select < 0) select = 0;//if source update, data item count maybe smaller than before
        final int selectIdx = select;
        SelectDialogAdapter<T> adapter = new SelectDialogAdapter<>(sourceBeanSelectDialogInterface, sourceBeanItemCallback, muteCheck);
        adapter.setData(data, select);
        if(tvRecyclerView == null){
            tvRecyclerView = findViewById(R.id.list);
        }
        tvRecyclerView.setAdapter(adapter);
        tvRecyclerView.setSelectedPosition(select);
        if (select<10){
            tvRecyclerView.setSelection(select);
        }
        TvRecyclerView finalTvRecyclerView = tvRecyclerView;
        tvRecyclerView.post(new Runnable() {
            @Override
            public void run() {//不清楚会不会存在什么问题
                if (selectIdx >= 10) {
                    finalTvRecyclerView.smoothScrollToPosition(selectIdx);
                    finalTvRecyclerView.setSelectionWithSmooth(selectIdx);
                }
            }
        });
    }
}
