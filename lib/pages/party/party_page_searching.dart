import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:jashan/data/track.dart';
import 'package:jashan/data/track_queue_item.dart';
import 'package:jashan/data/user.dart';
import 'package:jashan/pages/party/party_page.dart';
import 'package:jashan/util/text_utilities.dart';
import 'package:jashan/widgets/track_card.dart';

class PartyPageSearching extends StatefulWidget {
  final PartyPageState partyPageState;
  final JashanUser user;
  final QueueList<TrackQueueItem> queue;

  PartyPageSearching(this.partyPageState, this.user, this.queue);

  @override
  State<StatefulWidget> createState() {
    return _PartyPageSearchingState();
  }
}

class _PartyPageSearchingState extends State<PartyPageSearching> {
  List<Track> _searchItems = List<Track>();
  TextEditingController _searchQueryController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(
          color: Colors.white,
        ),
        backgroundColor: Colors.orange,
        title: TextField(
          autocorrect: false,
          controller: _searchQueryController,
          onSubmitted: (searchQuery) {
            if (searchQuery.length > 2) {
              _searchItems.clear();
              _repopulateSearchList(searchQuery);
            }
          },
          style: TextStyle(
            color: Colors.white,
          ),
          decoration: InputDecoration(
            contentPadding: EdgeInsets.symmetric(vertical: 14.0),
            prefixIcon: Icon(Icons.search, color: Colors.white),
            hintText: "Search...",
            hintStyle: TextStyle(color: Colors.white),
          ),
        ),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.close),
            color: Colors.white,
            onPressed: () {
              widget.partyPageState.setState(() {
                widget.partyPageState.searching = false;
              });
            },
          ),
          SizedBox(
            width: 20,
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _searchItems.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return SizedBox(
              height: 10,
            );
          }
          final Track data = _searchItems[index - 1];
          return TrackCard(
            data: data,
            onClick: () {
              final TrackQueueItem queueItem =
                  TrackQueueItem.fromTrack(data, addedBy: widget.user.username);
              widget.queue.add(queueItem);
            },
          );
        },
      ),
    );
  }

  Future _repopulateSearchList(String searchQuery) async {
    Response queryResponse = await get(
        'https://api.spotify.com/v1/search?q="$searchQuery"&type=track',
        headers: {'Authorization': 'Bearer ${widget.user.accessToken}'});
    List items = json.decode(queryResponse.body)['tracks']['items'];
    return setState(() {
      items.forEach((result) {
        String imageUrl = result['album']['images'][0]['url'];
        String uri = result['uri'];
        String name = result['name'];
        int durationMs = result['duration_ms'];
        name = getTextWithCap(name, 34);
        List artists = result['artists'];
        String artistsString = artists[0]['name'];
        for (int i = 1; i < artists.length; i++) {
          artistsString += ', ${artists[i]['name']}';
        }
        artistsString = getTextWithCap(artistsString, 37);
        _searchItems.add(
          Track(
              thumbnail: Image.network(imageUrl),
              thumbnailUrl: imageUrl,
              title: name,
              artist: artistsString,
              uri: uri,
              durationMs: durationMs),
        );
      });
    });
  }
}
