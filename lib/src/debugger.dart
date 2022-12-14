import 'package:flutter/widgets.dart';
import 'drawable/drawable_layer.dart';
import 'vector_map_mode.dart';

class DurationDebugger extends ChangeNotifier {
  DurationDebugger(VoidCallback listener) {
    addListener(listener);
  }

  int _milliseconds = 0;
  int get milliseconds => _milliseconds;

  DateTime? _lastStartTime;

  void clear() {
    _milliseconds = 0;
    _lastStartTime = null;
  }

  void open() {
    _lastStartTime = DateTime.now();
  }

  closeAndInc() {
    if (_lastStartTime != null) {
      DateTime end = DateTime.now();
      Duration duration = end.difference(_lastStartTime!);
      _milliseconds += duration.inMilliseconds;
      _lastStartTime = null;
      notifyListeners();
    }
  }
}

class MapDebugger extends ChangeNotifier {
  MapDebugger() {
    drawableBuildDuration = DurationDebugger(notifyListeners);
    bufferBuildDuration = DurationDebugger(notifyListeners);
  }

  int _layersCount = 0;
  int _chunksCount = 0;
  int _featuresCount = 0;
  int _originalPointsCount = 0;
  int _simplifiedPointsCount = 0;
  Offset? _mouseHoverWorld;
  Offset? _mouseHoverCanvas;

  late DurationDebugger drawableBuildDuration;
  late DurationDebugger bufferBuildDuration;

  String? _mode;

  void updateMode(VectorMapMode mode) {
    if (mode == VectorMapMode.autoFit) {
      _mode = "auto fit";
    } else if (mode == VectorMapMode.panAndZoom) {
      _mode = "pan and zoom";
    } else {
      _mode = null;
    }
  }

  void updateLayers(List<DrawableLayer> drawableLayers, int chunksCount) {
    _layersCount = drawableLayers.length;
    _chunksCount = chunksCount;
    for (DrawableLayer drawableLayer in drawableLayers) {
      final dataSourceLayer = drawableLayer.layer.dataSource;
      _featuresCount += dataSourceLayer.features.length;
      _originalPointsCount += dataSourceLayer.pointsCount;
    }
    _simplifiedPointsCount = 0;
    notifyListeners();
  }

  void updateMouseHover({Offset? worldCoordinate, Offset? locationOnCanvas}) {
    _mouseHoverWorld = worldCoordinate;
    _mouseHoverCanvas = locationOnCanvas;
    notifyListeners();
  }

  void updateSimplifiedPointsCount(int simplifiedPointsCount) {
    _simplifiedPointsCount = simplifiedPointsCount;
    notifyListeners();
  }
}

class MapDebuggerWidget extends StatefulWidget {
  final MapDebugger? debugger;

  const MapDebuggerWidget({super.key, this.debugger});

  @override
  State<StatefulWidget> createState() {
    return MapDebuggerState();
  }
}

class MapDebuggerState extends State<MapDebuggerWidget> {
  final ScrollController _controller = ScrollController();

  String formatInt(int value) {
    String str = value.toString();
    String fmt = '';
    int indexGroup = 3 - str.length % 3;
    if (indexGroup == 3) {
      indexGroup = 0;
    }
    for (int i = 0; i < str.length; i++) {
      fmt += str.substring(i, i + 1);
      indexGroup++;
      if (indexGroup == 3 && i < str.length - 1) {
        fmt += ',';
        indexGroup = 0;
      }
    }
    return fmt;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.debugger == null) {
      return Container();
    }
    MapDebugger d = widget.debugger!;

    int drawableBuildDuration = d.drawableBuildDuration.milliseconds;
    int bufferBuildDuration = d.bufferBuildDuration.milliseconds;
    int multiResolutionDuration = drawableBuildDuration + bufferBuildDuration;

    return SingleChildScrollView(
        controller: _controller,
        child: Container(
            child: Column(children: [
              _title('Quantities'),
              _int('Layers: ', d._layersCount),
              _int(' ??? Chunks: ', d._chunksCount),
              _int('Features: ', d._featuresCount),
              _int('Original points: ', d._originalPointsCount),
              _int('Simplified points: ', d._simplifiedPointsCount),
              _title('Last durations'),
              _milliseconds('Drawables build: ', multiResolutionDuration),
              _milliseconds(
                  ' ??? Simplified geometries: ', drawableBuildDuration),
              _milliseconds(' ??? Buffers: ', bufferBuildDuration),
              _title('Cursor location'),
              _offset('Canvas: ', d._mouseHoverCanvas),
              _offset('World: ', d._mouseHoverWorld),
              _title('Configurations'),
              _item('Mode: ', d._mode != null ? d._mode! : '')
            ], crossAxisAlignment: CrossAxisAlignment.start),
            width: 200,
            padding: const EdgeInsets.all(8)));
  }

  Widget _title(String text) {
    return Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)));
  }

  Widget _milliseconds(String label, int value) {
    return _item(label, formatInt(value) + ' ms');
  }

  Widget _int(String label, int value) {
    return _item(label, formatInt(value));
  }

  Widget _offset(String label, Offset? offset) {
    if (offset == null) {
      return _item(label, '');
    }
    return _item(label, offset.dx.toString() + ', ' + offset.dy.toString());
  }

  Widget _item(String label, String value) {
    return Padding(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 0),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 12),
            children: <TextSpan>[
              TextSpan(text: label),
              TextSpan(
                  text: value,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ));
  }

  @override
  void initState() {
    super.initState();
    widget.debugger?.addListener(_refresh);
  }

  @override
  void didUpdateWidget(MapDebuggerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    oldWidget.debugger?.removeListener(_refresh);
    widget.debugger?.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.debugger?.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    // avoid calling setState during build
    Future.delayed(Duration.zero, () {
      if (mounted) {
        setState(() {
          // rebuild
        });
      }
    });
  }
}
