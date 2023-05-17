import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

class QuillHelper {
  static String quillToHtml(List<Map<String, dynamic>> delta) {
    return QuillDeltaToHtmlConverter(delta, ConverterOptions.forEmail())
        .convert();
  }
}
