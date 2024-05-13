// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';

import 'package:filesystem_picker/filesystem_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/extensions.dart';
import 'package:flutter_quill/flutter_quill.dart' as flutter_quill;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:measure_size/measure_size.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import 'embeded/icon_embeded.dart';
import 'embeded/notes_embed.dart';

export 'package:flutter_quill/src/models/documents/document.dart';
export 'package:flutter_quill/src/widgets/controller.dart';

enum _SelectionType {
  none,
  word,
  // line,
}

class FlutterQuill2 extends StatefulWidget {
  const FlutterQuill2({
    this.controller,
    this.readOnly = false,
    this.toolbarHeight = 50,
    this.delta,
    super.key,
  });
  final flutter_quill.QuillController? controller;
  final List<dynamic>? delta;
  final bool readOnly;
  final double toolbarHeight;
  @override
  FlutterQuill2State createState() => FlutterQuill2State();
}

class FlutterQuill2State extends State<FlutterQuill2> {
  late final flutter_quill.QuillController _controller;
  final FocusNode _focusNode = FocusNode();
  Timer? _selectAllTimer;
  _SelectionType _selectionType = _SelectionType.none;
  double? _toolbarHeight;

  @override
  void dispose() {
    _selectAllTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    _controller = widget.controller ??
        flutter_quill.QuillController(
          document: widget.delta != null
              ? flutter_quill.Document.fromJson(widget.delta!)
              : flutter_quill.Document(),
          selection: const TextSelection.collapsed(offset: 0),
        );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return _buildEditor(context);
  }

  bool _onTripleClickSelection() {
    _selectAllTimer?.cancel();
    _selectAllTimer = null;

    if (_controller.selection.isCollapsed) {
      _selectionType = _SelectionType.none;
    }

    if (_selectionType == _SelectionType.none) {
      _selectionType = _SelectionType.word;
      _startTripleClickTimer();
      return false;
    }

    if (_selectionType == _SelectionType.word) {
      final child = _controller.document.queryChild(
        _controller.selection.baseOffset,
      );
      final offset = child.node?.documentOffset ?? 0;
      final length = child.node?.length ?? 0;

      final selection = TextSelection(
        baseOffset: offset,
        extentOffset: offset + length,
      );

      _controller.updateSelection(selection, flutter_quill.ChangeSource.remote);

      _selectionType = _SelectionType.none;

      _startTripleClickTimer();

      return true;
    }

    return false;
  }

  void _startTripleClickTimer() {
    _selectAllTimer = Timer(const Duration(milliseconds: 900), () {
      _selectionType = _SelectionType.none;
    });
  }

  Widget _buildEditor(BuildContext context) {
    final quillEditor = MouseRegion(
        cursor: SystemMouseCursors.text,
        child: flutter_quill.QuillEditor(
          focusNode: _focusNode,
          scrollController: ScrollController(),
          configurations: flutter_quill.QuillEditorConfigurations(
            readOnly: widget.readOnly,
            showCursor: !widget.readOnly,
            placeholder: '',
            enableSelectionToolbar: isMobile(supportWeb: true),
            onImagePaste: _onImagePaste,
            onTapUp: (details, p1) {
              return _onTripleClickSelection();
            },
            customStyles: const flutter_quill.DefaultStyles(
              h1: flutter_quill.DefaultTextBlockStyle(
                  TextStyle(
                    fontSize: 32,
                    color: Colors.black,
                    height: 1.15,
                    fontWeight: FontWeight.w300,
                  ),
                  flutter_quill.VerticalSpacing(16, 0),
                  flutter_quill.VerticalSpacing(0, 0),
                  null),
              sizeSmall: TextStyle(fontSize: 9),
            ),
            embedBuilders: [
              IconEmbedBuilder(),
              NotesEmbedBuilder(addEditNote: _addEditNote),
            ],
          ),
        ));

    final toolbar = flutter_quill.QuillToolbar(
      configurations: flutter_quill.QuillToolbarConfigurations(
        showDirection: true,
        customButtons: [
          flutter_quill.QuillToolbarCustomButtonOptions(
              controller: _controller,
              icon: const Icon(Icons.note_add),
              afterButtonPressed: () {
                _addEditNote(context);
                _focusNode.requestFocus();
              }),
          flutter_quill.QuillToolbarCustomButtonOptions(
              icon: const Icon(Icons.icecream_outlined),
              afterButtonPressed: () {
                IconEmbedBuilder.addIcon(context, _controller);
                _focusNode.requestFocus();
              }),
        ],
        showAlignmentButtons: true,
      ),
    );

    return flutter_quill.QuillProvider(
        configurations: flutter_quill.QuillConfigurations(
          controller: _controller,
          sharedConfigurations: const flutter_quill.QuillSharedConfigurations(
            locale: Locale('de'),
          ),
        ),
        child: Stack(children: [
          Padding(
              padding: EdgeInsets.only(top: _toolbarHeight ?? 0),
              child: quillEditor),
          if (!widget.readOnly)
            MeasureSize(
              child: toolbar,
              onChange: (size) {
                setState(() {
                  _toolbarHeight = size.height;
                });
              },
            ),
        ]));
  }

  Future<String?> openFileSystemPickerForDesktop(BuildContext context) async {
    return await FilesystemPicker.open(
      context: context,
      rootDirectory: await getApplicationDocumentsDirectory(),
      fsType: FilesystemType.file,
      fileTileSelectMode: FileTileSelectMode.wholeTile,
    );
  }

  Future<String> _onImagePaste(Uint8List imageBytes) async {
    // Saves the image to applications directory
    final appDocDir = await getApplicationDocumentsDirectory();
    final file = await File(
            '${appDocDir.path}/${basename('${DateTime.now().millisecondsSinceEpoch}.png')}')
        .writeAsBytes(imageBytes, flush: true);
    return file.path.toString();
  }

  Future<void> _addEditNote(BuildContext context,
      {flutter_quill.Document? document}) async {
    final isEditing = document != null;
    final quillEditorController = flutter_quill.QuillController(
      document: document ?? flutter_quill.Document(),
      selection: const TextSelection.collapsed(offset: 0),
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.only(left: 16, top: 8),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${isEditing ? 'Edit' : 'Add'} note'),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const FaIcon(FontAwesomeIcons.xmark),
            )
          ],
        ),
        content: flutter_quill.QuillProvider(
            configurations: flutter_quill.QuillConfigurations(
              controller: quillEditorController,
              sharedConfigurations:
                  const flutter_quill.QuillSharedConfigurations(
                locale: Locale('de'),
              ),
            ),
            child: flutter_quill.QuillEditor.basic()),
      ),
    );

    if (quillEditorController.document.isEmpty()) return;

    final block = flutter_quill.BlockEmbed.custom(
      NotesBlockEmbed.fromDocument(quillEditorController.document),
    );
    final controller = _controller;
    final index = controller.selection.baseOffset;
    final length = controller.selection.extentOffset - index;

    if (isEditing) {
      final offset = flutter_quill
          .getEmbedNode(controller, controller.selection.start)
          .offset;
      controller.replaceText(
          offset, 1, block, TextSelection.collapsed(offset: offset));
    } else {
      controller.replaceText(index, length, block, null);
    }
  }
}
