import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:url_launcher/url_launcher_string.dart';

class SponsorPage extends StatelessWidget {
  const SponsorPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("赞助作者"),
      ),
      body: ListView(
        padding: AppStyle.edgeInsetsA12,
        children: [
          const Padding(
            padding: AppStyle.edgeInsetsB12,
            child: Text(
              "觉得本程序好用就赞助我喝杯咖啡☕吧~\n感谢您的支持(*^▽^*)",
              style: TextStyle(fontSize: 16),
            ),
          ),
          AppStyle.vGap12,
          ListTile(
            leading: Icon(
              Remix.alipay_fill,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text("支付宝"),
            onTap: () {
              launchUrlString(
                "https://qr.alipay.com/fkx19511ajhmvikhwnfwnfd",
                mode: LaunchMode.externalApplication,
              );
            },
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => showQRCode(context, "支付宝"),
                  icon: Icon(
                    Remix.qr_code_line,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(
              Remix.wechat_pay_fill,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text("微信扫码"),
            onTap: () {
              showQRCode(context, "微信");
            },
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => showQRCode(context, "微信"),
                  icon: Icon(
                    Remix.qr_code_line,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                ),
              ],
            ),
          ),
          AppStyle.vGap12,
          const Text(
            "本程序开源可免费使用，您的赞助视为无偿支持开发者。",
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  void showQRCode(BuildContext context, String name) {
    var img = name == "支付宝"
        ? "assets/sponsor/alipay.png"
        : "assets/sponsor/wechat.png";
    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(name),
              contentPadding: AppStyle.edgeInsetsL12,
              trailing: IconButton(
                onPressed: Get.back,
                icon: const Icon(Icons.close),
              ),
            ),
            Padding(
              padding: AppStyle.edgeInsetsA12,
              child: Image.asset(
                img,
                width: 200,
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                try {
                  if (!await Utils.checkPhotoPermission()) {
                    return;
                  }
                  var imgBytes = await rootBundle.load(img);

                  await ImageGallerySaver.saveImage(
                    imgBytes.buffer.asUint8List(),
                    name: name,
                    isReturnImagePathOfIOS: true,
                  );
                  SmartDialog.showToast("已保存至相册，谢谢老板( •̀ ω •́ )✧");
                } catch (e) {
                  SmartDialog.showToast("保存失败");
                }
              },
              icon: const Icon(Icons.save),
              label: const Text("保存"),
            )
          ],
        ),
      ),
    );
  }
}
