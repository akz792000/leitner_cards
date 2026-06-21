/// String utilities used across the app.
class StringUtil {
  StringUtil._();

  /// Returns true if [text] contains Markdown syntax worth rendering.
  static bool containsMarkdown(String text) => text
      .contains(RegExp(r'\*{1,3}|_{1,3}|^#{1,6}\s|`|\||\~\~', multiLine: true));

  /// Strips Markdown syntax from [text] to produce plain text suitable for
  /// TTS and STT comparison.
  ///
  /// Handles the subset of Markdown used in card content:
  ///   - Headings (#, ##, ###)
  ///   - Bold/italic (**text**, *text*, __text__, _text_)
  ///   - Strikethrough (~~text~~)
  ///   - Inline code (`code`)
  ///   - Table pipes and separator rows (| col | and |---|)
  ///   - Bullet / numbered list markers (-, *, +, 1.)
  ///   - Blockquotes (>)
  ///   - Horizontal rules (---, ***)
  static String stripMarkdown(String text) {
    var s = text;

    // Remove headings: "### Title" → "Title"
    s = s.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');

    // Remove horizontal rules and table separator rows
    s = s.replaceAll(RegExp(r'^\s*[-*_|]{3,}\s*$', multiLine: true), '');

    // Remove table pipes — split cells by | and join with space
    s = s.replaceAll(RegExp(r'\|'), ' ');

    // Remove bold/italic/strikethrough markers
    s = s.replaceAll(RegExp(r'\*{1,3}|_{1,3}|~{2}'), '');

    // Remove inline code backticks
    s = s.replaceAll(RegExp(r'`+'), '');

    // Remove blockquote markers
    s = s.replaceAll(RegExp(r'^>\s*', multiLine: true), '');

    // Remove bullet/numbered list markers at line start
    s = s.replaceAll(RegExp(r'^[\s]*[-*+]\s+', multiLine: true), '');
    s = s.replaceAll(RegExp(r'^[\s]*\d+\.\s+', multiLine: true), '');

    // Collapse multiple spaces / blank lines
    s = s.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
    s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return s.trim();
  }
}
