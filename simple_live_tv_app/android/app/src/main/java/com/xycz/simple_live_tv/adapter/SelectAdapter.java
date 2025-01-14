package com.xycz.simple_live_tv.adapter;

import android.annotation.SuppressLint;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.DiffUtil;
import androidx.recyclerview.widget.ListAdapter;
import androidx.recyclerview.widget.RecyclerView;

import com.xycz.simple_live_tv.R;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;

public class SelectAdapter<T> extends ListAdapter<T, SelectAdapter.SelectViewHolder> {

    private boolean muteCheck = false;

    public static class SelectViewHolder extends RecyclerView.ViewHolder {
        public SelectViewHolder(@NonNull View itemView) {
            super(itemView);
        }
    }

    public interface ISelectDialog<T> {
        void click(T key, String value);
    }

    private final LinkedHashMap<T, String> dataMap = new LinkedHashMap<>();
    private final List<T> keyList = new ArrayList<>();

    private T select = null;

    private ISelectDialog<T> dialogInterface = null;

    public SelectAdapter(ISelectDialog<T> dialogInterface, DiffUtil.ItemCallback<T> diffCallback) {
        this(dialogInterface, diffCallback, false);
    }

    public SelectAdapter(ISelectDialog<T> dialogInterface, DiffUtil.ItemCallback<T> diffCallback, boolean muteCheck) {
        super(diffCallback);
        this.dialogInterface = dialogInterface;
        this.muteCheck = muteCheck;
    }

    public void setData(LinkedHashMap<T, String> newData, T defaultSelect) {
        dataMap.clear();
        dataMap.putAll(newData);
        keyList.clear();
        keyList.addAll(newData.keySet());
        select = defaultSelect;
        notifyDataSetChanged();
    }

    @Override
    public int getItemCount() {
        return dataMap.size();
    }


    @NonNull
    @Override
    public SelectViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        return new SelectViewHolder(LayoutInflater.from(parent.getContext()).inflate(R.layout.item_dialog_select, parent, false));
    }

    @Override
    public void onBindViewHolder(@NonNull SelectAdapter.SelectViewHolder holder, @SuppressLint("RecyclerView") int position) {
        T selectKey = keyList.get(position);
        final String value = dataMap.get(selectKey);
        String showValue = value;
        if (!muteCheck && selectKey == select) {
            showValue = "√ " + showValue;
        }

        ((TextView) holder.itemView.findViewById(R.id.tvName)).setText(showValue);
        holder.itemView.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                if (!muteCheck && selectKey == select) {
                    return;
                }

                notifyItemChanged(position);
                select = selectKey;
                notifyItemChanged(position);
                dialogInterface.click(selectKey, value);
            }
        });
    }
}