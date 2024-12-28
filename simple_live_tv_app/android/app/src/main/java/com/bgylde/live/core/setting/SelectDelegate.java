package com.bgylde.live.core.setting;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.bgylde.live.R;
import com.bgylde.live.adapter.SelectDialogAdapter;
import com.bgylde.live.core.FlutterManager;
import com.bgylde.live.multitype.ItemViewBinder;
import com.bgylde.live.widgets.SelectDialog;

import java.util.List;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.Setter;

import static com.bgylde.live.adapter.SelectDialogAdapter.stringDiff;

/**
 * Created by wangyan on 2024/12/26
 */
public class SelectDelegate extends ItemViewBinder<SelectDelegate.SelectModel, SelectDelegate.ViewHolder> {

    @NonNull
    @Override
    protected ViewHolder onCreateViewHolder(@NonNull LayoutInflater inflater, @NonNull ViewGroup parent) {
        View view = inflater.inflate(R.layout.item_select, parent, false);
        return new SelectDelegate.ViewHolder(view);
    }

    @Override
    protected void onBindViewHolder(@NonNull ViewHolder holder, @NonNull SelectModel item) {
        holder.setData(item);
    }

    @Getter
    @Setter
    @AllArgsConstructor
    public static class SelectModel {
        private final String selectTitle;

        private final List<String> selectList;

        private int selectedIndex;

        private final SelectDialogAdapter.SelectDialogInterface<String> dialogInterface;

        public String getCurrent() {
            if (selectList == null) {
                return null;
            }

            if (selectedIndex < 0 || selectedIndex >= selectList.size()) {
                return null;
            }

            return selectList.get(selectedIndex);
        }
    }

    public static class ViewHolder extends RecyclerView.ViewHolder {

        private final TextView title;
        private final TextView selectValue;

        public ViewHolder(@NonNull View itemView) {
            super(itemView);
            this.title = itemView.findViewById(R.id.select_title);
            this.selectValue = itemView.findViewById(R.id.select_value);
        }

        public void setData(SelectModel selectModel) {
            this.title.setText(selectModel.getSelectTitle());
            String showValue = selectModel.getCurrent();

            if (showValue == null) {
                selectValue.setVisibility(View.GONE);
                this.itemView.setBackgroundResource(R.color.transparent);
                return;
            }

            selectValue.setVisibility(View.VISIBLE);
            if (selectModel.getDialogInterface() != null) {
                showValue = "< " + selectModel.getDialogInterface().getDisplay(showValue) + " >";
            }

            selectValue.setText(showValue);
            this.itemView.setBackgroundResource(R.drawable.shape_model_focus);
            this.itemView.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    if (selectModel.getSelectList().size() == 2) {
                        int selectIndex = selectModel.getSelectedIndex();
                        selectIndex = selectModel.getSelectList().size() - selectIndex - 1;
                        String value = selectModel.getSelectList().get(selectIndex);
                        if (selectModel.getDialogInterface() != null) {
                            selectModel.getDialogInterface().click(value, selectIndex);
                        }

                        selectModel.setSelectedIndex(selectIndex);
                        String showValue;
                        if (selectModel.getDialogInterface() != null) {
                            showValue = "< " + selectModel.getDialogInterface().getDisplay(value) + " >";
                        } else {
                            showValue = "< " + value + " >";
                        }
                        selectValue.setText(showValue);
                        return;
                    }

                    SelectDialog<String> dialog = new SelectDialog<>(itemView.getContext());
                    dialog.setTip(selectModel.getSelectTitle());
                    dialog.setAdapter(null, new SelectDialogAdapter.SelectDialogInterface<String>() {
                        @Override
                        public void click(String value, int pos) {
                            dialog.cancel();
                            if (selectModel.getDialogInterface() != null) {
                                selectModel.getDialogInterface().click(value, pos);
                            }
                            selectValue.setText(value);
                            selectModel.setSelectedIndex(pos);
                        }

                        @Override
                        public String getDisplay(String val) {
                            if (selectModel.getDialogInterface() != null) {
                                return selectModel.getDialogInterface().getDisplay(val);
                            }

                            return val;
                        }
                    }, stringDiff, selectModel.getSelectList(), selectModel.getSelectedIndex());
                    dialog.show();
                }
            });
        }
    }
}
