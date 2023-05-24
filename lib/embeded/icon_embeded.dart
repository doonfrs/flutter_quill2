import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as flutter_quill;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:font_awesome_flutter_named/font_awesome_flutter_named.dart';

class IconBlockEmbed extends flutter_quill.CustomBlockEmbed {
  const IconBlockEmbed(String value) : super(embedType, value);

  static const String embedType = 'icon';
}

class IconEmbedBuilder extends flutter_quill.EmbedBuilder {
  IconEmbedBuilder();

  @override
  String get key => 'icon';

  @override
  bool get expanded => false;

  @override
  Widget build(
    BuildContext context,
    flutter_quill.QuillController controller,
    flutter_quill.Embed node,
    bool readOnly,
    bool inline,
    TextStyle textStyle,
  ) {
    final iconInfo = jsonDecode(node.value.data);

    String? iconName;
    if (iconInfo != null) {
      iconName = iconInfo['iconName'];
    }
    iconName ??= 'accessibleIcon';

    var color = Colors.black;
    if (iconInfo != null) {
      //convert color from string hex to Color
      var clr = node.style!.attributes['color']?.value?.toString();
      if (clr != null) {
        color = Color(int.parse(clr.replaceAll("#", "FF"), radix: 16));
      }
    }

    return Padding(
        padding: EdgeInsets.only(bottom: (textStyle.fontSize! > 24) ? 0 : 6),
        child: FaIcon(faIconNameMapping[iconName],
            color: color, size: textStyle.fontSize!));
  }

  static void addIcon(
      BuildContext context, flutter_quill.QuillController controller,
      {flutter_quill.Embed? node}) {
    showDialog(
        context: context,
        builder: (context) {
          var searchKey = '';
          Timer? debounce;

          return StatefulBuilder(builder: (context, msetState) {
            final searchedItems = faIconNameMapping.entries
                .where((element) => element.key.contains(searchKey))
                .toList();

            return AlertDialog(
                content: SizedBox(
                    width: 350,
                    height: 410,
                    child: ListView(children: [
                      SizedBox(
                        width: 350,
                        height: 50,
                        child: TextField(
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Search',
                          ),
                          onChanged: (value) {
                            if (debounce?.isActive ?? false) {
                              debounce!.cancel();
                            }
                            debounce =
                                Timer(const Duration(milliseconds: 500), () {
                              msetState(() {
                                searchKey = value;
                              });
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                          width: 350,
                          height: 350,
                          child: GridView.builder(
                            itemCount: searchedItems.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              crossAxisCount: 8,
                            ),
                            itemBuilder: (context, i) {
                              final iconName = searchedItems[i].key;
                              final iconData = searchedItems[i].value;
                              final index = controller.selection.baseOffset;
                              final length =
                                  controller.selection.extentOffset - index;

                              return InkWell(
                                  onTap: () {
                                    final block =
                                        flutter_quill.BlockEmbed.custom(
                                            IconBlockEmbed(
                                      jsonEncode({
                                        'iconName': iconName,
                                      }),
                                    ));

                                    if (node != null) {
                                      final offset = flutter_quill
                                          .getEmbedNode(controller,
                                              controller.selection.start)
                                          .offset;
                                      controller.replaceText(
                                          offset,
                                          1,
                                          block,
                                          TextSelection.collapsed(
                                              offset: offset));
                                    } else {
                                      controller.replaceText(
                                          index, length, block, null);
                                    }
                                    Navigator.pop(context);
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border:
                                          Border.all(color: Colors.grey[300]!),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(iconData),
                                  ));
                            },
                          )),
                    ])));
          });
        });
  }
}
