import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart';
import 'package:jashan/data/track.dart';
import 'package:jashan/data/track_queue_item.dart';
import 'package:jashan/data/user.dart';
import 'package:jashan/pages/party/party_page_searching.dart';
import 'package:jashan/util/sorted_queue_list.dart';
import 'package:jashan/util/spotify_player.dart';
import 'package:jashan/util/text_utilities.dart';
import 'package:jashan/widgets/track_info_view.dart';
import 'package:jashan/widgets/track_queue_item_card.dart';

class PartyPage extends StatefulWidget {
  final JashanUser user;
  final QueueList<TrackQueueItem> queue = new SortedQueueList();
  final String playlistName;

  PartyPage(this.playlistName, this.user, List<Track> tracks) {
    tracks.forEach((item) {
      var trackQueueItem =
          new TrackQueueItem.fromTrack(item, addedBy: user.username);
      trackQueueItem.upvotes.add(user);
      queue.add(trackQueueItem);
    });
  }

  @override
  State<StatefulWidget> createState() {
    return PartyPageState(queue);
  }
}

class PartyPageState extends State<PartyPage> {
  final QueueList<TrackQueueItem> queue;
  TrackQueueItem currentlyPlayingSong;
  SpotifyPlayer spotifyPlayer;

  PartyPageState(this.queue);

  @override
  void initState() {
    super.initState();
    spotifyPlayer = new SpotifyPlayer(
      user: widget.user,
    );
    spotifyPlayer.setOnSongChange(() {
      setState(() {
        currentlyPlayingSong = widget.queue.removeFirst();
        spotifyPlayer.playSong(currentlyPlayingSong);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    AppBar appBar = AppBar(
      iconTheme: Theme.of(context).iconTheme,
      actions: <Widget>[
        InkWell(
          child: Icon(Icons.add),
          onTap: () => _openSearch(),
        ),
        SizedBox(
          width: 20,
        ),
      ],
    );
    return Scaffold(
      appBar: appBar,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              flex: 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  Text(
                    getTextWithCap(widget.playlistName, 16),
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 30,
                    ),
                  ),
                  Divider(color: Colors.black),
                ],
              ),
            ),
            Expanded(
              flex: 8,
              child: widget.queue.isNotEmpty
                  ? ListView.builder(
                itemBuilder: (BuildContext context, int index) {
                  TrackQueueItem data;
                  if (currentlyPlayingSong == null) {
                    data = widget.queue[index];
                  } else if (index == 0 && currentlyPlayingSong != null) {
                    data = currentlyPlayingSong;
                  } else if (index != 0 && currentlyPlayingSong != null) {
                    data = widget.queue[index - 1];
                  }
                  return TrackQueueItemCard(
                    data: data,
                    onLongPress: () {
                      Color background = Colors.black.withOpacity(0.7);
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            backgroundColor: background,
                            content: TrackInfoView(appBar, data),
                          );
                        },
                      );
                    },
                    onUpvoteChange: (increase) => _onSongUpvote(index, data, increase),
                    isCurrentPlaying: data == currentlyPlayingSong,
                  );
                },
                itemCount: widget.queue.length +
                    (currentlyPlayingSong == null ? 0 : 1),
              )
                  : Center(
                child: Text(
                  'No songs!',
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: MediaQuery.of(context).size.width / 2 - 12.5,
                    height: 50,
                    child: RaisedButton(
                      child: Text(
                        "Start Party",
                        style: TextStyle(
                          color: Theme.of(context).accentColor,
                          fontSize: 20,
                        ),
                      ),
                      color: Theme.of(context).primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(75),
                      ),
                      onPressed: _startParty,
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  void _onSongUpvote(int songIndex, TrackQueueItem data, bool increase) {
    if (songIndex != 0 || currentlyPlayingSong == null) {
      Set<JashanUser> reputation = increase ? data.upvotes : data.downvotes;
      Set<JashanUser> otherReputation = increase ? data.downvotes : data
          .upvotes;
      otherReputation.remove(widget.user);
      reputation.contains(widget.user)
          ? reputation.remove(widget.user)
          : reputation.add(widget.user);
      setState(() => widget.queue.sort());
    }
  }

  @override
  void dispose() {
    super.dispose();
    spotifyPlayer.dispose();
  }

  void _startParty() async {
    Response availableDevicesResponse = await get(
        'https://api.spotify.com/v1/me/player/devices',
        headers: {'Authorization': 'Bearer ${widget.user.accessToken}'});
    List availableDevices = json.decode(availableDevicesResponse.body)['devices'];
    await put('https://api.spotify.com/v1/me/player',
        headers: {
          'Authorization': 'Bearer ${widget.user.accessToken}',
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: '{'
            '"device_ids": ['
            '"${availableDevices[0]['id']}"'
            ']'
            '}');
    setState(() {
      currentlyPlayingSong = widget.queue.removeFirst();
      spotifyPlayer.playSong(currentlyPlayingSong);
    });
  }

  void _openSearch() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => PartyPageSearching(widget.user, widget.queue)
    ));
  }
}
