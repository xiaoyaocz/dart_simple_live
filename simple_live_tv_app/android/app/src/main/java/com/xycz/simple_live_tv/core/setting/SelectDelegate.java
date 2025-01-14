package com.xycz.simple_live_tv.core.setting;

import android.annotation.SuppressLint;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.DiffUtil;
import androidx.recyclerview.widget.RecyclerView;

import com.xycz.simple_live_tv.R;
import com.xycz.simple_live_tv.adapter.SelectAdapter;
import com.xycz.simple_live_tv.multitype.ItemViewBinder;
import com.xycz.simple_live_tv.widgets.SelectDialog;

import java.util.LinkedHashMap;

/**
 * Created by wangyan on 2024/12/26
 */
public class SelectDelegate<T> extends ItemViewBinder<SelectDelegate.SelectModel<T>, SelectDelegate.ViewHolder<T>> {

    @NonNull
    @Override
    protected ViewHolder<T> onCreateViewHolder(@NonNull LayoutInflater inflater, @NonNull ViewGroup parent) {
        View view = inflater.inflate(R.layout.item_select, parent, false);
        return new SelectDelegate.ViewHolder<T>(view);
    }

    @Override
    protected void onBindViewHolder(@NonNull ViewHolder<T> holder, @NonNull SelectModel<T> item) {
        holder.setData(item);
    }

    public static class SelectModel<T> {
        private final String selectTitle;

        private final LinkedHashMap<T, String> selectMap;

        private T selectValue;

        private final SelectAdapter.ISelectDialog<T> selectCallback;

        public SelectModel(String selectTitle, LinkedHashMap<T, String> selectMap, T selectValue, SelectAdapter.ISelectDialog<T> dialogInterface) {
            this.selectTitle = selectTitle;
            this.selectMap = selectMap;
            this.selectCallback = dialogInterface;
            this.selectValue = selectValue;
        }

        public String getSelectTitle() {
            return selectTitle;
        }

        public LinkedHashMap<T, String> getSelectMap() {
            return selectMap;
        }

        public T getSelectValue() {
            return selectValue;
        }

        public void setSelectValue(T selectValue) {
            this.selectValue = selectValue;
        }

        public SelectAdapter.ISelectDialog<T> getSelectCallback() {
            return selectCallback;
        }

        public String getCurrent() {
            if (selectMap == null || selectValue == null) {
                return null;
            }

            return selectMap.get(selectValue);
        }
    }

    public static class ViewHolder<T> extends RecyclerView.ViewHolder {

        private final TextView title;
        private final TextView selectValue;

        private final TextView leftArrow;
        private final TextView rightArrow;

        public ViewHolder(@NonNull View itemView) {
            super(itemView);
            this.title = itemView.findViewById(R.id.select_title);
            this.selectValue = itemView.findViewById(R.id.select_value);
            this.leftArrow = itemView.findViewById(R.id.left_arrow);
            this.rightArrow = itemView.findViewById(R.id.right_arrow);
        }

        public void setData(SelectModel<T> selectModel) {
            this.title.setText(selectModel.getSelectTitle());
            String showValue = selectModel.getCurrent();
            if (showValue == null) {
                this.selectValue.setVisibility(View.GONE);
                this.leftArrow.setVisibility(View.GONE);
                this.rightArrow.setVisibility(View.GONE);
                this.itemView.setBackgroundResource(R.color.transparent);
                this.itemView.setFocusable(false);
                this.itemView.setClickable(false);
                return;
            }

            this.itemView.setFocusable(true);
            this.itemView.setClickable(true);
            this.selectValue.setVisibility(View.VISIBLE);
            this.leftArrow.setVisibility(View.VISIBLE);
            this.rightArrow.setVisibility(View.VISIBLE);
            this.selectValue.setText(showValue);
            this.itemView.setBackgroundResource(R.drawable.shape_model_focus);
            this.itemView.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    if (selectModel.getSelectMap().size() == 2) {
                        T currentKey = selectModel.getSelectValue();
                        LinkedHashMap<T, String> valueMap = selectModel.getSelectMap();
                        for (T key : valueMap.keySet()) {
                            if (!key.equals(currentKey)) {
                                currentKey = key;
                                break;
                            }
                        }

                        String showValue = valueMap.get(currentKey);
                        selectModel.setSelectValue(currentKey);
                        selectValue.setText(showValue);
                        if (selectModel.getSelectCallback() != null) {
                            selectModel.getSelectCallback().click(currentKey, showValue);
                        }

                        return;
                    }

                    SelectDialog<T> dialog = new SelectDialog<>(itemView.getContext());
                    dialog.setTip(selectModel.getSelectTitle());
                    dialog.setAdapter(null, new SelectAdapter.ISelectDialog<T>() {
                        @Override
                        public void click(T key, String value) {
                            dialog.cancel();
                            if (selectModel.getSelectCallback() != null) {
                                selectModel.getSelectCallback().click(key, value);
                            }
                            selectValue.setText(value == null ? "" : value);
                            selectModel.setSelectValue(key);
                        }
                    }, itemDiff, selectModel.getSelectMap(), selectModel.getSelectValue());
                    dialog.show();
                }
            });
        }

        public DiffUtil.ItemCallback<T> itemDiff = new DiffUtil.ItemCallback<T>() {

            @Override
            public boolean areItemsTheSame(@NonNull T oldItem, @NonNull T newItem) {
                return oldItem.equals(newItem);
            }

            @SuppressLint("DiffUtilEquals")
            @Override
            public boolean areContentsTheSame(@NonNull T oldItem, @NonNull T newItem) {
                return oldItem.equals(newItem);
            }
        };
    }
}
