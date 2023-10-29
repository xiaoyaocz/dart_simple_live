import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';


class AppstyleSettingPage extends GetView<AppSettingsController> {

  const AppstyleSettingPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("主题设置"),
      ),
      body: ListView(
        padding: AppStyle.edgeInsetsV12,
        children: [
          ListTile(
            leading: Icon(Get.isDarkMode ? Remix.moon_line : Remix.sun_line),
            title: Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: const Text("显示主题"),
            ),
            trailing: const Icon(
              Icons.chevron_right,
              color: Colors.grey,
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 24.0),
            onTap: Get.find<AppSettingsController>().changeTheme,
          ),
          Obx(
                () => RadioListTile(
              value: true,
              groupValue: controller.isDynamic.value,
              onChanged: (e) {
                controller.setIsDynamic(e ?? true);
                Get.forceAppUpdate();
              },
              title: const Text("动态取色"),
            ),
          ),
          Obx(()
          {
              return RadioListTile(
                value: false,
                groupValue: controller.isDynamic.value,
                onChanged: (e) {
                  controller.setIsDynamic(e ?? false);
                  Get.forceAppUpdate();
                },
                title: const Text("选定颜色"),
              );
            },
          ),
          Divider(
            indent: 12,
            endIndent: 12,
            color: Colors.grey.withOpacity(.1),
          ),
          Obx(() => AnimatedOpacity(
            opacity: controller.isDynamic.value?0:1,
            duration: 0.5.seconds,
            child: Container(
              width: double.infinity,
              child: Column(
                children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ColorBox(color: Color(0xffEF5350), name: '红色',),
                        ColorBox(color: Color(0xff3498db), name: '蓝色',),
                        ColorBox(color: Color(0xffF06292), name: '粉色',),
                        ColorBox(color: Color(0xff9575CD), name: '紫色',),
                      ],
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ColorBox(color: Color(0xff26C6DA), name: '青色',),
                      ColorBox(color: Color(0xff26A69A), name: '绿色',),
                      ColorBox(color: Color(0xffFFF176), name: '黄色',),
                      ColorBox(color: Color(0xffFF9800), name: '橙色',),
                    ],
                  )
                ],
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }
}

class ColorBox extends GetView<AppSettingsController>  {
  final Color color;
  final String name;

  ColorBox({required this.color, required this.name});

  @override
  Widget build(BuildContext context) {
    return  GestureDetector(
      onTap: (){
        controller.setStyleColor(color.value);
        Get.forceAppUpdate();
      },
      child: Column(
        children: [
          Obx(() => Container(
            width: 70.0,
            height: 40.0,
            margin: const EdgeInsets.only(left: 7.0,right: 7.0,top: 7.0,bottom: 2.0),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4.0)
            ),
            child: AnimatedOpacity(
              opacity: controller.styleColor.value==color.value?1:0,
              duration: 0.4.seconds,
              child: Container(
                decoration:  BoxDecoration(
                    borderRadius: BorderRadius.circular(4.0),
                    border: Border.all(color: Colors.black,width: 1),
                ),
                child: Icon(Icons.check,color: Colors.white,),
              )
            )
          ),
          ),
          Text(name)
        ],
      ),
    );

  }
}

