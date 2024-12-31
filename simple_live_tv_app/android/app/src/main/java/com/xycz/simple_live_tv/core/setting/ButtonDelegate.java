package com.xycz.simple_live_tv.core.setting;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.xycz.simple_live_tv.R;
import com.xycz.simple_live_tv.multitype.ItemViewBinder;

/**
 * Created by wangyan on 2024/12/26
 */
public class ButtonDelegate extends ItemViewBinder<ButtonDelegate.ButtonModel, ButtonDelegate.ViewHolder> {

    @NonNull
    @Override
    protected ViewHolder onCreateViewHolder(@NonNull LayoutInflater inflater, @NonNull ViewGroup parent) {
        View view = inflater.inflate(R.layout.item_button, parent, false);
        return new ViewHolder(view);
    }

    @Override
    protected void onBindViewHolder(@NonNull ViewHolder holder, @NonNull ButtonModel item) {
        holder.setData(item);
    }

    public static class ButtonModel {
        private final String title;

        private final String buttonContent;

        private final View.OnClickListener clickListener;

        public ButtonModel(String title, String buttonContent, View.OnClickListener clickListener) {
            this.title = title;
            this.buttonContent = buttonContent;
            this.clickListener = clickListener;
        }
    }

    public static class ViewHolder extends RecyclerView.ViewHolder {

        private final ImageView button;
        private final TextView title;

        public ViewHolder(@NonNull View itemView) {
            super(itemView);
            this.button = itemView.findViewById(R.id.button_content);
            this.title = itemView.findViewById(R.id.item_title);
        }

        public void setData(ButtonModel buttonModel) {
            this.title.setText(buttonModel.title);
            this.button.setOnClickListener(buttonModel.clickListener);
        }
    }
}
