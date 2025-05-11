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

class _PlaylistCardState extends State<PlaylistCard> {
  @override
  Widget build(BuildContext context) {
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

    return (widget.playlist['musics'] as List).asMap().entries.map((entry) {
      return _buildMusicPlayer(
        entry.value as Map<String, dynamic>,
        widget.index,
        entry.key,
      );
    }).toList();
  }

  Widget _buildMusicPlayer(Map<String, dynamic> music, int playlistIndex, int musicIndex) {
    final spotifyId = music['spotifyId']?.toString();
    final uniqueKey = '$playlistIndex-$musicIndex';

    if (spotifyId == null) {
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
      child: FutureBuilder<WebViewController>(
        future: _createWebViewController(spotifyId, uniqueKey),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 8),
                  Text(
                    music['title'] ?? 'Loading track...',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(height: 8),
                  Text(
                    music['title'] ?? 'Error loading track',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            );
          }
          return WebViewWidget(
            controller: snapshot.data!,
          );
        },
      ),
    );
  }

  Future<WebViewController> _createWebViewController(String spotifyId, String uniqueKey) async {
    if (widget.activeWebViews.containsKey(uniqueKey)) {
      return widget.activeWebViews[uniqueKey]!;
    }

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
}