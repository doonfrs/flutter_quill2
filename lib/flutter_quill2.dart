import 'dart:async';
import 'dart:io';

import 'package:filesystem_picker/filesystem_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/extensions.dart';
import 'package:flutter_quill/flutter_quill.dart' as flutter_quill;
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
    required this.controller,
    this.readOnly = false,
    this.toolbarHeight = 50,
    Key? key,
  }) : super(key: key);
  final flutter_quill.QuillController controller;
  final bool readOnly;
  final double toolbarHeight;
  @override
  _FlutterQuill2State createState() => _FlutterQuill2State();
}

class _FlutterQuill2State extends State<FlutterQuill2> {
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
    _controller = widget.controller;
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

      _controller.updateSelection(selection, flutter_quill.ChangeSource.REMOTE);

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
        controller: _controller,
        scrollController: ScrollController(),
        scrollable: true,
        focusNode: _focusNode,
        autoFocus: false,
        readOnly: widget.readOnly,
        showCursor: !widget.readOnly,
        placeholder: '',
        enableSelectionToolbar: isMobile(),
        expands: false,
        padding: EdgeInsets.zero,
        onImagePaste: _onImagePaste,
        onTapUp: (details, p1) {
          return _onTripleClickSelection();
        },
        customStyles: flutter_quill.DefaultStyles(
          h1: flutter_quill.DefaultTextBlockStyle(
              const TextStyle(
                fontSize: 32,
                color: Colors.black,
                height: 1.15,
                fontWeight: FontWeight.w300,
              ),
              const flutter_quill.VerticalSpacing(16, 0),
              const flutter_quill.VerticalSpacing(0, 0),
              null),
          sizeSmall: const TextStyle(fontSize: 9),
        ),
        embedBuilders: [
          IconEmbedBuilder(),
          NotesEmbedBuilder(addEditNote: _addEditNote),
        ],
      ),
    );

    final toolbar = flutter_quill.QuillToolbar.basic(
      showDirection: true,
      controller: _controller,
      customButtons: [
        flutter_quill.QuillCustomButton(
            icon: Icons.note_add,
            onTap: () {
              _addEditNote(context);
            }),
        flutter_quill.QuillCustomButton(
            icon: Icons.icecream_outlined,
            onTap: () {
              IconEmbedBuilder.addIcon(context, _controller);
            }),
      ],
      showAlignmentButtons: true,
      afterButtonPressed: _focusNode.requestFocus,
    );

    return Stack(children: [
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
    ]);
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
              icon: const Icon(Icons.close),
            )
          ],
        ),
        content: flutter_quill.QuillEditor.basic(
          controller: quillEditorController,
          readOnly: false,
        ),
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

  Future<void> _insertIcon(
    BuildContext context,
  ) async {
    final block = flutter_quill.BlockEmbed.custom(
      const IconBlockEmbed(''),
    );
    final controller = _controller;
    final index = controller.selection.baseOffset;
    final length = controller.selection.extentOffset - index;

    controller.replaceText(index, length, block, null);
  }
}
