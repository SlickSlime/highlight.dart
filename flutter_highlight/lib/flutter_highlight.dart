import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight_background.dart';
import 'package:highlight/highlight.dart' show highlight, Node;

/// Highlight Flutter Widget
class HighlightView extends StatefulWidget {
  /// The original code to be highlighted
  final String source;

  /// Highlight language
  ///
  /// It is recommended to give it a value for performance
  ///
  /// [All available languages](https://github.com/pd4d10/highlight/tree/master/highlight/lib/languages)
  final String? language;

  /// Highlight theme
  ///
  /// [All available themes](https://github.com/pd4d10/highlight/blob/master/flutter_highlight/lib/themes)
  final Map<String, TextStyle> theme;

  /// Padding
  final EdgeInsetsGeometry? padding;

  /// Text styles
  ///
  /// Specify text styles such as font family and font size
  final TextStyle? textStyle;

  /// Progress indicator
  ///
  /// A widget that is displayed while the [source] is being processed.
  /// This may only be used if a [HighlightBackgroundEnvironment] is available.
  final Widget? progressIndicator;

  HighlightView(
    String input, {
    this.language,
    this.theme = const {},
    this.padding,
    this.textStyle,
    int tabSize = 8, // TODO: https://github.com/flutter/flutter/issues/50087
    this.progressIndicator,
  }) : source = input.replaceAll('\t', ' ' * tabSize);

  static const _rootKey = 'root';
  static const _defaultFontColor = Color(0xff000000);
  static const _defaultBackgroundColor = Color(0xffffffff);

  // TODO: dart:io is not available at web platform currently
  // See: https://github.com/flutter/flutter/issues/39998
  // So we just use monospace here for now
  static const _defaultFontFamily = 'monospace';

  @override
  State<HighlightView> createState() => _HighlightViewState();
}

class _HighlightViewState extends State<HighlightView> {
  late Future<List<Node>> _nodesFuture;
  late Future<List<TextSpan>> _spansFuture;

  List<TextSpan> _convert(List<Node> nodes) {
    List<TextSpan> spans = [];
    var currentSpans = spans;
    List<List<TextSpan>> stack = [];

    _traverse(Node node) {
      if (node.value != null) {
        currentSpans.add(node.className == null
            ? TextSpan(text: node.value)
            : TextSpan(text: node.value, style: widget.theme[node.className!]));
      } else if (node.children != null) {
        List<TextSpan> tmp = [];
        currentSpans
            .add(TextSpan(children: tmp, style: widget.theme[node.className!]));
        stack.add(currentSpans);
        currentSpans = tmp;

        node.children!.forEach((n) {
          _traverse(n);
          if (n == node.children!.last) {
            currentSpans = stack.isEmpty ? spans : stack.removeLast();
          }
        });
      }
    }

    for (var node in nodes) {
      _traverse(node);
    }

    return spans;
  }

  void _parse(HighlightBackgroundProvider? backgroundProvider) => _nodesFuture =
      backgroundProvider?.parse(widget.source, language: widget.language) ??
          Future.value(
            highlight.parse(widget.source, language: widget.language).nodes,
          );

  void _generateSpans() => _spansFuture = _nodesFuture.then(_convert);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final backgroundProvider = HighlightBackgroundProvider.maybeOf(context);
    _parse(backgroundProvider);
    _generateSpans();
  }

  @override
  void didUpdateWidget(HighlightView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.source != oldWidget.source ||
        widget.language != oldWidget.language) {
      final backgroundProvider = HighlightBackgroundProvider.maybeOf(context);
      _parse(backgroundProvider);
      _generateSpans();
    } else if (widget.theme != oldWidget.theme) {
      _generateSpans();
    }
  }

  @override
  Widget build(BuildContext context) {
    var _textStyle = TextStyle(
      fontFamily: HighlightView._defaultFontFamily,
      color: widget.theme[HighlightView._rootKey]?.color ??
          HighlightView._defaultFontColor,
    );
    if (widget.textStyle != null) {
      _textStyle = _textStyle.merge(widget.textStyle);
    }

    return Container(
      color: widget.theme[HighlightView._rootKey]?.backgroundColor ??
          HighlightView._defaultBackgroundColor,
      padding: widget.padding,
      child: FutureBuilder<List<TextSpan>>(
        future: _spansFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            final progressIndicator = widget.progressIndicator;
            if (progressIndicator == null) {
              return const SizedBox.shrink();
            } else {
              assert(
                HighlightBackgroundProvider.maybeOf(context) != null,
                'Cannot display a progress indicator unless a HighlightBackgroundEnvironment is available!',
              );
              return progressIndicator;
            }
          }
          return SelectableText.rich(
            TextSpan(
              style: _textStyle,
              children: snapshot.requireData,
            ),
          );
        },
      ),
    );
  }
}
