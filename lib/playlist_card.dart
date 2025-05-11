import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class PlaylistCard extends StatefulWidget {
  final Map<String, dynamic> playlist;
  final int index;
  final int? currentlyExpandedIndex;
  final Function(int, bool) onExpansionChanged;
  final Map<String, WebViewController> activeWebViews;

  const PlaylistCard({
    Key? key,
    required this.playlist,
    required this.index,
    required this.currentlyExpandedIndex,
    required this.onExpansionChanged,
    required this.activeWebViews,
  }) : super(key: key);

  @override
  State<PlaylistCard> createState() => _PlaylistCardState();
}

class _PlaylistCardState extends State<PlaylistCard> with AutomaticKeepAliveClientMixin {
  late List<WebViewController?> _webViewControllers;
  bool _isInitialized = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeWebViews();
  }

  void _initializeWebViews() {
    if (widget.playlist['musics'] == null) {
      _isInitialized = true;
      return;
    }

    final musics = widget.playlist['musics'] as List;
    _webViewControllers = List<WebViewController?>.filled(musics.length, null);

    // Pre-initialize all web views for this playlist
    for (int i = 0; i < musics.length; i++) {
      final music = musics[i] as Map<String, dynamic>;
      final spotifyId = music['spotifyId']?.toString();
      final uniqueKey = '${widget.playlist['_id']}-$i';

      if (spotifyId != null) {
        if (widget.activeWebViews.containsKey(uniqueKey)) {
          _webViewControllers[i] = widget.activeWebViews[uniqueKey]!;
        } else {
          _createWebViewController(spotifyId, uniqueKey).then((controller) {
            if (mounted) {
              setState(() {
                _webViewControllers[i] = controller;
                if (i == musics.length - 1) _isInitialized = true;
              });
            }
          });
        }
      } else {
        _webViewControllers[i] = null;
        if (i == musics.length - 1) _isInitialized = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Needed for AutomaticKeepAliveClientMixin

    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        key: ValueKey('${widget.playlist['_id']}_${widget.index}'),
        initiallyExpanded: widget.currentlyExpandedIndex == widget.index,
        onExpansionChanged: (expanded) {
          widget.onExpansionChanged(widget.index, expanded);
        },
        title: Text(
          widget.playlist['name'] ?? 'Untitled Playlist',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        subtitle: Text(
          "${widget.playlist['musicCount'] ?? 0} songs",
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
        children: _buildPlaylistChildren(),
      ),
    );
  }

  List<Widget> _buildPlaylistChildren() {
    if (widget.playlist['musics'] == null ||
        (widget.playlist['musics'] as List).isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            "No songs in this playlist",
            style: TextStyle(color: Colors.grey),
          ),
        )
      ];
    }

    final musics = widget.playlist['musics'] as List;
    return List.generate(musics.length, (index) {
      return _buildMusicPlayer(
        musics[index] as Map<String, dynamic>,
        index,
      );
    });
  }

  Widget _buildMusicPlayer(Map<String, dynamic> music, int musicIndex) {
    final spotifyId = music['spotifyId']?.toString();

    if (spotifyId == null || !_isInitialized || _webViewControllers[musicIndex] == null) {
      return Container(
        height: 60,
        color: Colors.grey[800],
        child: ListTile(
          leading: const Icon(Icons.music_note, color: Colors.white70),
          title: Text(
            music['title'] ?? 'Unknown Track',
            style: const TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            music['artist'] ?? 'Unknown Artist',
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return Container(
      height: 80,
      color: Colors.grey[800],
      child: WebViewWidget(
        controller: _webViewControllers[musicIndex]!,
      ),
    );
  }

  Future<WebViewController> _createWebViewController(String spotifyId, String uniqueKey) async {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..loadRequest(
        Uri.parse('https://open.spotify.com/embed/track/$spotifyId'),
      );

    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (controller.platform as AndroidWebViewController)
        ..setMediaPlaybackRequiresUserGesture(false);
    }

    widget.activeWebViews[uniqueKey] = controller;
    return controller;
  }

  @override
  void dispose() {
    // Don't dispose controllers here - let the parent widget handle them
    super.dispose();
  }
}