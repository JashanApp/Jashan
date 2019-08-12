import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:http/http.dart';
import 'package:jashan/data/playlist_item.dart';
import 'package:jashan/data/user.dart';

class SpotifyPlayer {
  final JashanUser user;
  Function onSongChange;
  String timerSongUri;
  Timer timer;

  SpotifyPlayer({this.user});

  void setOnSongChange(Function onSongChange) {
    this.onSongChange = onSongChange;
  }

  void playSong(QueueList<PlaylistItem> queue) {
    PlaylistItem playlistItem = queue.removeFirst();
    put(
      'https://api.spotify.com/v1/me/player/play',
      headers: {
        'Authorization': 'Bearer ${user.accessToken}',
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      body: '{'
          '"uris": ["${playlistItem.uri}"]'
          '}',
    );
    timerSongUri = playlistItem.uri;
    // todo flaw with this approach: can adjust song time in spotify itself and ruin this
    if (timer != null) {
      timer.cancel();
    }
    timer = new Timer(Duration(milliseconds: playlistItem.durationMs + 1000),
        () async {
          // todo checks to not override user choice
      //String currentSongUri = await _getCurrentSongUri();
      /*if (currentSongUri != timerSongUri) {
        print('ded :( cuz $currentSongUri vs $timerSongUri');
        return;
      }*/
      onSongChange();
    });
  }

  Future<String> _getCurrentSongUri() async {
    Response response = await get(
      'https://api.spotify.com/v1/me/player',
      headers: {
        'Authorization': 'Bearer ${user.accessToken}',
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
    );
    Map currentPlayback = json.decode(response.body);
    Map context = currentPlayback['context'];
    print(currentPlayback['context']);
    return context['uri'];
  }

// todo close web socket
}
