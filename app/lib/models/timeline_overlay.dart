enum OverlayType { text, image }

extension OverlayTypeX on OverlayType {
  String get wire => name; // 'text' | 'image'

  static OverlayType fromWire(String s) => OverlayType.values
      .firstWhere((v) => v.name == s, orElse: () => OverlayType.text);
}

/// A text or image element layered on top of the stitched timeline.
///
/// [startSeconds] / [durationSeconds] are relative to the TIMELINE's own
/// composed duration (post-cut), NOT the original source video — an
/// overlay at startSeconds=5 always appears 5s into the exported result,
/// regardless of which source clip that lands in.
///
/// [x] / [y] / [widthFrac] / [heightFrac] are normalized 0.0–1.0 so
/// overlays stay correctly positioned no matter the export resolution.
class TimelineOverlay {
  final String      id;
  final OverlayType type;
  final String      content;   // text string, or image file path
  final double      startSeconds;
  final double      durationSeconds;
  final double      x;
  final double      y;
  final double?     fontSize;  // text only
  final String?     colorHex;  // text only, e.g. '#FFFFFF'
  final double?     widthFrac; // image only
  final double?     heightFrac; // image only

  const TimelineOverlay({
    required this.id,
    required this.type,
    required this.content,
    required this.startSeconds,
    required this.durationSeconds,
    required this.x,
    required this.y,
    this.fontSize,
    this.colorHex,
    this.widthFrac,
    this.heightFrac,
  });

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'id':              id,
    'type':            type.wire,
    'content':         content,
    'startSeconds':    startSeconds,
    'durationSeconds': durationSeconds,
    'x':               x,
    'y':               y,
    'fontSize':        fontSize,
    'colorHex':        colorHex,
    'widthFrac':       widthFrac,
    'heightFrac':      heightFrac,
  };

  factory TimelineOverlay.fromJson(Map<String, dynamic> j) => TimelineOverlay(
    id:              j['id']              as String,
    type:            OverlayTypeX.fromWire(j['type'] as String),
    content:         j['content']         as String,
    startSeconds:    (j['startSeconds']    as num).toDouble(),
    durationSeconds: (j['durationSeconds'] as num).toDouble(),
    x:               (j['x'] as num).toDouble(),
    y:               (j['y'] as num).toDouble(),
    fontSize:        (j['fontSize']   as num?)?.toDouble(),
    colorHex:        j['colorHex']   as String?,
    widthFrac:       (j['widthFrac']  as num?)?.toDouble(),
    heightFrac:      (j['heightFrac'] as num?)?.toDouble(),
  );

  TimelineOverlay copyWith({
    String? content,
    double? startSeconds,
    double? durationSeconds,
    double? x,
    double? y,
    double? fontSize,
    String? colorHex,
    double? widthFrac,
    double? heightFrac,
  }) => TimelineOverlay(
    id:              id,
    type:            type,
    content:         content ?? this.content,
    startSeconds:    startSeconds ?? this.startSeconds,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    x:               x ?? this.x,
    y:               y ?? this.y,
    fontSize:        fontSize ?? this.fontSize,
    colorHex:        colorHex ?? this.colorHex,
    widthFrac:       widthFrac ?? this.widthFrac,
    heightFrac:      heightFrac ?? this.heightFrac,
  );
}