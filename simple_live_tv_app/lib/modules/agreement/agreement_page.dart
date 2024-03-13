import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_tv_app/routes/route_path.dart';
import 'package:simple_live_tv_app/widgets/app_scaffold.dart';
import 'package:simple_live_tv_app/widgets/button/highlight_button.dart';

class AgreementPage extends StatelessWidget {
  const AgreementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Center(
        child: SizedBox(
          width: 1000.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "使用须知",
                textAlign: TextAlign.center,
                style: AppStyle.titleStyleWhite,
              ),
              AppStyle.vGap24,
              Text(
                "欢迎使用Simple Live TV，请在使用前仔细阅读以下内容：",
                style: AppStyle.textStyleWhite,
              ),
              AppStyle.vGap12,
              Text(
                "1. 本软件为开源软件，仅供学习交流使用，禁止用于任何商业用途。",
                style: AppStyle.textStyleWhite,
              ),
              AppStyle.vGap12,
              Text(
                "2. 本软件不提供任何直播内容，所有直播内容均来自网络。",
                style: AppStyle.textStyleWhite,
              ),
              AppStyle.vGap12,
              Text(
                "3. 本软件完全基于您个人意愿使用，您应该对自己的使用行为和所有结果承担全部责任。",
                style: AppStyle.textStyleWhite,
              ),
              AppStyle.vGap12,
              Text(
                "4. 如果本软件存在侵犯您的合法权益的情况，请及时与作者联系，作者将会及时删除有关内容。",
                style: AppStyle.textStyleWhite,
              ),
              AppStyle.vGap12,
              Text(
                "如您继续使用本软件即代表您已完全理解并同意上述内容。",
                style: AppStyle.textStyleWhite,
              ),
              AppStyle.vGap32,
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  HighlightButton(
                    text: "已阅读并同意",
                    autofocus: true,
                    focusNode: AppFocusNode(),
                    onTap: () {
                      AppSettingsController.instance.setNoFirstRun();
                      Get.offAllNamed(RoutePath.kHome);
                    },
                  ),
                  AppStyle.hGap32,
                  HighlightButton(
                    text: "退出应用",
                    focusNode: AppFocusNode(),
                    onTap: () {
                      //退出软件
                      exit(0);
                    },
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
